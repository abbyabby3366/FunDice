import 'dart:async';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/haptics.dart';
import '../state/app_controller.dart';
import '../state/app_scope.dart';
import '../widgets/app_button.dart';
import '../widgets/felt_panel.dart';
import '../widgets/rolling_dice.dart';
import '../widgets/secret_keypad_sheet.dart';

/// The Roll Tab: lets players roll their 5 dice, view frequencies, and review recent roll history.
/// Contains a discreet secret trigger (tapping Help 5 times) to open the Secret Opponent Keypad.
class RollScreen extends StatefulWidget {
  const RollScreen({super.key});

  @override
  State<RollScreen> createState() => _RollScreenState();
}

class _RollScreenState extends State<RollScreen> {
  bool _isRolling = false;
  List<int?> _currentDice = [null, null, null, null, null];

  // Secret 5-tap detector on Help icon
  int _helpTapCount = 0;
  DateTime? _lastHelpTap;
  Timer? _helpTapTimer;

  @override
  void dispose() {
    _helpTapTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppScope.of(context);
    if (!_isRolling && controller.rolls.isNotEmpty) {
      _currentDice = controller.rolls.last.dice.map((d) => d as int?).toList();
    }
  }

  void _onHelpTap() {
    final now = DateTime.now();
    if (_lastHelpTap == null ||
        now.difference(_lastHelpTap!) > const Duration(seconds: 2)) {
      _helpTapCount = 1;
    } else {
      _helpTapCount++;
    }
    _lastHelpTap = now;

    if (_helpTapCount >= 5) {
      _helpTapTimer?.cancel();
      _helpTapCount = 0;
      AppHaptics.diceSelect(); // Subtle tactile haptic buzz on 5th tap
      SecretKeypadSheet.show(context);
    } else {
      _helpTapTimer?.cancel();
      _helpTapTimer = Timer(const Duration(milliseconds: 350), () {
        if (_helpTapCount == 1 && mounted) {
          _showHelpDialog();
        }
      });
    }
  }

  void _showHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.surface,
        title: const Text('Rolling Dice',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Tap "Roll Dice" to cast all 5 dice on the felt tray.\n\n'
          'Your roll is saved in your history and synchronized with the server when you are connected.',
          style: TextStyle(
              fontSize: 14.5, height: 1.4, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
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
    final hasRolled = _currentDice.any((d) => d != null);

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
        actions: [
          IconButton(
            tooltip: 'Help',
            icon: const Icon(Icons.help_outline,
                color: AppColors.textSecondary),
            onPressed: _onHelpTap,
          ),
        ],
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.background,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Felt dice tray
            FeltPanel(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  RollingDice(
                    values: _currentDice,
                    rolling: _isRolling,
                    dieSize: 56,
                    spacing: 12,
                  ),
                  const SizedBox(height: 18),
                  if (hasRolled && !_isRolling) ...[
                    Text(
                      'Total: ${_totalSum()}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.goldLight,
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
            const SizedBox(height: 20),
            AppButton(
              label: _isRolling ? 'Rolling...' : 'Roll Dice',
              icon: Icons.casino_outlined,
              loading: _isRolling,
              onPressed: _isRolling ? null : _handleRoll,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
