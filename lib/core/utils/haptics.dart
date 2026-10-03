import 'package:flutter/services.dart';

/// Micro-haptic helper. [enabled] mirrors the user's Settings toggle (set by AppController).
class AppHaptics {
  AppHaptics._();

  static bool enabled = true;

  static void lightImpact() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void mediumImpact() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  static void heavyImpact() {
    if (enabled) HapticFeedback.heavyImpact();
  }

  static void selectionClick() {
    if (enabled) HapticFeedback.selectionClick();
  }

  static void success() {
    if (enabled) HapticFeedback.heavyImpact();
  }
}
