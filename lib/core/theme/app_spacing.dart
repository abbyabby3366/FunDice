/// Spacing scale (docs/SPEC.md §5): 4 · 8 · 12 · 16 · 24 · 32.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Smallest comfortable tap target.
  static const double minTapTarget = 48;

  /// Height of every standard button.
  static const double buttonHeight = 52;
}

/// Corner radii (docs/SPEC.md §5).
class AppRadius {
  AppRadius._();

  static const double card = 16;
  static const double button = 14;
  static const double dialog = 20;

  /// Top corners of bottom sheets.
  static const double sheet = 24;

  /// Felt panels and other large surfaces.
  static const double panel = 24;

  /// A die's corner radius is this fraction of its edge length.
  static const double dieFraction = 0.18;

  static double die(double size) => size * dieFraction;
}
