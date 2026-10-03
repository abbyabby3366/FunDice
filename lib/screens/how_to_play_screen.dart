import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Interactive tutorial and rulebook for FunDice (Liar's Dice).
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'How to Play',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.textPrimary),
        ),
        elevation: 0,
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          _buildCard(
            title: '1. The Goal',
            icon: Icons.flag_outlined,
            content: 'Each player begins with 5 dice. You can only see your own dice. '
                'Players take turns bidding on the total number of dice showing a specific face across BOTH hands on the table. '
                'The last player with dice remaining wins the game!',
          ),
          const SizedBox(height: 14),
          _buildCard(
            title: '2. Taking Turns & Bidding',
            icon: Icons.trending_up,
            content: 'On your turn, you must either raise the current bid or call "Liar!".\n\n'
                'To raise a bid, you must:\n'
                '• Increase the quantity of dice (e.g. 3 × ⚃ becomes 4 × ⚁), OR\n'
                '• Keep the same quantity but increase the face value (e.g. 3 × ⚃ becomes 3 × ⚄).\n\n'
                'The first bid of any round is free.',
          ),
          const SizedBox(height: 14),
          _buildCard(
            title: '3. Calling "Liar!"',
            icon: Icons.gavel_outlined,
            content: 'If you believe the opponent\'s bid is higher than the actual number of matching dice on the table, call "Liar!".\n\n'
                'Both hands are revealed:\n'
                '• If there are AT LEAST as many dice as bid: the bid held, and the challenger loses 1 die.\n'
                '• If there are FEWER dice than bid: the bidder bluffed, and the bidder loses 1 die.',
          ),
          const SizedBox(height: 14),
          _buildCard(
            title: '4. Secret Peek (The Catch)',
            icon: Icons.visibility_outlined,
            content: 'Each player has 3 secret Peeks per match.\n\n'
                'A peek secretly reveals 1 random die from your opponent\'s hand.\n\n'
                'BEWARE: Every peek has a 30% chance of being CAUGHT! If caught, the opponent is notified and one of your own dice is exposed in return!',
          ),
          const SizedBox(height: 14),
          _buildCard(
            title: '5. Pairing Without Lobby Codes',
            icon: Icons.qr_code_scanner,
            content: 'FunDice does not require room codes. On the Roll tab, roll your dice. '
                'To challenge a friend, go to the Play tab and type the 5 dice your friend currently shows on their screen, left to right. '
                'FunDice instantly matches you and sends the challenge!',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required IconData icon, required String content}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
