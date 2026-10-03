import 'package:flutter/material.dart';

import '../core/constants/app_config.dart';
import '../core/theme/app_colors.dart';
import '../services/api_client.dart';
import '../state/app_scope.dart';
import 'app_button.dart';
import 'app_toast.dart';

/// Modal dialog allowing the player to configure and test the game server URL.
Future<void> showServerUrlDialog(BuildContext context) async {
  final controller = AppScope.of(context);
  final textController = TextEditingController(text: controller.serverUrl);
  bool isTesting = false;
  String? testResult;
  bool testSuccess = false;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        Future<void> testConnection() async {
          setState(() {
            isTesting = true;
            testResult = null;
          });
          final input = textController.text.trim();
          final normalized = AppConfig.normalizeServerUrl(input);
          if (normalized == null) {
            setState(() {
              isTesting = false;
              testResult = 'Invalid URL format';
              testSuccess = false;
            });
            return;
          }

          final tester = ApiClient(baseUrl: normalized);
          final ok = await tester.warmUp();
          setState(() {
            isTesting = false;
            testSuccess = ok;
            testResult = ok ? 'Connected successfully! (HTTP 200 OK)' : 'Failed to reach server at $normalized';
          });
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.surface,
          title: const Text(
            'Server Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter the FunDice backend server address. For local physical device USB debugging, use your PC local IP or http://10.0.2.2:3000.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  autocorrect: false,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'Server Address',
                    hintText: 'http://192.168.x.x:3000',
                    filled: true,
                    fillColor: AppColors.surfaceMuted,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.computer, size: 14, color: AppColors.primary),
                      label: const Text('Local (3000)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      backgroundColor: AppColors.surfaceMuted,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onPressed: () {
                        textController.text = 'http://127.0.0.1:3000';
                        testConnection();
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.cloud_queue, size: 14, color: AppColors.primary),
                      label: const Text('Render Cloud', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      backgroundColor: AppColors.surfaceMuted,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onPressed: () {
                        textController.text = 'https://fundice.onrender.com';
                        testConnection();
                      },
                    ),
                  ],
                ),
                if (testResult != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        testSuccess ? Icons.check_circle : Icons.error,
                        size: 16,
                        color: testSuccess ? AppColors.success : AppColors.danger,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          testResult!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: testSuccess ? AppColors.success : AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                AppButton(
                  label: 'Test Connection',
                  style: AppButtonStyle.secondary,
                  loading: isTesting,
                  onPressed: isTesting ? null : testConnection,
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Cancel',
                    style: AppButtonStyle.secondary,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Save',
                    style: AppButtonStyle.primary,
                    onPressed: () async {
                      final url = textController.text.trim();
                      await controller.setServerUrl(url);
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                        showAppToast(context, 'Server address updated');
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}
