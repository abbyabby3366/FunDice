import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../services/local_store.dart';
import '../state/app_scope.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_toast.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/server_url_dialog.dart';
import 'how_to_play_screen.dart';

/// The Settings Tab: handles profile name updates, haptics, server URL, and gameplay guide.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _editName(BuildContext context) async {
    final controller = AppScope.of(context);
    final textController = TextEditingController(text: controller.user?.name ?? '');

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.surface,
        title: const Text('Change Display Name', style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: textController,
          maxLength: 16,
          decoration: const InputDecoration(
            hintText: 'Enter new name',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(textController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.length >= 2 && context.mounted) {
      try {
        await controller.registerName(newName);
        if (context.mounted) showAppToast(context, 'Name updated to $newName');
      } catch (e) {
        if (context.mounted) showAppToast(context, 'Failed to update name', isError: true);
      }
    }
  }

  Future<void> _handleResetAccount(BuildContext context) async {
    final controller = AppScope.of(context);
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Reset Account & Identity?',
      message: 'This will log you out, delete your stored profile credentials, and return to the onboarding screen.',
      confirmLabel: 'Confirm Reset',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirmed) {
      final store = await LocalStore.create();
      await store.clearIdentity();
      await controller.bootstrap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final user = controller.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.textPrimary),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // Profile Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                AppAvatar(
                  seed: user?.id ?? '',
                  name: user?.name ?? 'Player',
                  size: 52,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Player',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${user?.id ?? 'Not registered'}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                  tooltip: 'Edit name',
                  onPressed: () => _editName(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Preferences
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Tactile Haptics', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  subtitle: const Text('Vibrate on dice rolls, bids, and challenges', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  activeThumbColor: AppColors.primary,
                  value: controller.hapticsEnabled,
                  onChanged: (val) => controller.setHaptics(val),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined, color: AppColors.primary),
                  title: const Text('How to Play', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  subtitle: const Text('Official rules and secret peek mechanics', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const HowToPlayScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dns_outlined, color: AppColors.primary),
                  title: const Text('Server Configuration', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  subtitle: Text(
                    controller.serverUrl.isEmpty ? 'Not set' : controller.serverUrl,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showServerUrlDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Account reset (Rule #9: confirmation required)
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text('Reset Account & Identity', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.danger)),
              subtitle: const Text('Clears local session token and username', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              onTap: () => _handleResetAccount(context),
            ),
          ),
          const SizedBox(height: 28),

          const Center(
            child: Text(
              'FunDice v1.0.0 • Mobile Liar\'s Dice',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
