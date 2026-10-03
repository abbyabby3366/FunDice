import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/haptics.dart';

enum AppButtonStyle { primary, secondary, destructive, ghost }

/// Standardized action button for FunDice adhering to M3 & SPEC conventions:
/// - 52 dp height (comfortably above 48 dp touch target rule)
/// - 14 dp border radius
/// - Loading indicator
/// - Tactile haptic feedback
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.style = AppButtonStyle.primary,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    BorderSide border = BorderSide.none;

    switch (style) {
      case AppButtonStyle.primary:
        bg = AppColors.primary;
        fg = Colors.white;
        break;
      case AppButtonStyle.secondary:
        bg = AppColors.surface;
        fg = AppColors.primary;
        border = const BorderSide(color: AppColors.border, width: 1.5);
        break;
      case AppButtonStyle.destructive:
        bg = AppColors.danger;
        fg = Colors.white;
        break;
      case AppButtonStyle.ghost:
        bg = Colors.transparent;
        fg = AppColors.textSecondary;
        break;
    }

    final disabled = onPressed == null || loading;
    if (disabled && style != AppButtonStyle.ghost) {
      bg = bg.withValues(alpha: 0.5);
      fg = fg.withValues(alpha: 0.7);
    }

    Widget content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          ),
          const SizedBox(width: 10),
        ] else if (icon != null) ...[
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: fg,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ],
    );

    return SizedBox(
      width: expand ? double.infinity : null,
      height: 52,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: border,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: disabled
              ? null
              : () {
                  AppHaptics.buttonPress();
                  onPressed?.call();
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: content,
          ),
        ),
      ),
    );
  }
}
