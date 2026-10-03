import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/constants/app_config.dart';
import '../models/game_view.dart';
import '../models/invite.dart';

sealed class ServerEvent {
  const ServerEvent();
}

class HelloEvent extends ServerEvent {
  const HelloEvent({required this.userId, required this.serverTime});
  final String userId;
  final String serverTime;
}

class InviteEvent extends ServerEvent {
  const InviteEvent({required this.invite});
  final Invite invite;
}

class InviteUpdateEvent extends ServerEvent {
  const InviteUpdateEvent({required this.invite});
  final Invite invite;
}

class GameEvent extends ServerEvent {
  const GameEvent({required this.game});
  final GameView game;
}

typedef WebSocketFactory = WebSocketChannel Function(Uri uri);

class RealtimeClient {
  RealtimeClient({
    required String baseUrl,
    String? token,
    WebSocketFactory? channelFactory,
  })  : _baseUrl = baseUrl,
        _token = token,
        _channelFactory = channelFactory ?? ((uri) => WebSocketChannel.connect(uri));

  String _baseUrl;
  String? _token;
  final WebSocketFactory _channelFactory;

  final _eventsController = StreamController<ServerEvent>.broadcast();
  Stream<ServerEvent> get events => _eventsController.stream;

  final ValueNotifier<bool> connected = ValueNotifier<bool>(false);

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _disposed = false;
  int _reconnectDelaySec = 1;

  void updateCredentials({required String baseUrl, String? token}) {
    final changed = _baseUrl != baseUrl || _token != token;
    _baseUrl = baseUrl;
    _token = token;
    if (changed) {
      disconnect();
      if (_token != null && _token!.isNotEmpty) {
        connect();
      }
    }
  }

  void connect() {
    if (_disposed || _token == null || _token!.isEmpty) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    final wsUrl = _resolveWsUri(_baseUrl);
    try {
      final ch = _channelFactory(wsUrl);
      _channel = ch;

      // Send auth frame immediately
      ch.sink.add(jsonEncode({'type': 'auth', 'token': _token}));

      _sub = ch.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: true,
      );

      _startPing();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final text = raw is String ? raw : utf8.decode(raw as List<int>);
      final map = jsonDecode(text) as Map<String, dynamic>;
      final type = map['type'] as String?;

      switch (type) {
        case 'hello':
          connected.value = true;
          _reconnectDelaySec = 1;
          final userId = map['userId']?.toString() ?? '';
          final serverTime = map['serverTime']?.toString() ?? '';
          _eventsController.add(HelloEvent(userId: userId, serverTime: serverTime));
          break;
        case 'invite':
          final inv = Invite.fromJson(map['invite'] as Map<String, dynamic>);
          _eventsController.add(InviteEvent(invite: inv));
          break;
        case 'invite_update':
          final inv = Invite.fromJson(map['invite'] as Map<String, dynamic>);
          _eventsController.add(InviteUpdateEvent(invite: inv));
          break;
        case 'game':
          final gv = GameView.fromJson(map['game'] as Map<String, dynamic>);
          _eventsController.add(GameEvent(game: gv));
          break;
        case 'error':
          if (map['code'] == 'unauthorized') {
            connected.value = false;
            disconnect();
          }
          break;
      }
    } catch (_) {
      // Ignore malformed push payloads
    }
  }

  void _onError(dynamic _) {
    _cleanupChannel();
    _scheduleReconnect();
  }

  void _onDone() {
    _cleanupChannel();
    _scheduleReconnect();
  }

  void _cleanupChannel() {
    connected.value = false;
    _pingTimer?.cancel();
    _pingTimer = null;
    _sub?.cancel();
    _sub = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(AppConfig.socketPingInterval, (_) {
      if (connected.value && _channel != null) {
        try {
          _channel?.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {}
      }
    });
  }

  void _scheduleReconnect() {
    if (_disposed || _token == null || _token!.isEmpty) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelaySec), () {
      connect();
    });
    // Exponential backoff up to 30s
    _reconnectDelaySec = (_reconnectDelaySec * 2).clamp(1, 30);
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cleanupChannel();
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _eventsController.close();
    connected.dispose();
  }

  Uri _resolveWsUri(String httpUrl) {
    var raw = httpUrl.trim();
    if (raw.startsWith('http://')) {
      raw = 'ws://${raw.substring(7)}';
    } else if (raw.startsWith('https://')) {
      raw = 'wss://${raw.substring(8)}';
    } else {
      raw = 'ws://$raw';
    }
    raw = raw.replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$raw/ws');
  }
}
