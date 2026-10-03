import 'app_user.dart';

enum MatchStatus { matched, busy, ambiguous, notFound }

class MatchResult {
  const MatchResult({
    required this.status,
    this.opponent,
    this.candidates,
  });

  final MatchStatus status;
  final AppUser? opponent;
  final int? candidates;

  @override
  String toString() => 'MatchResult($status, opponent: $opponent, candidates: $candidates)';
}

class PeekResult {
  const PeekResult({
    required this.index,
    required this.value,
    required this.caught,
  });

  final int index;
  final int value;
  final bool caught;

  @override
  String toString() => 'PeekResult(index: $index, value: $value, caught: $caught)';
}
