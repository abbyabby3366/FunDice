import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Shows a non-intrusive yet clearly visible toast alert adhering to Rule #4.
void showAppToast(
  BuildContext context,
  String message, {
  bool isError = false,
  Duration duration = const Duration(seconds: 3),
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 6,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: isError ? AppColors.danger : AppColors.surface,
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            size: 20,
            color: isError ? Colors.white : AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? Colors.white : AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      duration: duration,
    ),
  );
}
