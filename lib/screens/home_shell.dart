import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../state/app_scope.dart';
import '../widgets/app_toast.dart';
import '../widgets/connection_status_banner.dart';
import '../widgets/invite_sheet.dart';
import 'game_screen.dart';
import 'play_screen.dart';
import 'roll_screen.dart';
import 'settings_screen.dart';

/// The central shell managing the 3-tab navigation, incoming invites, and game transitions.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const ConnectionStatusBanner(),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: const [
                RollScreen(),
                PlayScreen(),
                SettingsScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        elevation: 4,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryLight,
        onDestinationSelected: (idx) {
          setState(() => _currentIndex = idx);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.casino_outlined),
            selectedIcon: Icon(Icons.casino, color: AppColors.primaryDark),
            label: 'Roll',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle, color: AppColors.primaryDark),
            label: 'Play',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: AppColors.primaryDark),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
