import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/haptics.dart';
import '../models/api_exception.dart';
import '../models/app_user.dart';
import '../models/match_result.dart';
import '../state/app_scope.dart';
import 'die_view.dart';
import 'secret_opponent_card.dart';

/// Secret bottom sheet triggered by tapping Help 5 times.
/// Immediately sends a signal to the server upon entering the 5th die to identify
/// which online user is playing, supports 2nd-roll disambiguation, and saves player aliases.
class SecretKeypadSheet extends StatefulWidget {
  const SecretKeypadSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SecretKeypadSheet(),
    );
  }

  @override
  State<SecretKeypadSheet> createState() => _SecretKeypadSheetState();
}

class _SecretKeypadSheetState extends State<SecretKeypadSheet> {
  final List<int> _firstRoll = [];
  final List<int> _secondRoll = [];
  bool _isSecondRoll = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Identified opponent result
  AppUser? _matchedOpponent;

  void _onDieTap(int face) {
    if (_isLoading) return;
    AppHaptics.keypadTap();

    setState(() {
      _errorMessage = null;
      if (!_isSecondRoll) {
        if (_firstRoll.length < 5) {
          _firstRoll.add(face);
          if (_firstRoll.length == 5) {
            _performMatch();
          }
        }
      } else {
        if (_secondRoll.length < 5) {
          _secondRoll.add(face);
          if (_secondRoll.length == 5) {
            _performMatch();
          }
        }
      }
    });
  }

  void _onBackspace() {
    if (_isLoading) return;
    AppHaptics.buttonPress();
    setState(() {
      _errorMessage = null;
      if (!_isSecondRoll) {
        if (_firstRoll.isNotEmpty) _firstRoll.removeLast();
      } else {
        if (_secondRoll.isNotEmpty) {
          _secondRoll.removeLast();
        } else {
          _isSecondRoll = false;
        }
      }
    });
  }

  void _reset() {
    setState(() {
      _firstRoll.clear();
      _secondRoll.clear();
      _isSecondRoll = false;
      _isLoading = false;
      _errorMessage = null;
      _matchedOpponent = null;
    });
  }

  Future<void> _performMatch() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final controller = AppScope.of(context);
    try {
      final res = await controller.match(
        _firstRoll,
        next: _isSecondRoll ? _secondRoll : null,
      );

      if (res.status == MatchStatus.matched && res.opponent != null) {
        setState(() {
          _isLoading = false;
          _matchedOpponent = res.opponent;
        });
        AppHaptics.lightImpact();
      } else if (res.status == MatchStatus.ambiguous) {
        setState(() {
          _isLoading = false;
          _isSecondRoll = true;
          _secondRoll.clear();
        });
        AppHaptics.warning();
      } else if (res.status == MatchStatus.busy && res.opponent != null) {
        setState(() {
          _isLoading = false;
          _matchedOpponent = res.opponent;
          _errorMessage = 'Player is currently in another match.';
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'No online player found with these dice in the past 5 rounds.';
        });
        AppHaptics.warning();
      }
    } on ApiException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not reach server. Check network connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/secret_detect_badge.jpg',
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.verified_outlined,
                            size: 24,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dice Verification',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Spectator Roll Scanner',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (_matchedOpponent != null)
                SecretOpponentCard(
                  opponent: _matchedOpponent!,
                  onIdentifyAnother: _reset,
                  onDone: () => Navigator.of(context).pop(),
                )
              else ...[
                Text(
                  _isSecondRoll
                      ? 'Ambiguous match! Type their 2nd roll to confirm:'
                      : 'Type the 5 dice your spectator rolled:',
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        _isSecondRoll ? AppColors.gold : AppColors.textSecondary,
                    fontWeight:
                        _isSecondRoll ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),

                // 5 Dice display slots
                _buildDiceSlots(),
                const SizedBox(height: 16),

                if (_isLoading) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Identifying player across past 5 rounds...',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 18,
                            color: AppColors.danger,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.danger,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Keypad
                  _buildKeypad(),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiceSlots() {
    final currentList = _isSecondRoll ? _secondRoll : _firstRoll;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final hasValue = index < currentList.length;
        final isNext = index == currentList.length;
        final value = hasValue ? currentList[index] : null;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: DieView(
            value: value,
            size: 52,
            state: isNext
                ? DieState.selected
                : (hasValue ? DieState.normal : DieState.empty),
          ),
        );
      }),
    );
  }

  Widget _buildKeypad() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildKey(1),
              _buildKey(2),
              _buildKey(3),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildKey(4),
              _buildKey(5),
              _buildKey(6),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _onBackspace,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.backspace_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Clear Last Die',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKey(int face) {
    return InkWell(
      onTap: () => _onDieTap(face),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 76,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: DieView(value: face, size: 44),
        ),
      ),
    );
  }
}
