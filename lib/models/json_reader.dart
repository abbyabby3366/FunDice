/// Typed accessors for decoded JSON objects, used by the model factories.
///
/// Values the app cannot work without throw a [FormatException] that names the key;
/// optional ones fall back to a default, so unknown or missing extras never break parsing.
extension JsonReader on Map<String, dynamic> {
  String string(String key) {
    final value = this[key];
    if (value is String) return value;
    throw FormatException('Expected "$key" to be a string, got ${_describe(value)}.');
  }

  String? stringOrNull(String key) {
    final value = this[key];
    return value is String ? value : null;
  }

  int integer(String key) {
    final value = this[key];
    if (value is num) return value.toInt();
    throw FormatException('Expected "$key" to be a number, got ${_describe(value)}.');
  }

  int integerOr(String key, int fallback) {
    final value = this[key];
    return value is num ? value.toInt() : fallback;
  }

  int? integerOrNull(String key) {
    final value = this[key];
    return value is num ? value.toInt() : null;
  }

  bool boolOr(String key, bool fallback) {
    final value = this[key];
    return value is bool ? value : fallback;
  }

  /// A timestamp that is only displayed: unreadable or missing values become the Unix epoch.
  DateTime time(String key) => timeOrNull(key) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  /// A timestamp the app acts on (for example an expiry).
  DateTime requiredTime(String key) {
    final value = timeOrNull(key);
    if (value != null) return value;
    throw FormatException('Expected "$key" to be an ISO-8601 timestamp, got ${_describe(this[key])}.');
  }

  DateTime? timeOrNull(String key) {
    final value = this[key];
    return value is String ? DateTime.tryParse(value) : null;
  }

  Map<String, dynamic> object(String key) {
    final value = this[key];
    if (value is Map<String, dynamic>) return value;
    throw FormatException('Expected "$key" to be an object, got ${_describe(value)}.');
  }

  Map<String, dynamic>? objectOrNull(String key) {
    final value = this[key];
    return value is Map<String, dynamic> ? value : null;
  }

  /// Parses an array of objects; a missing array is empty and non-object entries are skipped.
  List<T> list<T>(String key, T Function(Map<String, dynamic> json) parse) {
    final value = this[key];
    if (value is! List) return const [];
    return List<T>.unmodifiable([
      for (final entry in value)
        if (entry is Map<String, dynamic>) parse(entry),
    ]);
  }

  /// A required array of integers (dice).
  List<int> intList(String key) {
    final value = this[key];
    if (value is List && value.every((entry) => entry is num)) {
      return List<int>.unmodifiable([for (final entry in value) (entry as num).toInt()]);
    }
    throw FormatException('Expected "$key" to be a list of numbers, got ${_describe(value)}.');
  }
}

/// The wire name of an enum value: `diceLost` is `dice_lost` on the server.
String wireName(Enum value) =>
    value.name.replaceAllMapped(RegExp('[A-Z]'), (match) => '_${match[0]!.toLowerCase()}');

/// Finds the enum value whose [wireName] equals [raw], or null.
T? enumFromWire<T extends Enum>(List<T> values, Object? raw) {
  for (final value in values) {
    if (wireName(value) == raw) return value;
  }
  return null;
}

String _describe(Object? value) => value == null ? 'null' : value.runtimeType.toString();
