import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../state/app_scope.dart';
import '../widgets/app_toast.dart';
import '../widgets/connection_status_banner.dart';
import '../widgets/invite_sheet.dart';
import 'game_screen.dart';
import 'roll_screen.dart';

/// The central shell hosting the main Roll view, incoming invites, and game transitions.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  String? _lastShownInviteId;
  bool _gameScreenOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppScope.of(context);

    // Surface global notices (toast)
    final notice = controller.notice;
    if (notice != null && notice.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showAppToast(context, notice);
          controller.consumeNotice();
        }
      });
    }

    // Surface incoming invite
    final incoming = controller.incomingInvite;
    if (incoming != null && incoming.id != _lastShownInviteId && !_gameScreenOpen) {
      _lastShownInviteId = incoming.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showInviteSheet(context);
        }
      });
    }

    // Auto-navigate to GameScreen when active game exists
    final game = controller.game;
    if (game != null && !_gameScreenOpen) {
      _gameScreenOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const GameScreen()))
              .then((_) {
            _gameScreenOpen = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          ConnectionStatusBanner(),
          Expanded(
            child: RollScreen(),
          ),
        ],
      ),
    );
  }
}
