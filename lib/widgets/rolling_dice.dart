import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../core/utils/haptics.dart';
import 'die_view.dart';

/// Animated rolling dice widget with 3D wobble, tumbling faces, and settling bounce.
class RollingDice extends StatefulWidget {
  const RollingDice({
    super.key,
    required this.values,
    required this.rolling,
    this.dieSize = 56,
    this.spacing = 8,
    this.onSettled,
  });

  final List<int?> values;
  final bool rolling;
  final double dieSize;
  final double spacing;
  final VoidCallback? onSettled;

  @override
  State<RollingDice> createState() => _RollingDiceState();
}

class _RollingDiceState extends State<RollingDice> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final math.Random _rng = math.Random();
  Timer? _shuffleTimer;
  late List<int> _displayFaces;

  @override
  void initState() {
    super.initState();
    _displayFaces = _initialFaces();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    if (widget.rolling) {
      _startRolling();
    }
  }

  List<int> _initialFaces() {
    return widget.values.map((v) => v ?? (_rng.nextInt(6) + 1)).toList();
  }

  @override
  void didUpdateWidget(RollingDice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.rolling && widget.rolling) {
      _startRolling();
    } else if (oldWidget.rolling && !widget.rolling) {
      _settleRolling();
    }
  }

  void _startRolling() {
    _controller.repeat();
    _shuffleTimer?.cancel();
    _shuffleTimer = Timer.periodic(const Duration(milliseconds: 75), (_) {
      if (mounted) {
        setState(() {
          _displayFaces = List.generate(
            widget.values.length,
            (_) => _rng.nextInt(6) + 1,
          );
        });
      }
    });
  }

  void _settleRolling() {
    _shuffleTimer?.cancel();
    _shuffleTimer = null;
    _controller.stop();
    _controller.forward(from: 0.0);

    setState(() {
      _displayFaces = widget.values.map((v) => v ?? 1).toList();
    });

    AppHaptics.rollSettled();
    widget.onSettled?.call();
  }

  @override
  void dispose() {
    _shuffleTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        return Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: widget.spacing,
          runSpacing: widget.spacing,
          children: List.generate(widget.values.length, (index) {
            final val = widget.rolling
                ? _displayFaces[index]
                : widget.values[index];

            final wobble = widget.rolling
                ? math.sin((progress * 2 * math.pi) + index) * 0.15
                : 0.0;
            final bounce = widget.rolling
                ? math.cos((progress * 4 * math.pi) + index) * 4.0
                : 0.0;

            return Transform.translate(
              offset: Offset(0, bounce),
              child: Transform.rotate(
                angle: wobble,
                child: DieView(
                  value: val,
                  size: widget.dieSize,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
