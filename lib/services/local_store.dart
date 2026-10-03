import 'package:shared_preferences/shared_preferences.dart';

/// Manages local persistent preferences for FunDice.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _keyToken = 'fundice_token';
  static const String _keyUserId = 'fundice_user_id';
  static const String _keyUserName = 'fundice_user_name';
  static const String _keyServerUrl = 'fundice_server_url';
  static const String _keyHaptics = 'fundice_haptics';
  static const String _keyGamesPlayed = 'fundice_games_played';
  static const String _keyGamesWon = 'fundice_games_won';

  static Future<LocalStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStore(prefs);
  }

  String? get token => _prefs.getString(_keyToken);
  Future<void> setToken(String? token) async {
    if (token == null) {
      await _prefs.remove(_keyToken);
    } else {
      await _prefs.setString(_keyToken, token);
    }
  }

  String? get userId => _prefs.getString(_keyUserId);
  Future<void> setUserId(String? id) async {
    if (id == null) {
      await _prefs.remove(_keyUserId);
    } else {
      await _prefs.setString(_keyUserId, id);
    }
  }

  String? get userName => _prefs.getString(_keyUserName);
  Future<void> setUserName(String? name) async {
    if (name == null) {
      await _prefs.remove(_keyUserName);
    } else {
      await _prefs.setString(_keyUserName, name);
    }
  }

  String? get serverUrl => _prefs.getString(_keyServerUrl);
  Future<void> setServerUrl(String? url) async {
    if (url == null) {
      await _prefs.remove(_keyServerUrl);
    } else {
      await _prefs.setString(_keyServerUrl, url);
    }
  }

  bool get hapticsEnabled => _prefs.getBool(_keyHaptics) ?? true;
  Future<void> setHapticsEnabled(bool enabled) async {
    await _prefs.setBool(_keyHaptics, enabled);
  }

  int get gamesPlayed => _prefs.getInt(_keyGamesPlayed) ?? 0;
  int get gamesWon => _prefs.getInt(_keyGamesWon) ?? 0;

  Future<void> recordGameFinished({required bool won}) async {
    final played = gamesPlayed + 1;
    final wins = gamesWon + (won ? 1 : 0);
    await _prefs.setInt(_keyGamesPlayed, played);
    await _prefs.setInt(_keyGamesWon, wins);
  }

  static const String _keyAliasesPrefix = 'fundice_alias_';

  String? getAlias(String userId) => _prefs.getString('$_keyAliasesPrefix$userId');

  Future<void> setAlias(String userId, String alias) async {
    final clean = alias.trim();
    if (clean.isEmpty) {
      await _prefs.remove('$_keyAliasesPrefix$userId');
    } else {
      await _prefs.setString('$_keyAliasesPrefix$userId', clean);
    }
  }

  Future<void> clearIdentity() async {
    await _prefs.remove(_keyToken);
    await _prefs.remove(_keyUserId);
    await _prefs.remove(_keyUserName);
  }
}
