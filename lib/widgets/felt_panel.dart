import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Emerald green felt game panel representing the casino tabletop.
class FeltPanel extends StatelessWidget {
  const FeltPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.border = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const RadialGradient(
          center: Alignment(0.0, -0.2),
          radius: 1.1,
          colors: [
            AppColors.feltLight,
            AppColors.felt,
            AppColors.feltDark,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.feltDark.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: border
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.5,
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
