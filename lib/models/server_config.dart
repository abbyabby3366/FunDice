import 'package:flutter/foundation.dart';

import 'json_reader.dart';

/// Game constants announced by the server in `GET /api/me`.
@immutable
class ServerConfig {
  const ServerConfig({
    this.diceCount = 5,
    this.rollHistory = 5,
    this.peeksPerGame = 3,
    this.inviteTtlSec = 60,
    this.graceSec = 60,
  });

  /// Used until the first snapshot arrives.
  static const ServerConfig defaults = ServerConfig();

  factory ServerConfig.fromJson(Map<String, dynamic> json) {
    return ServerConfig(
      diceCount: json.integerOr('diceCount', defaults.diceCount),
      rollHistory: json.integerOr('rollHistory', defaults.rollHistory),
      peeksPerGame: json.integerOr('peeksPerGame', defaults.peeksPerGame),
      inviteTtlSec: json.integerOr('inviteTtlSec', defaults.inviteTtlSec),
      graceSec: json.integerOr('graceSec', defaults.graceSec),
    );
  }

  /// Dice each player starts a game with.
  final int diceCount;

  /// How many of a player's latest rolls opponents can match against.
  final int rollHistory;
  final int peeksPerGame;

  /// How long an invitation stays open.
  final int inviteTtlSec;

  /// How long a disconnected player has to come back before forfeiting.
  final int graceSec;

  @override
  bool operator ==(Object other) =>
      other is ServerConfig &&
      other.diceCount == diceCount &&
      other.rollHistory == rollHistory &&
      other.peeksPerGame == peeksPerGame &&
      other.inviteTtlSec == inviteTtlSec &&
      other.graceSec == graceSec;

  @override
  int get hashCode => Object.hash(diceCount, rollHistory, peeksPerGame, inviteTtlSec, graceSec);
}
