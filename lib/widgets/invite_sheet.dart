import 'dart:async';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/haptics.dart';
import '../state/app_scope.dart';
import 'app_avatar.dart';
import 'app_button.dart';

/// Modal bottom sheet presented when an incoming challenge invitation arrives.
Future<void> showInviteSheet(BuildContext context) async {
  final controller = AppScope.of(context);
  final invite = controller.incomingInvite;
  if (invite == null) return;

  AppHaptics.bidPlaced();

  await showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    backgroundColor: AppColors.surface,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          int secondsRemaining() {
            final diff = invite.expiresAt.difference(DateTime.now()).inSeconds;
            return diff > 0 ? diff : 0;
          }

          int remaining = secondsRemaining();
          Timer? timer;
          timer = Timer.periodic(const Duration(seconds: 1), (t) {
            final currentInvite = controller.incomingInvite;
            if (currentInvite == null || currentInvite.id != invite.id) {
              t.cancel();
              if (ctx.mounted) Navigator.of(ctx).pop();
              return;
            }
            final rem = secondsRemaining();
            if (rem <= 0) {
              t.cancel();
              if (ctx.mounted) Navigator.of(ctx).pop();
            } else {
              setState(() {
                remaining = rem;
              });
            }
          });

          return PopScope(
            canPop: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppAvatar(
                    seed: invite.from.id,
                    name: invite.from.name,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${invite.from.name} wants to play!',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Two-player bluffing dice match • Expires in ${remaining}s',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Decline',
                          style: AppButtonStyle.secondary,
                          onPressed: () async {
                            timer?.cancel();
                            Navigator.of(ctx).pop();
                            await controller.declineInvite();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          label: 'Accept',
                          style: AppButtonStyle.primary,
                          onPressed: () async {
                            timer?.cancel();
                            Navigator.of(ctx).pop();
                            await controller.acceptInvite();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
