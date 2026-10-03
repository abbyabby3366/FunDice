import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

import '../core/constants/app_config.dart';
import '../core/utils/haptics.dart';
import '../models/api_exception.dart';
import '../models/app_user.dart';
import '../models/game_view.dart';
import '../models/invite.dart';
import '../models/match_result.dart';
import '../models/roll.dart';
import '../models/server_config.dart';
import '../services/api_client.dart';
import '../services/local_store.dart';
import '../services/realtime_client.dart';

enum AppPhase { booting, needsName, ready }
enum ServerStatus { connecting, waking, online, offline }

class AppController extends ChangeNotifier {
  AppController({
    required ApiClient api,
    required RealtimeClient realtime,
    required LocalStore store,
  })  : _api = api,
        _realtime = realtime,
        _store = store {
    _realtimeSub = _realtime.events.listen(_onServerEvent);
    _realtimeConnectedListener = () {
      if (_realtime.connected.value) {
        _serverStatus = ServerStatus.online;
        notifyListeners();
        resync();
      }
    };
    _realtime.connected.addListener(_realtimeConnectedListener);
  }

  final ApiClient _api;
  final RealtimeClient _realtime;
  final LocalStore _store;

  late final StreamSubscription<ServerEvent> _realtimeSub;
  late final VoidCallback _realtimeConnectedListener;

  AppPhase _phase = AppPhase.booting;
  ServerStatus _serverStatus = ServerStatus.connecting;
  AppUser? _user;
  List<Roll> _rolls = [];
  Invite? _incomingInvite;
  Invite? _outgoingInvite;
  GameView? _game;
  ServerConfig _config = const ServerConfig(
    diceCount: 5,
    rollHistory: 5,
    peeksPerGame: 3,
    inviteTtlSec: 60,
    graceSec: 60,
  );
  bool _hapticsEnabled = true;
  String _serverUrl = '';
  String? _notice;
  int _lastSeenLogId = 0;

  AppPhase get phase => _phase;
  ServerStatus get serverStatus => _serverStatus;
  AppUser? get user => _user;
  List<Roll> get rolls => List.unmodifiable(_rolls);
  Invite? get incomingInvite => _incomingInvite;
  Invite? get outgoingInvite => _outgoingInvite;
  GameView? get game => _game;
  ServerConfig get config => _config;
  bool get hapticsEnabled => _hapticsEnabled;
  String get serverUrl => _serverUrl;
  String? get notice => _notice;

  void consumeNotice() {
    _notice = null;
  }

  Future<void> bootstrap() async {
    _hapticsEnabled = _store.hapticsEnabled;
    AppHaptics.enabled = _hapticsEnabled;

    final storedUrl = _store.serverUrl?.trim();
    _serverUrl = (storedUrl != null && storedUrl.isNotEmpty)
        ? storedUrl
        : AppConfig.defaultServerUrl;
    _api.baseUrl = _serverUrl;

    final token = _store.token;
    final userId = _store.userId;
    final userName = _store.userName;

    if (token != null && userId != null && userName != null) {
      _api.token = token;
      _user = AppUser(id: userId, name: userName);
      _phase = AppPhase.ready;
      notifyListeners();
      _connectAndResync();
    } else {
      _phase = AppPhase.needsName;
      _serverStatus = ServerStatus.offline;
      notifyListeners();
    }
  }

  void _connectAndResync() {
    if (_serverUrl.isEmpty) {
      _serverStatus = ServerStatus.offline;
      notifyListeners();
      return;
    }
    _serverStatus = ServerStatus.connecting;
    notifyListeners();

    final wakingTimer = Timer(AppConfig.wakingHintAfter, () {
      if (_serverStatus == ServerStatus.connecting) {
        _serverStatus = ServerStatus.waking;
        notifyListeners();
      }
    });

    _realtime.updateCredentials(baseUrl: _serverUrl, token: _api.token);
    resync().whenComplete(() {
      wakingTimer.cancel();
    });
  }

  Future<void> registerName(String name) async {
    try {
      final res = await _api.register(name);
      final token = res['token'] as String;
      final userMap = res['user'] as Map<String, dynamic>;
      final user = AppUser.fromJson(userMap);

      _api.token = token;
      _user = user;
      await _store.setToken(token);
      await _store.setUserId(user.id);
      await _store.setUserName(user.name);

      _phase = AppPhase.ready;
      _serverStatus = ServerStatus.online;
      notifyListeners();

      _realtime.updateCredentials(baseUrl: _serverUrl, token: token);
      await resync();
    } on ApiException {
      rethrow;
    }
  }

  Future<void> setServerUrl(String url) async {
    final clean = AppConfig.normalizeServerUrl(url) ?? url.trim();
    _serverUrl = clean;
    await _store.setServerUrl(clean);
    _api.baseUrl = clean;
    _connectAndResync();
  }

  Future<void> setHaptics(bool enabled) async {
    _hapticsEnabled = enabled;
    AppHaptics.enabled = enabled;
    await _store.setHapticsEnabled(enabled);
    notifyListeners();
  }

