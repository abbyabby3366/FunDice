import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/haptics.dart';
import '../models/api_exception.dart';
import '../models/game_view.dart';
import '../state/app_scope.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_button.dart';
import '../widgets/app_toast.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/dice_row.dart';
import '../widgets/die_view.dart';
import '../widgets/felt_panel.dart';

/// The live Liar's Dice match arena.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int _bidQuantity = 1;
  int _bidFace = 1;
  bool _isActionInProgress = false;
  int _lastHandledRound = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppScope.of(context);
    final game = controller.game;

    if (game == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return;
    }

    // Set initial bid stepper to minimum legal bid
    final minBid = game.minimumNextBid;
    if (_bidQuantity < minBid.quantity || (_bidQuantity == minBid.quantity && _bidFace < minBid.face)) {
      _bidQuantity = minBid.quantity;
      _bidFace = minBid.face;
    }

    // Show round result sheet if a new round just resolved
    final lastRound = game.lastRound;
    if (lastRound != null && lastRound.round != _lastHandledRound && !game.isFinished) {
      _lastHandledRound = lastRound.round;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showRoundResultDialog(lastRound);
      });
    }
  }

  Future<void> _handleForfeit() async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Leave Game?',
      message: "If you leave an ongoing match, you will automatically forfeit the game.",
      confirmLabel: 'Forfeit & Leave',
      cancelLabel: 'Stay & Play',
      isDestructive: true,
    );

    if (confirmed && mounted) {
      final controller = AppScope.of(context);
      await controller.leaveGame();
      if (mounted) Navigator.of(context).maybePop();
    }
  }

  Future<void> _placeBid(GameView game) async {
    if (!game.isLegalBid(_bidQuantity, _bidFace)) {
      showAppToast(context, 'Bid must be higher than current bid.', isError: true);
      return;
    }
    setState(() => _isActionInProgress = true);
    final controller = AppScope.of(context);
    try {
      await controller.bid(_bidQuantity, _bidFace);
      AppHaptics.bidPlaced();
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _callLiar() async {
    setState(() => _isActionInProgress = true);
    final controller = AppScope.of(context);
    try {
      await controller.challenge();
      AppHaptics.challengeCalled();
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _peek() async {
    setState(() => _isActionInProgress = true);
    final controller = AppScope.of(context);
    try {
      final res = await controller.peek();
      if (mounted) {
        showAppToast(
          context,
          res.caught
              ? "You peeked at opponent's die (${res.value}), BUT you got caught!"
              : "Secret peek revealed die: ${res.value}",
        );
      }
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  void _showRoundResultDialog(RoundResult result) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.surface,
        title: Text(
          result.bidHeld ? 'Challenge Failed!' : 'Bluff Called!',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${result.challenger == 'you' ? 'You' : 'Opponent'} called Liar on ${result.bid.quantity} × ${result.bid.face}.\n'
              'Total on table: ${result.total}. ${result.loser == 'you' ? 'You lose 1 die!' : 'Opponent loses 1 die!'}',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 16),
            const Text('Your Hand:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DiceRow(
              values: result.yourHand.map((d) => d as int?).toList(),
              dieSize: 34,
              spacing: 6,
            ),
            const SizedBox(height: 12),
            const Text("Opponent's Hand:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DiceRow(
              values: result.opponentHand.map((d) => d as int?).toList(),
              dieSize: 34,
              spacing: 6,
            ),
          ],
        ),
        actions: [
          AppButton(
            label: 'Continue',
            expand: true,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final game = controller.game;

    if (game == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (game.isFinished) {
      return _buildGameOverScreen(game);
    }

    final isMyTurn = game.isMyTurn;
    final minBid = game.minimumNextBid;

    // Opponent dice representation (peeked dice are revealed)
    final oppDice = List<int?>.generate(game.opponent.diceCount, (i) {
      final peekMatch = game.peeks.where((p) => p.index == i).toList();
      return peekMatch.isNotEmpty ? peekMatch.first.value : null;
    });

    final oppStates = <int, DieState>{};
    for (int i = 0; i < game.opponent.diceCount; i++) {
      if (oppDice[i] != null) oppStates[i] = DieState.peeked;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: _handleForfeit,
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Round ${game.round}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            const SizedBox(width: 10),
            AppAvatar(seed: game.opponent.id, name: game.opponent.name, size: 28),
            const SizedBox(width: 6),
            Text(
              game.opponent.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // Opponent Hand
            FeltPanel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${game.opponent.name}'s Dice (${game.opponent.diceCount})",
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      if (game.you.peeksLeft > 0)
                        GestureDetector(
                          onTap: _isActionInProgress ? null : _peek,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.visibility, size: 14, color: AppColors.textPrimary),
                                const SizedBox(width: 4),
                                Text(
                                  'Peek (${game.you.peeksLeft})',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DiceRow(
                    values: oppDice,
                    states: oppStates,
                    dieSize: 44,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Active Bid & Turn Pill
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isMyTurn ? AppColors.primary : AppColors.border, width: 1.5),
              ),
              child: Column(
                children: [
                  Text(
                    isMyTurn ? "IT'S YOUR TURN" : "WAITING FOR OPPONENT",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: isMyTurn ? AppColors.primary : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (game.bid != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${game.bid!.by == 'you' ? 'You bid' : "${game.opponent.name} bid"}: ',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${game.bid!.quantity} × ',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.goldDark),
                        ),
                        DieView(value: game.bid!.face, size: 30),
                      ],
                    )
                  else
                    const Text(
                      'No bid placed yet. First bid is free!',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // My Dice Hand
            FeltPanel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Your Dice',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DiceRow(
                    values: game.myDice.map((d) => d as int?).toList(),
                    dieSize: 50,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Turn Action Controls
            if (isMyTurn) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    // Quantity Stepper
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Dice Count:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: _bidQuantity > minBid.quantity
                                  ? () => setState(() => _bidQuantity--)
                                  : null,
                            ),
                            Text(
                              '$_bidQuantity',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: _bidQuantity < game.totalDice
                                  ? () => setState(() => _bidQuantity++)
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(),
                    // Face Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(6, (idx) {
                        final face = idx + 1;
                        final isSelected = _bidFace == face;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _bidFace = face);
                            AppHaptics.keypadTap();
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: isSelected ? Border.all(color: AppColors.primary, width: 2.5) : null,
                            ),
                            child: DieView(value: face, size: 40),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 18),
                    // Action Buttons
                    Row(
                      children: [
                        if (game.bid != null) ...[
                          Expanded(
                            flex: 4,
                            child: AppButton(
                              label: 'Liar!',
                              style: AppButtonStyle.destructive,
                              loading: _isActionInProgress,
                              onPressed: _isActionInProgress ? null : _callLiar,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          flex: 6,
                          child: AppButton(
                            label: 'Bid $_bidQuantity × $_bidFace',
                            style: AppButtonStyle.primary,
                            loading: _isActionInProgress,
                            onPressed: _isActionInProgress ? null : () => _placeBid(game),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverScreen(GameView game) {
    final won = game.iWon;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  won ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                  size: 96,
                  color: won ? AppColors.gold : AppColors.danger,
                ),
                const SizedBox(height: 20),
                Text(
                  won ? 'Victory!' : 'Defeat',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: won ? AppColors.primaryDark : AppColors.danger,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  won
                      ? 'You out-bluffed ${game.opponent.name}!'
                      : '${game.opponent.name} claimed the win this match.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),
                AppButton(
                  label: 'Return to Home',
                  onPressed: () async {
                    final controller = AppScope.of(context);
                    await controller.leaveGame();
                    if (mounted) Navigator.of(context).maybePop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
