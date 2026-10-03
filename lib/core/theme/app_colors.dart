import 'package:flutter/material.dart';

/// FunDice palette (docs/SPEC.md §5): emerald brand, green felt table, ivory dice, gold accents.
///
/// Text contrast (WCAG AA, 4.5:1): [textPrimary] and [textSecondary] work on [background],
/// [surface] and [surfaceMuted]; white works on [primary], [primaryDark], [felt], [feltLight] and
/// the `*Dark` status colours. [textMuted], [gold], [goldDark] and the plain [danger], [success] and
/// [warning] are for icons, borders and decoration only, never for body text on light surfaces.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF0E7A5F);
  static const Color primaryDark = Color(0xFF0A5C47);
  static const Color primaryLight = Color(0xFFD6F2E8);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Felt table
  static const Color felt = Color(0xFF0B5D46);
  static const Color feltDark = Color(0xFF08473A);
  static const Color feltLight = Color(0xFF0F7357);

  // Gold: bids, peeks, winner
  static const Color gold = Color(0xFFF2B632);
  static const Color goldDark = Color(0xFFB9851A);
  static const Color goldLight = Color(0xFFFFF3D1);

  // Dice
  static const Color dieFace = Color(0xFFFFFCF2);
  static const Color dieEdge = Color(0xFFE6DFCB);
  static const Color pip = Color(0xFF1F2328);
  static const Color pipRed = Color(0xFFD93636);

  // Surfaces
  static const Color background = Color(0xFFF6F7F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEEF0EC);
  static const Color border = Color(0xFFE2E5DF);

  // Text
  static const Color textPrimary = Color(0xFF14181B);
  static const Color textSecondary = Color(0xFF5E6A66);
  static const Color textMuted = Color(0xFF98A29E);

  // Status. The plain colours are for icons, rings and borders; the *Dark variants carry text
  // (and white text on top of them) and the *Light tints are for banner backgrounds.
  static const Color danger = Color(0xFFE5484D);
  static const Color dangerDark = Color(0xFFC42B31);
  static const Color dangerLight = Color(0xFFFDEBEC);

  static const Color success = Color(0xFF17A673);
  static const Color successDark = Color(0xFF0E7A52);
  static const Color successLight = Color(0xFFDDF5EB);

  static const Color warning = Color(0xFFF5A524);
  static const Color warningDark = Color(0xFF8A5A00);
  static const Color warningLight = Color(0xFFFEF1D6);

  /// Background colours for [AppAvatar]; every one has white-text contrast of at least 4.5:1.
  static const List<Color> avatarPalette = [
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFFBE185D),
    Color(0xFFC2410C),
    Color(0xFFA16207),
    Color(0xFF15803D),
    Color(0xFF0F766E),
    Color(0xFF475569),
  ];
}
