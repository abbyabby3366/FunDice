import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/app_user.dart';
import '../state/app_scope.dart';
import 'app_button.dart';
import 'app_toast.dart';

/// Card displaying the identified opponent, online status, and custom alias editor.
class SecretOpponentCard extends StatefulWidget {
  const SecretOpponentCard({
    super.key,
    required this.opponent,
    required this.onIdentifyAnother,
    required this.onDone,
  });

  final AppUser opponent;
  final VoidCallback onIdentifyAnother;
  final VoidCallback onDone;

  @override
  State<SecretOpponentCard> createState() => _SecretOpponentCardState();
}

class _SecretOpponentCardState extends State<SecretOpponentCard> {
  String? _currentAlias;
  bool _isEditingAlias = false;
  late final TextEditingController _aliasController;

  @override
  void initState() {
    super.initState();
    _aliasController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppScope.of(context);
    _currentAlias = controller.getAlias(widget.opponent.id);
    _aliasController.text = _currentAlias ?? '';
  }

  @override
  void dispose() {
    _aliasController.dispose();
    super.dispose();
  }

  Future<void> _saveAlias() async {
    final oppId = widget.opponent.id;
    final newAlias = _aliasController.text.trim();
    final controller = AppScope.of(context);
    await controller.saveAlias(oppId, newAlias);
    setState(() {
      _currentAlias = newAlias.isEmpty ? null : newAlias;
      _isEditingAlias = false;
    });
    if (mounted) {
      showAppToast(context, 'Alias saved for this opponent');
    }
  }

  @override
  Widget build(BuildContext context) {
    final registeredName = widget.opponent.name;
    final hasAlias = _currentAlias != null && _currentAlias!.isNotEmpty;
    final displayName = hasAlias ? _currentAlias! : registeredName;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/secret_detect_badge.jpg',
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          registeredName.isNotEmpty
                              ? registeredName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'OPPONENT IDENTIFIED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (hasAlias)
                          Text(
                            'Registered: $registeredName',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Online Now',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: AppColors.border),

              // Alias management
              if (_isEditingAlias) ...[
                TextField(
                  controller: _aliasController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Opponent Nickname / Alias',
                    hintText: 'e.g. Uncle Bob, Seat 3',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Cancel',
                        style: AppButtonStyle.secondary,
                        onPressed: () =>
                            setState(() => _isEditingAlias = false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppButton(
                        label: 'Save Alias',
                        style: AppButtonStyle.primary,
                        onPressed: _saveAlias,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        hasAlias
                            ? 'Saved Alias: "$_currentAlias"'
                            : 'No custom alias set',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton.icon(
                      icon: Icon(
                        hasAlias ? Icons.edit : Icons.bookmark_add,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      label: Text(
                        hasAlias ? 'Change' : 'Set Alias',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                        ),
                      ),
                      onPressed: () =>
                          setState(() => _isEditingAlias = true),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (!_isEditingAlias)
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Identify Another',
                  style: AppButtonStyle.secondary,
                  onPressed: widget.onIdentifyAnother,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'Done',
                  style: AppButtonStyle.primary,
                  onPressed: widget.onDone,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
