import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/date_formatter.dart';
import '../core/utils/haptics.dart';
import '../state/app_controller.dart';
import '../state/app_scope.dart';
import '../widgets/app_button.dart';
import '../widgets/dice_row.dart';
import '../widgets/felt_panel.dart';
import '../widgets/rolling_dice.dart';
import '../widgets/section_header.dart';

/// The Roll Tab: lets players roll their 5 dice, view frequencies, and review recent roll history.
class RollScreen extends StatefulWidget {
  const RollScreen({super.key});

  @override
  State<RollScreen> createState() => _RollScreenState();
}

class _RollScreenState extends State<RollScreen> {
  bool _isRolling = false;
  List<int?> _currentDice = [null, null, null, null, null];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppScope.of(context);
    if (!_isRolling && controller.rolls.isNotEmpty) {
      _currentDice = controller.rolls.last.dice.map((d) => d as int?).toList();
    }
  }

  Future<void> _handleRoll() async {
    if (_isRolling) return;
    setState(() => _isRolling = true);
    AppHaptics.buttonPress();

    final controller = AppScope.of(context);
    try {
      final roll = await controller.roll();
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (mounted) {
        setState(() {
          _currentDice = roll.dice.map((d) => d as int?).toList();
          _isRolling = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isRolling = false);
      }
    }
  }

  Map<int, int> _counts() {
    final map = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};
    for (final d in _currentDice) {
      if (d != null && map.containsKey(d)) {
        map[d] = map[d]! + 1;
      }
    }
    return map;
  }

  int _totalSum() {
    int sum = 0;
    for (final d in _currentDice) {
      if (d != null) sum += d;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final isOnline = controller.serverStatus == ServerStatus.online;
    final counts = _counts();
    final hasRolled = _currentDice.any((d) => d != null);
    final reversedRolls = controller.rolls.reversed.toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'FunDice',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline ? AppColors.success : AppColors.danger,
              ),
            ),
          ],
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.background,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FeltPanel(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  RollingDice(
                    values: _currentDice,
                    rolling: _isRolling,
                    dieSize: 56,
                  ),
                  const SizedBox(height: 18),
                  if (hasRolled && !_isRolling) ...[
                    Text(
                      'Total: ${_totalSum()}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.goldLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '1×${counts[1]}  2×${counts[2]}  3×${counts[3]}  4×${counts[4]}  5×${counts[5]}  6×${counts[6]}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Tap Roll to cast your dice',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: _isRolling ? 'Rolling...' : 'Roll Dice',
              icon: Icons.refresh,
              loading: _isRolling,
              onPressed: _isRolling ? null : _handleRoll,
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                isOnline
                    ? "Friends find you by these dice while you're online."
                    : 'Offline — local roll only.',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader('Recent Rolls'),
            if (reversedRolls.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'No rolls yet. Hit Roll Dice to begin!',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reversedRolls.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final r = reversedRolls[idx];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        // Stacked date and time complying with User Rule #2
                        StackedDateTimeView(
                          dateTime: r.at,
                          isTimePrimary: true,
                        ),
                        const Spacer(),
                        DiceRow(
                          values: r.dice.map((d) => d as int?).toList(),
                          dieSize: 32,
                          spacing: 4,
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
