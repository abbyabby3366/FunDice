import 'package:flutter/foundation.dart';
import 'json_reader.dart';

@immutable
class Bid {
  const Bid({required this.by, required this.quantity, required this.face});

  factory Bid.fromJson(Map<String, dynamic> json) {
    return Bid(
      by: json.string('by'),
      quantity: json.integer('quantity'),
      face: json.integer('face'),
    );
  }

  final String by; // 'you' | 'opponent'
  final int quantity;
  final int face;

  Map<String, dynamic> toJson() => {'by': by, 'quantity': quantity, 'face': face};

  @override
  String toString() => '$quantity × $face (by $by)';
}

@immutable
class GamePlayer {
  const GamePlayer({
    required this.id,
    required this.name,
    required this.diceCount,
    required this.peeksLeft,
  });

  factory GamePlayer.fromJson(Map<String, dynamic> json) {
    return GamePlayer(
      id: json.string('id'),
      name: json.string('name'),
      diceCount: json.integerOr('diceCount', 5),
      peeksLeft: json.integerOr('peeksLeft', 3),
    );
  }

  final String id;
  final String name;
  final int diceCount;
  final int peeksLeft;
}

@immutable
class GameOpponent {
  const GameOpponent({
    required this.id,
    required this.name,
    required this.diceCount,
    required this.online,
    this.offlineDeadline,
  });

  factory GameOpponent.fromJson(Map<String, dynamic> json) {
    return GameOpponent(
      id: json.string('id'),
      name: json.string('name'),
      diceCount: json.integerOr('diceCount', 5),
      online: json.boolOr('online', true),
      offlineDeadline: json.timeOrNull('offlineDeadline'),
    );
  }

  final String id;
  final String name;
  final int diceCount;
  final bool online;
  final DateTime? offlineDeadline;
}

@immutable
class SeenDie {
  const SeenDie({required this.index, required this.value});

  factory SeenDie.fromJson(Map<String, dynamic> json) {
    return SeenDie(
      index: json.integer('index'),
      value: json.integer('value'),
    );
  }

  final int index;
  final int value;
}

@immutable
class RoundResult {
  const RoundResult({
    required this.round,
    required this.bid,
    required this.challenger,
    required this.total,
    required this.bidHeld,
    required this.loser,
    required this.yourHand,
    required this.opponentHand,
  });

  factory RoundResult.fromJson(Map<String, dynamic> json) {
    final handsObj = json.objectOrNull('hands');
    final your = handsObj?['you'];
    final opp = handsObj?['opponent'];
    return RoundResult(
      round: json.integerOr('round', 1),
      bid: Bid.fromJson(json.object('bid')),
      challenger: json.string('challenger'),
      total: json.integerOr('total', 0),
      bidHeld: json.boolOr('bidHeld', false),
      loser: json.string('loser'),
      yourHand: your is List ? your.whereType<num>().map((e) => e.toInt()).toList() : const [],
      opponentHand: opp is List ? opp.whereType<num>().map((e) => e.toInt()).toList() : const [],
    );
  }

  final int round;
  final Bid bid;
  final String challenger;
  final int total;
  final bool bidHeld;
  final String loser;
  final List<int> yourHand;
  final List<int> opponentHand;
}

@immutable
class GameLogEntry {
  const GameLogEntry({
    required this.id,
    required this.type,
    required this.actor,
    required this.text,
    required this.notify,
    required this.at,
  });

  factory GameLogEntry.fromJson(Map<String, dynamic> json) {
    return GameLogEntry(
      id: json.integerOr('id', 0),
      type: json.stringOrNull('type') ?? 'log',
      actor: json.stringOrNull('actor') ?? '',
      text: json.stringOrNull('text') ?? '',
      notify: json.boolOr('notify', false),
      at: json.time('at'),
    );
  }

  final int id;
  final String type;
  final String actor;
  final String text;
  final bool notify;
  final DateTime at;
}

@immutable
class GameView {
  const GameView({
    required this.id,
    required this.version,
    required this.status,
    required this.round,
    required this.turn,
    required this.you,
    required this.opponent,
    required this.myDice,
    this.bid,
    required this.peeks,
    required this.exposed,
    this.lastRound,
    this.winner,
    this.endReason,
    required this.log,
    required this.updatedAt,
  });

  factory GameView.fromJson(Map<String, dynamic> json) {
    final myDiceRaw = json['myDice'];
    final peeksRaw = json['peeks'];
    final expRaw = json['exposed'];
    final logRaw = json['log'];

    return GameView(
      id: json.string('id'),
      version: json.integerOr('version', 1),
      status: json.stringOrNull('status') ?? 'playing',
      round: json.integerOr('round', 1),
      turn: json.stringOrNull('turn') ?? 'you',
      you: GamePlayer.fromJson(json.object('you')),
      opponent: GameOpponent.fromJson(json.object('opponent')),
      myDice: myDiceRaw is List ? myDiceRaw.whereType<num>().map((e) => e.toInt()).toList() : const [],
      bid: json.containsKey('bid') && json['bid'] != null ? Bid.fromJson(json.object('bid')) : null,
      peeks: peeksRaw is List
          ? peeksRaw.whereType<Map<String, dynamic>>().map(SeenDie.fromJson).toList()
          : const [],
      exposed: expRaw is List
          ? expRaw.whereType<Map<String, dynamic>>().map(SeenDie.fromJson).toList()
          : const [],
      lastRound: json.containsKey('lastRound') && json['lastRound'] != null
          ? RoundResult.fromJson(json.object('lastRound'))
          : null,
      winner: json.stringOrNull('winner'),
      endReason: json.stringOrNull('endReason'),
      log: logRaw is List
          ? logRaw.whereType<Map<String, dynamic>>().map(GameLogEntry.fromJson).toList()
          : const [],
      updatedAt: json.time('updatedAt'),
    );
  }

  final String id;
  final int version;
  final String status; // 'playing' | 'finished'
  final int round;
  final String turn; // 'you' | 'opponent'
  final GamePlayer you;
  final GameOpponent opponent;
  final List<int> myDice;
  final Bid? bid;
  final List<SeenDie> peeks;
  final List<SeenDie> exposed;
  final RoundResult? lastRound;
  final String? winner; // 'you' | 'opponent' | null
  final String? endReason; // 'dice_lost' | 'forfeit' | 'disconnect' | null
  final List<GameLogEntry> log;
  final DateTime updatedAt;

  bool get isMyTurn => turn == 'you';
  bool get isFinished => status == 'finished';
  int get totalDice => you.diceCount + opponent.diceCount;
  bool get iWon => winner == 'you';

  Bid get minimumNextBid {
    final current = bid;
    if (current == null) {
      return const Bid(by: 'you', quantity: 1, face: 1);
    }
    if (current.face < 6) {
      return Bid(by: 'you', quantity: current.quantity, face: current.face + 1);
    }
    return Bid(by: 'you', quantity: current.quantity + 1, face: 1);
  }

  bool isLegalBid(int quantity, int face) {
    if (quantity < 1 || quantity > totalDice) return false;
    if (face < 1 || face > 6) return false;
    final current = bid;
    if (current == null) return true;
    if (quantity > current.quantity) return true;
    if (quantity == current.quantity && face > current.face) return true;
    return false;
  }
}
