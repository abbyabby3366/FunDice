import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

const _stateDuration = Duration(milliseconds: 150);
const _ringWidth = 3.0;
const _selectedScale = 1.04;
const _dimmedOpacity = 0.35;

/// How a [DieView] is drawn. Every state is also described to screen readers.
enum DieState {
  /// A plain die.
  normal,

  /// Learned by peeking: gold ring and an eye badge.
  peeked,

  /// Counts towards a result: green ring and a soft glow.
  highlighted,

  /// Faded into the background.
  dimmed,

  /// Chosen by the player: emerald ring, slightly enlarged.
  selected,

  /// An empty slot: a dashed outline instead of a die.
  empty,
}

/// One die, drawn from the SVGs in `assets/images/dice/`.
///
/// [value] is the face (1-6); `null` shows the face-down die.
class DieView extends StatelessWidget {
  const DieView({
    super.key,
    this.value,
    this.size = 56,
    this.state = DieState.normal,
    this.semanticsLabel,
  }) : assert(value == null || (value >= 1 && value <= 6), 'A die shows 1-6');

  final int? value;

  /// Edge length in logical pixels.
  final double size;
  final DieState state;

  /// Replaces the default label: "Die showing 4", "Hidden die" or "Empty die slot".
  final String? semanticsLabel;

  String get _label {
    if (semanticsLabel != null) return semanticsLabel!;
    if (state == DieState.empty) return 'Empty die slot';
    return value == null ? 'Hidden die' : 'Die showing $value';
  }

  String? get _stateDescription => switch (state) {
    DieState.peeked => 'Peeked',
    DieState.highlighted => 'Highlighted',
    _ => null,
  };

  Color? get _ringColor => switch (state) {
    DieState.peeked => AppColors.gold,
    DieState.highlighted => AppColors.success,
    DieState.selected => AppColors.primary,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final isEmpty = state == DieState.empty;
    final ringColor = _ringColor;

    return Semantics(
      label: _label,
      value: _stateDescription,
      selected: state == DieState.selected ? true : null,
      child: ExcludeSemantics(
        child: AnimatedScale(
          scale: state == DieState.selected ? _selectedScale : 1,
          duration: _stateDuration,
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: state == DieState.dimmed ? _dimmedOpacity : 1,
            duration: _stateDuration,
            child: SizedBox.square(
              dimension: size,
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  AnimatedSwitcher(
                    duration: _stateDuration,
                    child: isEmpty
                        ? _EmptySlot(key: const ValueKey('slot'), size: size)
                        : _DieFace(
                            key: const ValueKey('face'),
                            value: value,
                            size: size,
                          ),
                  ),
                  AnimatedContainer(
                    duration: _stateDuration,
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.die(size)),
                      border: Border.all(
                        color: ringColor ?? Colors.transparent,
                        width: math.min(_ringWidth, size * 0.08),
                      ),
                      boxShadow: state == DieState.highlighted
                          ? [
                              BoxShadow(
                                color: AppColors.success.withValues(alpha: 0.45),
                                blurRadius: size * 0.3,
                                spreadRadius: size * 0.01,
                              ),
                            ]
                          : const [],
                    ),
                  ),
                  if (state == DieState.peeked) _EyeBadge(size: size),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _assetFor(int? value) =>
    'assets/images/dice/${value == null ? 'die_hidden' : 'die_$value'}.svg';

class _DieFace extends StatelessWidget {
  const _DieFace({super.key, required this.value, required this.size});

  final int? value;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      _assetFor(value),
      width: size,
      height: size,
      excludeFromSemantics: true,
      // A plain tile of the same colour keeps the die from popping in while the SVG loads.
      placeholderBuilder: (_) => DecoratedBox(
        decoration: BoxDecoration(
          color: value == null ? AppColors.primary : AppColors.dieFace,
          borderRadius: BorderRadius.circular(AppRadius.die(size)),
        ),
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _EmptySlotPainter(radius: AppRadius.die(size)),
    );
  }
}

/// Dashed rounded outline whose dashes divide the perimeter evenly, so the corners look symmetric.
class _EmptySlotPainter extends CustomPainter {
  const _EmptySlotPainter({required this.radius});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    const strokeWidth = 2.0;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(strokeWidth / 2),
          Radius.circular(radius),
        ),
      );
    final paint = Paint()
      ..color = AppColors.textMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (final metric in outline.computeMetrics()) {
      final dashes = math.max(8, (metric.length / (size.shortestSide * 0.2)).round());
      final step = metric.length / dashes;
      for (var i = 0; i < dashes; i++) {
        canvas.drawPath(metric.extractPath(i * step, i * step + step * 0.55), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_EmptySlotPainter oldDelegate) => oldDelegate.radius != radius;
}

/// Small gold eye in the top-right corner of a peeked die.
class _EyeBadge extends StatelessWidget {
  const _EyeBadge({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final diameter = size * 0.34;
    return Positioned(
      top: -diameter * 0.25,
      right: -diameter * 0.25,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: _stateDuration,
        curve: Curves.easeOutBack,
        builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            color: AppColors.gold,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.dieFace, width: 1.5),
          ),
          child: Icon(Icons.visibility, size: diameter * 0.62, color: AppColors.pip),
        ),
      ),
    );
  }
}
