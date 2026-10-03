import 'package:flutter/material.dart';
import 'die_view.dart';

/// A horizontal row/wrap of dice with configurable size, spacing, and states.
class DiceRow extends StatelessWidget {
  const DiceRow({
    super.key,
    required this.values,
    this.dieSize = 56,
    this.spacing = 8,
    this.states = const {},
    this.alignment = WrapAlignment.center,
    this.onDieTap,
  });

  final List<int?> values;
  final double dieSize;
  final double spacing;
  final Map<int, DieState> states;
  final WrapAlignment alignment;
  final void Function(int index)? onDieTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: alignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: spacing,
      runSpacing: spacing,
      children: List.generate(values.length, (index) {
        final dieWidget = DieView(
          value: values[index],
          size: dieSize,
          state: states[index] ?? DieState.normal,
        );

        if (onDieTap == null) return dieWidget;
        return GestureDetector(
          onTap: () => onDieTap!(index),
          child: dieWidget,
        );
      }),
    );
  }
}
