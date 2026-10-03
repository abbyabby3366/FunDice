import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Formatter adhering to GMT+8 and DD-MM-YY standard (User Rule #2).
class AppDateFormatter {
  AppDateFormatter._();

  static const Duration gmt8Offset = Duration(hours: 8);

  /// Converts any [DateTime] to GMT+8 (Malaysia Time / Asia/Kuala_Lumpur).
  static DateTime toGmt8(DateTime dt) {
    final utc = dt.isUtc ? dt : dt.toUtc();
    return utc.add(gmt8Offset);
  }

  /// Formats date strictly as DD-MM-YY (e.g., 03-10-26).
  static String formatDate(DateTime dt) {
    final local = toGmt8(dt);
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = (local.year % 100).toString().padLeft(2, '0');
    return '$day-$month-$year';
  }

  /// Formats time in GMT+8 (e.g., 01:45 PM).
  static String formatTime(DateTime dt) {
    final local = toGmt8(dt);
    final hour12 = local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
    final hourStr = hour12.toString().padLeft(2, '0');
    final minuteStr = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hourStr:$minuteStr $period';
  }

  /// Formats seconds to mm:ss (e.g., 00:45).
  static String formatRemainingSeconds(int seconds) {
    if (seconds <= 0) return '00:00';
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// Standardized two-row stacked Date & Time component adhering to Rule #2:
/// - Stacked in two separate rows (Column)
/// - Primary component on top
/// - Secondary component on bottom (smaller and greyed out)
class StackedDateTimeView extends StatelessWidget {
  const StackedDateTimeView({
    super.key,
    required this.dateTime,
    this.isTimePrimary = true,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final DateTime dateTime;
  final bool isTimePrimary;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final dateStr = AppDateFormatter.formatDate(dateTime);
    final timeStr = AppDateFormatter.formatTime(dateTime);

    final primaryText = isTimePrimary ? timeStr : dateStr;
    final secondaryText = isTimePrimary ? dateStr : timeStr;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          primaryText,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          secondaryText,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
