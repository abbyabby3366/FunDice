import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

/// The light Material 3 theme, built from the tokens in docs/SPEC.md §5.
///
/// The platform system font is kept on purpose, so Android looks like Android and iOS like iOS.
class AppTheme {
  AppTheme._();

  static final ThemeData light = _build();

  static const _buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.button)),
  );
  static const _buttonSize = Size(64, AppSpacing.buttonHeight);
  static const _buttonPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.xl,
    vertical: AppSpacing.md,
  );
  static const _fieldRadius = BorderRadius.all(Radius.circular(AppRadius.button));
  static const _softShadow = Color(0x29000000);

  static const _colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryLight,
    onPrimaryContainer: AppColors.primaryDark,
    secondary: AppColors.primary,
    onSecondary: AppColors.onPrimary,
    secondaryContainer: AppColors.primaryLight,
    onSecondaryContainer: AppColors.primaryDark,
    tertiary: AppColors.gold,
    onTertiary: AppColors.textPrimary,
    tertiaryContainer: AppColors.goldLight,
    onTertiaryContainer: AppColors.textPrimary,
    error: AppColors.dangerDark,
    onError: AppColors.onPrimary,
    errorContainer: AppColors.dangerLight,
    onErrorContainer: AppColors.dangerDark,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.background,
    surfaceContainer: AppColors.surfaceMuted,
    surfaceContainerHigh: AppColors.surfaceMuted,
    surfaceContainerHighest: AppColors.border,
    outline: AppColors.textMuted,
    outlineVariant: AppColors.border,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: AppColors.textPrimary,
    onInverseSurface: AppColors.surface,
    inversePrimary: AppColors.primaryLight,
    surfaceTint: Colors.transparent,
  );

  static const _textTheme = TextTheme(
    displayLarge: AppTextStyles.display,
    displayMedium: AppTextStyles.display,
    displaySmall: AppTextStyles.display,
    headlineLarge: AppTextStyles.title,
    headlineMedium: AppTextStyles.title,
    headlineSmall: AppTextStyles.title,
    titleLarge: AppTextStyles.title,
    titleMedium: AppTextStyles.subtitle,
    titleSmall: AppTextStyles.subtitle,
    bodyLarge: AppTextStyles.body,
    bodyMedium: AppTextStyles.body,
    bodySmall: AppTextStyles.caption,
    labelLarge: AppTextStyles.button,
    labelMedium: AppTextStyles.caption,
    labelSmall: AppTextStyles.caption,
  );

  static ThemeData _build() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: _textTheme,
      appBarTheme: _appBarTheme,
      filledButtonTheme: FilledButtonThemeData(style: _filledButtonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _elevatedButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: _outlinedButtonStyle),
      textButtonTheme: TextButtonThemeData(style: _textButtonStyle),
      inputDecorationTheme: _inputDecorationTheme,
      navigationBarTheme: _navigationBarTheme,
      bottomSheetTheme: _bottomSheetTheme,
      dialogTheme: _dialogTheme,
      snackBarTheme: _snackBarTheme,
      switchTheme: _switchTheme,
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: _listTileTheme,
      chipTheme: _chipTheme,
      cardTheme: _cardTheme,
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceMuted,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: Color(0x400E7A5F),
        selectionHandleColor: AppColors.primary,
      ),
    );
  }

  // Flat app bar that blends into the page and only shows a hairline shadow once content scrolls under it.
  static const _appBarTheme = AppBarThemeData(
    backgroundColor: AppColors.background,
    foregroundColor: AppColors.textPrimary,
    surfaceTintColor: Colors.transparent,
    shadowColor: Color(0x33000000),
    elevation: 0,
    scrolledUnderElevation: 1,
    centerTitle: true,
    titleTextStyle: AppTextStyles.subtitle,
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  static final _filledButtonStyle = FilledButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.onPrimary,
    disabledBackgroundColor: AppColors.border,
    disabledForegroundColor: AppColors.textMuted,
    elevation: 0,
    minimumSize: _buttonSize,
    padding: _buttonPadding,
    shape: _buttonShape,
    textStyle: AppTextStyles.button,
  );

  static final _elevatedButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.surface,
    foregroundColor: AppColors.primary,
    disabledBackgroundColor: AppColors.border,
    disabledForegroundColor: AppColors.textMuted,
    surfaceTintColor: Colors.transparent,
    shadowColor: _softShadow,
    elevation: 1,
    minimumSize: _buttonSize,
    padding: _buttonPadding,
    shape: _buttonShape,
    textStyle: AppTextStyles.button,
  );

  static final _outlinedButtonStyle = OutlinedButton.styleFrom(
    backgroundColor: AppColors.surface,
    foregroundColor: AppColors.primary,
    disabledForegroundColor: AppColors.textMuted,
    side: const BorderSide(color: AppColors.border, width: 1.5),
    minimumSize: _buttonSize,
    padding: _buttonPadding,
    shape: _buttonShape,
    textStyle: AppTextStyles.button,
  );

  static final _textButtonStyle = TextButton.styleFrom(
    foregroundColor: AppColors.primary,
    disabledForegroundColor: AppColors.textMuted,
    minimumSize: _buttonSize,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    shape: _buttonShape,
    textStyle: AppTextStyles.button,
  );

  static OutlineInputBorder _fieldBorder(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: _fieldRadius,
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static final _inputDecorationTheme = InputDecorationThemeData(
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.lg,
    ),
    hintStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
    labelStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
    floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
      final Color color;
      if (states.contains(WidgetState.error)) {
        color = AppColors.dangerDark;
      } else if (states.contains(WidgetState.focused)) {
        color = AppColors.primary;
      } else {
        color = AppColors.textSecondary;
      }
      return AppTextStyles.caption.copyWith(color: color);
    }),
    helperStyle: AppTextStyles.caption,
    counterStyle: AppTextStyles.caption,
    errorStyle: AppTextStyles.caption.copyWith(color: AppColors.dangerDark),
    errorMaxLines: 3,
    prefixIconColor: AppColors.textSecondary,
    suffixIconColor: AppColors.textSecondary,
    border: _fieldBorder(AppColors.border, 1),
    enabledBorder: _fieldBorder(AppColors.border, 1),
    disabledBorder: _fieldBorder(AppColors.border, 1),
    focusedBorder: _fieldBorder(AppColors.primary, 2),
    errorBorder: _fieldBorder(AppColors.danger, 1.5),
    focusedErrorBorder: _fieldBorder(AppColors.danger, 2),
  );

  static final _navigationBarTheme = NavigationBarThemeData(
    height: 72,
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    shadowColor: _softShadow,
    elevation: 3,
    indicatorColor: AppColors.primaryLight,
    indicatorShape: const StadiumBorder(),
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return AppTextStyles.caption.copyWith(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? AppColors.primaryDark : AppColors.textSecondary,
      );
    }),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return IconThemeData(
        size: 26,
        color: selected ? AppColors.primaryDark : AppColors.textSecondary,
      );
    }),
  );

  static const _bottomSheetTheme = BottomSheetThemeData(
    backgroundColor: AppColors.surface,
    modalBackgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    clipBehavior: Clip.antiAlias,
    showDragHandle: true,
    dragHandleColor: Color(0x9998A29E),
    dragHandleSize: Size(40, 4),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    ),
  );

  static final _dialogTheme = DialogThemeData(
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 6,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.dialog)),
    ),
    titleTextStyle: AppTextStyles.title,
    contentTextStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
    actionsPadding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      0,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
  );

  static final _snackBarTheme = SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: AppColors.textPrimary,
    actionTextColor: AppColors.gold,
    contentTextStyle: AppTextStyles.body.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: AppColors.surface,
    ),
    elevation: 4,
    insetPadding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      0,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
    shape: _buttonShape,
  );

  static final _switchTheme = SwitchThemeData(
    thumbColor: const WidgetStatePropertyAll(Colors.white),
    trackColor: WidgetStateProperty.resolveWith((states) {
      return states.contains(WidgetState.selected)
          ? AppColors.primary
          : AppColors.textMuted;
    }),
    trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
  );

  static const _listTileTheme = ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    minTileHeight: 56,
    iconColor: AppColors.textSecondary,
    titleTextStyle: AppTextStyles.body,
    subtitleTextStyle: AppTextStyles.caption,
  );

  static final _chipTheme = ChipThemeData(
    backgroundColor: AppColors.surfaceMuted,
    selectedColor: AppColors.primaryLight,
    disabledColor: AppColors.surfaceMuted,
    checkmarkColor: AppColors.primaryDark,
    side: BorderSide.none,
    shape: const StadiumBorder(),
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    labelStyle: AppTextStyles.caption.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    iconTheme: const IconThemeData(size: 18, color: AppColors.textSecondary),
  );

  static const _cardTheme = CardThemeData(
    color: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
      side: BorderSide(color: AppColors.border),
    ),
  );
}
