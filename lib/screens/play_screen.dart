import 'dart:async';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/haptics.dart';
import '../models/api_exception.dart';
import '../models/app_user.dart';
import '../models/match_result.dart';
import '../state/app_scope.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_button.dart';
import '../widgets/app_toast.dart';
import '../widgets/die_view.dart';

/// The Play Tab: lets players type their opponent's 5 dice using a custom keypad to find and challenge them.
class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  final List<int?> _dice = [null, null, null, null, null];
  int _activeSlot = 0;
  bool _isSearching = false;
  MatchResult? _matchResult;
  String? _feedbackMessage;
  bool _isError = false;

  Timer? _autoSubmitTimer;
  Timer? _countdownTimer;
  int _inviteRemainingSec = 60;

  @override
  void dispose() {
    _autoSubmitTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _onKeyPress(int face) {
    AppHaptics.keypadTap();
    setState(() {
      _dice[_activeSlot] = face;
      if (_activeSlot < 4) {
        _activeSlot++;
      }
      _feedbackMessage = null;
      _isError = false;
    });

    if (_dice.every((d) => d != null)) {
      _autoSubmitTimer?.cancel();
      _autoSubmitTimer = Timer(const Duration(milliseconds: 250), _executeSearch);
    }
  }

  void _onBackspace() {
    AppHaptics.keypadTap();
    setState(() {
      if (_dice[_activeSlot] != null) {
        _dice[_activeSlot] = null;
      } else if (_activeSlot > 0) {
        _activeSlot--;
        _dice[_activeSlot] = null;
      }
      _matchResult = null;
      _feedbackMessage = null;
      _isError = false;
    });
  }

  void _clearDice() {
    setState(() {
      for (int i = 0; i < 5; i++) {
        _dice[i] = null;
      }
      _activeSlot = 0;
      _matchResult = null;
      _feedbackMessage = null;
      _isError = false;
    });
  }

  Future<void> _executeSearch() async {
    if (_dice.any((d) => d == null)) return;
    final diceList = _dice.map((d) => d!).toList();

    setState(() {
      _isSearching = true;
      _matchResult = null;
      _feedbackMessage = null;
      _isError = false;
    });

    final controller = AppScope.of(context);
    try {
      final res = await controller.match(diceList);
      if (!mounted) return;
      setState(() {
        _matchResult = res;
        _isSearching = false;
        switch (res.status) {
          case MatchStatus.matched:
            _feedbackMessage = 'Opponent found! Challenge them to a game.';
            _isError = false;
            break;
          case MatchStatus.busy:
            _feedbackMessage = '${res.opponent?.name ?? 'Player'} is currently in a game.';
            _isError = true;
            break;
          case MatchStatus.ambiguous:
            _feedbackMessage = 'Multiple players matched. Ask them to roll again!';
            _isError = true;
            break;
          case MatchStatus.notFound:
            _feedbackMessage = 'No online player has rolled these dice recently. Check order and try again.';
            _isError = true;
            AppHaptics.warning();
            break;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _feedbackMessage = e.message;
        _isError = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _feedbackMessage = 'Failed to search. Check connection.';
        _isError = true;
      });
    }
  }

  Future<void> _sendChallenge(AppUser opponent) async {
    final controller = AppScope.of(context);
    try {
      await controller.sendInvite(opponent);
      _startInviteCountdown();
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message, isError: true);
    }
  }

  void _startInviteCountdown() {
    _inviteRemainingSec = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final controller = AppScope.of(context);
      if (controller.outgoingInvite == null) {
        t.cancel();
        return;
      }
      if (_inviteRemainingSec <= 1) {
        t.cancel();
        controller.cancelOutgoingInvite();
      } else {
        setState(() => _inviteRemainingSec--);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final outgoing = controller.outgoingInvite;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Find Opponent',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all, color: AppColors.textSecondary),
            tooltip: 'Clear dice',
            onPressed: _clearDice,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          children: [
            if (outgoing != null) ...[
              // Outgoing challenge waiting card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    AppAvatar(
                      seed: outgoing.to.id,
                      name: outgoing.to.name,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Waiting for ${outgoing.to.name}...',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Expires in ${_inviteRemainingSec}s',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                      label: 'Cancel Challenge',
                      style: AppButtonStyle.secondary,
                      onPressed: () => controller.cancelOutgoingInvite(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
              const Text(
                'Type the 5 dice your opponent is currently showing, left to right.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // 5 Entry Slots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final val = _dice[index];
                  final isSelected = _activeSlot == index;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _activeSlot = index);
                        AppHaptics.keypadTap();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: isSelected
                              ? Border.all(color: AppColors.primary, width: 2.5)
                              : Border.all(color: AppColors.border, width: 1.2),
                        ),
                        child: DieView(
                          value: val,
                          size: 54,
                          state: isSelected
                              ? DieState.selected
                              : (val == null ? DieState.empty : DieState.normal),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),

              if (_isSearching) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Searching for match...',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ] else if (_feedbackMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isError ? AppColors.dangerLight : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isError ? Icons.info_outline : Icons.check_circle_outline,
                        size: 18,
                        color: _isError ? AppColors.danger : AppColors.primaryDark,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _feedbackMessage!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _isError ? AppColors.danger : AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Matched Card
              if (_matchResult?.status == MatchStatus.matched && _matchResult?.opponent != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      AppAvatar(
                        seed: _matchResult!.opponent!.id,
                        name: _matchResult!.opponent!.name,
                        size: 48,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _matchResult!.opponent!.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Row(
                              children: [
                                Icon(Icons.circle, size: 8, color: AppColors.success),
                                SizedBox(width: 4),
                                Text(
                                  'Online now',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      AppButton(
                        label: 'Challenge',
                        expand: false,
                        onPressed: () => _sendChallenge(_matchResult!.opponent!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Custom Keypad (Dice 1-6 + Backspace)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [1, 2, 3].map((f) => _keypadButton(f)).toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [4, 5, 6].map((f) => _keypadButton(f)).toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _onBackspace,
                            child: Container(
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.backspace_outlined, color: AppColors.textPrimary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _keypadButton(int face) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _onKeyPress(face),
      child: Container(
        padding: const EdgeInsets.all(4),
        child: DieView(
          value: face,
          size: 52,
        ),
      ),
    );
  }
}