  Future<void> resync() async {
    if (_api.token == null || _api.token!.isEmpty) return;
    try {
      final data = await _api.me();
      _serverStatus = ServerStatus.online;

      final u = AppUser.fromJson(data['user'] as Map<String, dynamic>);
      _user = u;
      await _store.setUserName(u.name);

      final rollsList = (data['rolls'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(Roll.fromJson)
              .toList() ??
          [];
      _rolls = rollsList;

      final invObj = data['invites'] as Map<String, dynamic>?;
      _incomingInvite = invObj?['incoming'] != null
          ? Invite.fromJson(invObj!['incoming'] as Map<String, dynamic>)
          : null;
      _outgoingInvite = invObj?['outgoing'] != null
          ? Invite.fromJson(invObj!['outgoing'] as Map<String, dynamic>)
          : null;

      final gameData = data['game'];
      final newGame = gameData is Map<String, dynamic> ? GameView.fromJson(gameData) : null;
      if (_game != null && _game!.status == 'playing' && newGame == null) {
        _notice = 'The game ended (server restarted).';
      }
      _updateGame(newGame);

      if (data['config'] is Map<String, dynamic>) {
        _config = ServerConfig.fromJson(data['config'] as Map<String, dynamic>);
      }
      notifyListeners();
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        final currentName = _user?.name ?? _store.userName;
        if (currentName != null && currentName.isNotEmpty) {
          try {
            await registerName(currentName);
          } catch (_) {}
        }
      } else if (e.isOffline) {
        _serverStatus = ServerStatus.offline;
        notifyListeners();
      }
    }
  }

  Future<Roll> roll() async {
    try {
      final res = await _api.roll();
      final r = Roll.fromJson(res['roll'] as Map<String, dynamic>);
      final all = (res['rolls'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(Roll.fromJson)
              .toList() ??
          [r];
      _rolls = all;
      notifyListeners();
      return r;
    } catch (e) {
      // Offline fallback: random local roll not shared with server
      final rng = Random();
      final localDice = List.generate(5, (_) => rng.nextInt(6) + 1);
      return Roll(
        seq: -1,
        dice: localDice,
        at: DateTime.now().toUtc(),
        shared: false,
      );
    }
  }

  void clearRolls() {
    _rolls = [];
    notifyListeners();
  }

  Future<MatchResult> match(List<int> dice, {List<int>? next}) async {
    return _api.match(dice, next: next);
  }

  Future<void> sendInvite(AppUser to) async {
    final inv = await _api.createInvite(to.id);
    _outgoingInvite = inv;
    notifyListeners();
  }

  Future<void> cancelOutgoingInvite() async {
    final inv = _outgoingInvite;
    if (inv != null) {
      _outgoingInvite = null;
      notifyListeners();
      try {
        await _api.cancelInvite(inv.id);
      } catch (_) {}
    }
  }

  Future<void> acceptInvite() async {
    final inv = _incomingInvite;
    if (inv != null) {
      _incomingInvite = null;
      notifyListeners();
      final gv = await _api.acceptInvite(inv.id);
      _updateGame(gv);
      notifyListeners();
    }
  }

  Future<void> declineInvite() async {
    final inv = _incomingInvite;
    if (inv != null) {
      _incomingInvite = null;
      notifyListeners();
      try {
        await _api.declineInvite(inv.id);
      } catch (_) {}
    }
  }

  Future<void> bid(int quantity, int face) async {
    final gv = await _api.bid(quantity: quantity, face: face);
    _updateGame(gv);
    notifyListeners();
  }

  Future<void> challenge() async {
    final gv = await _api.challenge();
    _updateGame(gv);
    notifyListeners();
  }

  Future<PeekResult> peek() async {
    final res = await _api.peek();
    // Refresh game view after peek
    final gv = await _api.getGame();
    if (gv != null) _updateGame(gv);
    notifyListeners();
    return res;
  }

  Future<void> leaveGame() async {
    final wasPlaying = _game?.status == 'playing';
    _game = null;
    notifyListeners();
    try {
      await _api.leaveGame();
    } catch (_) {}
    if (!wasPlaying) {
      await resync();
    }
  }

  void _onServerEvent(ServerEvent event) {
    switch (event) {
      case HelloEvent():
        _serverStatus = ServerStatus.online;
        notifyListeners();
        break;
      case InviteEvent(:final invite):
        _incomingInvite = invite;
        notifyListeners();
        break;
      case InviteUpdateEvent(:final invite):
        if (_incomingInvite?.id == invite.id) {
          if (invite.status == InviteStatus.cancelled) {
            _notice = '${invite.from.name} cancelled the invitation.';
            _incomingInvite = null;
          } else if (invite.status == InviteStatus.expired) {
            _notice = 'Invitation from ${invite.from.name} expired.';
            _incomingInvite = null;
          }
        }
        if (_outgoingInvite?.id == invite.id) {
          if (invite.status == InviteStatus.declined) {
            _notice = '${invite.to.name} declined your challenge.';
            _outgoingInvite = null;
          } else if (invite.status == InviteStatus.expired) {
            _notice = 'Challenge to ${invite.to.name} expired.';
            _outgoingInvite = null;
          }
        }
        notifyListeners();
        break;
      case GameEvent(:final game):
        _updateGame(game);
        notifyListeners();
        break;
    }
  }

  void _updateGame(GameView? newGame) {
    if (newGame == null) {
      _game = null;
      return;
    }
    if (_game == null || newGame.version >= _game!.version) {
      // Check for notifications in new log items
      for (final item in newGame.log) {
        if (item.id > _lastSeenLogId) {
          _lastSeenLogId = item.id;
          if (item.notify) {
            _notice = item.text;
          }
        }
      }
      if (newGame.status == 'finished' && _game?.status == 'playing') {
        _store.recordGameFinished(won: newGame.iWon);
      }
      _game = newGame;
    }
  }

  String? getAlias(String userId) => _store.getAlias(userId);

  Future<void> saveAlias(String userId, String alias) async {
    await _store.setAlias(userId, alias);
    notifyListeners();
  }

  @override
  void dispose() {
    _realtime.connected.removeListener(_realtimeConnectedListener);
    _realtimeSub.cancel();
    _realtime.dispose();
    super.dispose();
  }
}
