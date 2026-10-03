import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme/app_colors.dart';
import '../models/api_exception.dart';
import '../state/app_scope.dart';
import '../widgets/app_button.dart';
import '../widgets/server_url_dialog.dart';

/// Onboarding screen where new players pick their display name.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _inlineError;
  String? _wakingHint;
  Timer? _wakingTimer;

  @override
  void dispose() {
    _wakingTimer?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  String? _validateName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.length < 2) return 'Name must be at least 2 characters';
    if (trimmed.length > 16) return 'Name must be 16 characters or less';
    final validChars = RegExp(r'^[\p{L}\p{N}\s_.\-]+$', unicode: true);
    if (!validChars.hasMatch(trimmed)) {
      return 'Only letters, numbers, spaces, and _ . - are allowed';
    }
    return null;
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final err = _validateName(name);
    if (err != null) {
      setState(() => _inlineError = err);
      return;
    }

    setState(() {
      _isLoading = true;
      _inlineError = null;
      _wakingHint = null;
    });

    _wakingTimer?.cancel();
    _wakingTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _isLoading) {
        setState(() {
          _wakingHint = 'Waking up the server — the first time can take up to a minute.';
        });
      }
    });

    try {
      final controller = AppScope.of(context);
      await controller.registerName(name);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _inlineError = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _inlineError = 'Failed to connect. Please verify server address.';
        });
      }
    } finally {
      _wakingTimer?.cancel();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final hasServer = controller.serverUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/images/illustrations/welcome.svg',
                  width: 160,
                  height: 160,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Welcome to FunDice',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A bluffing dice game for two. Roll dice, match with friends, and call Liar!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  maxLength: 16,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'What should we call you?',
                    hintText: 'e.g. Alex, Sam',
                    errorText: _inlineError,
                    filled: true,
                    fillColor: AppColors.surface,
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                  onChanged: (_) {
                    if (_inlineError != null) {
                      setState(() => _inlineError = null);
                    }
                  },
                ),
                if (_wakingHint != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.goldLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 18, color: AppColors.goldDark),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _wakingHint!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.goldDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                AppButton(
                  label: 'Continue',
                  loading: _isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => showServerUrlDialog(context),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      hasServer ? 'Server: ${controller.serverUrl}' : 'Set server address',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
