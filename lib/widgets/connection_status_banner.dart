import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../state/app_controller.dart';
import '../state/app_scope.dart';
import 'server_url_dialog.dart';

/// Top banner that visibly indicates server state (waking, offline, reconnecting)
/// strictly adhering to Rules #4 and #5 (no silent errors/fallbacks).
class ConnectionStatusBanner extends StatelessWidget {
  const ConnectionStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final status = controller.serverStatus;

    if (status == ServerStatus.online) {
      return const SizedBox.shrink();
    }

    Color bg;
    Color fg;
    IconData icon;
    String text;
    bool showSpinner = false;

    switch (status) {
      case ServerStatus.waking:
        bg = AppColors.goldLight;
        fg = AppColors.goldDark;
        icon = Icons.bedtime_outlined;
        text = 'Waking up the game server... (first connect can take up to a minute)';
        showSpinner = true;
        break;
      case ServerStatus.connecting:
        bg = AppColors.surfaceMuted;
        fg = AppColors.textSecondary;
        icon = Icons.sync;
        text = 'Connecting to server...';
        showSpinner = true;
        break;
      case ServerStatus.offline:
        bg = AppColors.dangerLight;
        fg = AppColors.danger;
        icon = Icons.cloud_off_outlined;
        text = 'Server unreachable. Playing offline rolls.';
        break;
      case ServerStatus.online:
        return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (showSpinner)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(fg),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(icon, size: 16, color: fg),
              ),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => showServerUrlDialog(context),
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  'Server',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
