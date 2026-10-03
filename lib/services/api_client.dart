import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../core/constants/app_config.dart';
import '../models/api_exception.dart';
import '../models/app_user.dart';
import '../models/game_view.dart';
import '../models/invite.dart';
import '../models/match_result.dart';

/// HTTP Client implementing all FunDice REST API endpoints.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    this.token,
    http.Client? client,
  }) : _client = client ?? http.Client();

  String baseUrl;
  String? token;
  final http.Client _client;

  Map<String, String> _headers({bool needsAuth = true}) {
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (needsAuth && token != null && token!.isNotEmpty) {
      map['Authorization'] = 'Bearer $token';
    }
    return map;
  }

  Future<T> _wrap<T>(Future<http.Response> Function() action) async {
    try {
      final res = await action().timeout(AppConfig.requestTimeout);
      final body = res.body.trim();
      final Map<String, dynamic> data = body.isNotEmpty && body.startsWith('{')
          ? jsonDecode(body) as Map<String, dynamic>
          : <String, dynamic>{};

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return data as T;
      }

      final errorObj = data['error'];
      if (errorObj is Map<String, dynamic>) {
        throw ApiException(
          code: errorObj['code']?.toString() ?? 'server_error',
          message: errorObj['message']?.toString() ?? 'Something went wrong',
          statusCode: res.statusCode,
          retryAfterSec: (errorObj['retryAfter'] as num?)?.toInt(),
        );
      }

      throw ApiException(
        code: res.statusCode == 401 ? 'unauthorized' : 'http_${res.statusCode}',
        message: 'Request failed with status ${res.statusCode}',
        statusCode: res.statusCode,
      );
    } on SocketException catch (_) {
      throw const ApiException(
        code: 'offline',
        message: 'Cannot reach game server. Check your connection or server URL.',
        statusCode: 0,
      );
    } on TimeoutException catch (_) {
      throw const ApiException(
        code: 'offline',
        message: 'Request timed out waiting for server response.',
        statusCode: 0,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        code: 'unknown',
        message: e.toString(),
        statusCode: 0,
      );
    }
  }

  /// Pings server health.
  Future<bool> warmUp() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/healthz'))
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Registers or re-registers display name.
  Future<Map<String, dynamic>> register(String name) async {
    final uri = Uri.parse('$baseUrl/api/register');
    final res = await _wrap<Map<String, dynamic>>(() => _client.post(
          uri,
          headers: _headers(needsAuth: token != null),
          body: jsonEncode({'name': name}),
        ));
    return res;
  }

  /// Fetches player snapshot.
  Future<Map<String, dynamic>> me() async {
    final uri = Uri.parse('$baseUrl/api/me');
    return _wrap<Map<String, dynamic>>(() => _client.get(uri, headers: _headers()));
  }

  /// Rolls dice on the server.
  Future<Map<String, dynamic>> roll() async {
    final uri = Uri.parse('$baseUrl/api/roll');
    return _wrap<Map<String, dynamic>>(() => _client.post(uri, headers: _headers()));
  }

  /// Finds an opponent by 5 dice pattern.
  Future<MatchResult> match(List<int> dice, {List<int>? next}) async {
    final uri = Uri.parse('$baseUrl/api/match');
    final payload = <String, dynamic>{'dice': dice};
    if (next != null) payload['next'] = next;

    final data = await _wrap<Map<String, dynamic>>(() => _client.post(
          uri,
          headers: _headers(),
          body: jsonEncode(payload),
        ));

    final statusStr = data['status'] as String? ?? 'not_found';
    switch (statusStr) {
      case 'matched':
        final opp = data['opponent'] as Map<String, dynamic>?;
        return MatchResult(
          status: MatchStatus.matched,
          opponent: opp != null ? AppUser.fromJson(opp) : null,
        );
      case 'busy':
        final opp = data['opponent'] as Map<String, dynamic>?;
        return MatchResult(
          status: MatchStatus.busy,
          opponent: opp != null ? AppUser.fromJson(opp) : null,
        );
      case 'ambiguous':
        return MatchResult(
          status: MatchStatus.ambiguous,
          candidates: (data['candidates'] as num?)?.toInt() ?? 2,
        );
      case 'not_found':
      default:
        return const MatchResult(status: MatchStatus.notFound);
    }
  }

  /// Sends challenge invite to an opponent.
  Future<Invite> createInvite(String opponentUserId) async {
    final uri = Uri.parse('$baseUrl/api/invites');
    final data = await _wrap<Map<String, dynamic>>(() => _client.post(
          uri,
          headers: _headers(),
          body: jsonEncode({'to': opponentUserId}),
        ));
    return Invite.fromJson(data['invite'] as Map<String, dynamic>);
  }

  /// Accepts an incoming challenge.
  Future<GameView> acceptInvite(String inviteId) async {
    final uri = Uri.parse('$baseUrl/api/invites/$inviteId/accept');
    final data = await _wrap<Map<String, dynamic>>(() => _client.post(uri, headers: _headers()));
    return GameView.fromJson(data['game'] as Map<String, dynamic>);
  }

  /// Declines an incoming challenge.
  Future<void> declineInvite(String inviteId) async {
    final uri = Uri.parse('$baseUrl/api/invites/$inviteId/decline');
    await _wrap<Map<String, dynamic>>(() => _client.post(uri, headers: _headers()));
  }

  /// Cancels an outgoing challenge.
  Future<void> cancelInvite(String inviteId) async {
    final uri = Uri.parse('$baseUrl/api/invites/$inviteId');
    await _wrap<Map<String, dynamic>>(() => _client.delete(uri, headers: _headers()));
  }

  /// Fetches current game view.
  Future<GameView?> getGame() async {
    final uri = Uri.parse('$baseUrl/api/game');
    final data = await _wrap<Map<String, dynamic>>(() => _client.get(uri, headers: _headers()));
    final gameData = data['game'];
    if (gameData is Map<String, dynamic>) {
      return GameView.fromJson(gameData);
    }
    return null;
  }

  /// Places a bid.
  Future<GameView> bid({required int quantity, required int face}) async {
    final uri = Uri.parse('$baseUrl/api/game/bid');
    final data = await _wrap<Map<String, dynamic>>(() => _client.post(
          uri,
          headers: _headers(),
          body: jsonEncode({'quantity': quantity, 'face': face}),
        ));
    return GameView.fromJson(data['game'] as Map<String, dynamic>);
  }

  /// Challenges the opponent's bid ("Liar!").
  Future<GameView> challenge() async {
    final uri = Uri.parse('$baseUrl/api/game/challenge');
    final data = await _wrap<Map<String, dynamic>>(() => _client.post(uri, headers: _headers()));
    return GameView.fromJson(data['game'] as Map<String, dynamic>);
  }

  /// Secretly peeks at an opponent's die.
  Future<PeekResult> peek() async {
    final uri = Uri.parse('$baseUrl/api/game/peek');
    final data = await _wrap<Map<String, dynamic>>(() => _client.post(uri, headers: _headers()));
    final peekData = data['peek'] as Map<String, dynamic>;
    return PeekResult(
      index: (peekData['index'] as num).toInt(),
      value: (peekData['value'] as num).toInt(),
      caught: peekData['caught'] as bool? ?? false,
    );
  }

  /// Leaves or forfeits the game.
  Future<void> leaveGame() async {
    final uri = Uri.parse('$baseUrl/api/game/leave');
    await _wrap<Map<String, dynamic>>(() => _client.post(uri, headers: _headers()));
  }
}
