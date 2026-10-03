import 'package:flutter/foundation.dart';

import 'json_reader.dart';

/// One roll of the player's dice.
///
/// Server rolls have a `seq` (1, 2, 3, ...) and are what opponents match against.
/// A roll made while offline is local only: `shared == false` and `seq == 0`.
@immutable
class Roll {
  const Roll({required this.seq, required this.dice, required this.at, this.shared = true});

  factory Roll.fromJson(Map<String, dynamic> json) {
    return Roll(seq: json.integer('seq'), dice: json.intList('dice'), at: json.time('at'));
  }

  final int seq;

  /// Face values, left to right.
  final List<int> dice;
  final DateTime at;

  /// False for the local fallback roll made while offline.
  final bool shared;

  /// Sum of all faces.
  int get total => dice.fold(0, (sum, face) => sum + face);

  /// How many dice show [face].
  int countOf(int face) => dice.where((die) => die == face).length;

  @override
  bool operator ==(Object other) =>
      other is Roll &&
      other.seq == seq &&
      other.at == at &&
      other.shared == shared &&
      listEquals(other.dice, dice);

  @override
  int get hashCode => Object.hash(seq, at, shared, Object.hashAll(dice));

  @override
  String toString() => 'Roll(#$seq ${dice.join(' ')}${shared ? '' : ', local'})';
}
