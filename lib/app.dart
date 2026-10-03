import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'state/app_controller.dart';
import 'state/app_scope.dart';

/// Root Application Widget configuring theme and top-level phase routing.
class FunDiceApp extends StatelessWidget {
  const FunDiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FunDice',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AppGate(),
    );
  }
}

/// AppGate dynamically selects the screen according to the player's phase.
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);

    switch (controller.phase) {
      case AppPhase.booting:
        return const SplashScreen();
      case AppPhase.needsName:
        return const OnboardingScreen();
      case AppPhase.ready:
        return const HomeShell();
    }
  }
}
