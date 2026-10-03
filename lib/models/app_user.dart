import 'package:flutter/foundation.dart';

import 'json_reader.dart';

/// A player as the server knows them: a stable id and a display name.
@immutable
class AppUser {
  const AppUser({required this.id, required this.name});

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(id: json.string('id'), name: json.string('name'));
  }

  final String id;
  final String name;

  @override
  bool operator ==(Object other) => other is AppUser && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'AppUser($id, $name)';
}
