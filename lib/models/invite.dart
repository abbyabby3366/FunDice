import 'package:flutter/foundation.dart';

import 'app_user.dart';
import 'json_reader.dart';

enum InviteStatus {
  pending,
  accepted,
  declined,
  cancelled,
  expired;

  /// Unknown statuses count as cancelled so an invitation the app does not understand is dropped.
  static InviteStatus fromWire(Object? raw) => enumFromWire(values, raw) ?? cancelled;
}

/// An invitation to play, sent by [from] to [to].
@immutable
class Invite {
  const Invite({
    required this.id,
    required this.status,
    required this.from,
    required this.to,
    required this.createdAt,
    required this.expiresAt,
  });

  factory Invite.fromJson(Map<String, dynamic> json) {
    return Invite(
      id: json.string('id'),
      status: InviteStatus.fromWire(json['status']),
      from: AppUser.fromJson(json.object('from')),
      to: AppUser.fromJson(json.object('to')),
      createdAt: json.time('createdAt'),
      expiresAt: json.requiredTime('expiresAt'),
    );
  }

  final String id;
  final InviteStatus status;
  final AppUser from;
  final AppUser to;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool get isPending => status == InviteStatus.pending;

  /// Time left until [expiresAt], never negative.
  Duration remaining(DateTime now) {
    final left = expiresAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  @override
  bool operator ==(Object other) =>
      other is Invite &&
      other.id == id &&
      other.status == status &&
      other.from == from &&
      other.to == to &&
      other.createdAt == createdAt &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(id, status, from, to, createdAt, expiresAt);

  @override
  String toString() => 'Invite($id ${status.name} ${from.name} -> ${to.name})';
}
