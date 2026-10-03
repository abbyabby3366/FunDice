import 'package:flutter/foundation.dart';

/// Server address and timing constants shared by the data layer.
class AppConfig {
  AppConfig._();

  /// Server address compiled in with `--dart-define=API_BASE_URL=https://...`.
  static const String _compiledServerUrl = String.fromEnvironment('API_BASE_URL');

  /// The server the app talks to until the player picks another one in Settings.
  ///
  /// Release builds without `API_BASE_URL` return an empty string on purpose: the app
  /// never guesses a host, it asks for one.
  static String get defaultServerUrl => resolveDefaultServerUrl(
        compiled: _compiledServerUrl,
        debug: kDebugMode,
        platform: defaultTargetPlatform,
      );

  /// Pure form of [defaultServerUrl] so every branch can be tested.
  @visibleForTesting
  static String resolveDefaultServerUrl({
    required String compiled,
    required bool debug,
    required TargetPlatform platform,
  }) {
    final configured = normalizeServerUrl(compiled);
    if (configured != null) return configured;
    if (!debug) return '';
    // The Android emulator reaches the host machine through 10.0.2.2.
    return platform == TargetPlatform.android ? 'http://10.0.2.2:3000' : 'http://localhost:3000';
  }

  /// Cleans up an address typed by the player.
  ///
  /// Trims it, adds a scheme when missing (`http` for local network hosts, `https` for the
  /// rest) and drops trailing slashes. Returns null when the text cannot be a server address.
  static String? normalizeServerUrl(String input) {
    var text = input.trim();
    if (text.isEmpty) return null;
    if (!text.contains('://')) {
      text = '${_isLocalHost(text) ? 'http' : 'https'}://$text';
    }
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return text.replaceFirst(RegExp(r'/+$'), '');
  }

  static final RegExp _localHost = RegExp(
    r'^(localhost|127(\.\d+){3}|10(\.\d+){3}|192\.168(\.\d+){2}|172\.(1[6-9]|2\d|3[01])(\.\d+){2}|[^/:\s]+\.local)(?=[:/]|$)',
    caseSensitive: false,
  );

  static bool _isLocalHost(String text) => _localHost.hasMatch(text);

  /// How long registration waits for a sleeping server (Render's free plan needs up to a minute to wake).
  static const Duration registerTimeout = Duration(seconds: 75);

  /// Timeout of a single API request.
  static const Duration requestTimeout = Duration(seconds: 15);

  /// How long a connection attempt may take before the UI says the server is waking up.
  static const Duration wakingHintAfter = Duration(seconds: 5);

  /// Reconnect backoff of the WebSocket: starts at [reconnectMinDelay], doubles up to [reconnectMaxDelay].
  static const Duration reconnectMinDelay = Duration(seconds: 1);
  static const Duration reconnectMaxDelay = Duration(seconds: 30);

  /// Keep-alive ping of the WebSocket; a missing pong closes the connection so it can be re-opened.
  static const Duration socketPingInterval = Duration(seconds: 20);

  /// Time allowed for opening the WebSocket and receiving the server's `hello`.
  static const Duration socketConnectTimeout = Duration(seconds: 15);

  /// Extra time the app waits past an invitation's `expiresAt` before dropping it locally.
  static const Duration inviteExpiryGrace = Duration(seconds: 2);
}
