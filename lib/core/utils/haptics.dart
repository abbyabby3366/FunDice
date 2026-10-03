import 'package:flutter/services.dart';

/// Micro-haptic helper for tactile feedback on dice rolls and interactions.
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

  static void diceSelect() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void success() {
    if (enabled) HapticFeedback.heavyImpact();
  }

  static void rollSettled() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  static void buttonPress() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void warning() {
    if (enabled) HapticFeedback.heavyImpact();
  }

  static void bidPlaced() {
    if (enabled) HapticFeedback.selectionClick();
  }

  static void keypadTap() {
    if (enabled) HapticFeedback.selectionClick();
  }

  static void challengeCalled() {
    if (enabled) HapticFeedback.heavyImpact();
  }
}
