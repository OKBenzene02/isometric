import 'package:flutter/material.dart';
import 'package:isometric/common/theme/app_colors.dart';
import 'package:isometric/common/theme/app_typography.dart';
import 'package:isometric/common/theme/camera_theme_extension.dart';

/// Pure Black & Greys Dark Mode Theme Configuration.
/// Strictly enforces a monochrome camera aesthetic with Open Sans typography.
abstract final class AppTheme {
  static ThemeData get darkTheme {
    final textTheme = AppTypography.createTextTheme();

    final colorScheme = const ColorScheme(
      brightness: Brightness.dark,
      // Primary: Pure White highlights
      primary: AppColors.pureWhite,
      onPrimary: AppColors.pureBlack,
      primaryContainer: AppColors.surfaceHighlight,
      onPrimaryContainer: AppColors.pureWhite,

      // Secondary: Mid Greys
      secondary: AppColors.grey200,
      onSecondary: AppColors.pureBlack,
      secondaryContainer: AppColors.surfaceElevated,
      onSecondaryContainer: AppColors.grey100,

      // Tertiary: Subtle dark greys
      tertiary: AppColors.grey400,
      onTertiary: AppColors.pureBlack,
      tertiaryContainer: AppColors.dark800,
      onTertiaryContainer: AppColors.grey200,

      // Error: Subdued grey/white alert in monochrome
      error: AppColors.grey300,
      onError: AppColors.pureBlack,

      // Surface & Background: Pure OLED Black to Charcoal
      surface: AppColors.dark900,
      onSurface: AppColors.pureWhite,
      surfaceDim: AppColors.pureBlack,
      surfaceBright: AppColors.surfaceElevated,
      surfaceContainerLowest: AppColors.pureBlack,
      surfaceContainerLow: AppColors.dark950,
      surfaceContainer: AppColors.dark900,
      surfaceContainerHigh: AppColors.surfaceElevated,
      surfaceContainerHighest: AppColors.surfaceHighlight,
      onSurfaceVariant: AppColors.grey300,

      // Outlines & Borders
      outline: AppColors.grey600,
      outlineVariant: AppColors.grey700,
      shadow: AppColors.pureBlack,
      scrim: AppColors.pureBlack,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.pureBlack,
      canvasColor: AppColors.pureBlack,
      colorScheme: colorScheme,
      textTheme: textTheme,

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.pureBlack,
        foregroundColor: AppColors.pureWhite,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: AppColors.pureWhite,
        size: 24,
      ),

      // Sliders (For color grading, exposure compensation, golden ratio parameters)
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.pureWhite,
        inactiveTrackColor: AppColors.grey700,
        thumbColor: AppColors.pureWhite,
        overlayColor: AppColors.pureWhite.withValues(alpha: 0.15),
        trackHeight: 3.0,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
        valueIndicatorTextStyle: textTheme.labelSmall?.copyWith(
          color: AppColors.pureBlack,
          fontWeight: FontWeight.bold,
        ),
        valueIndicatorColor: AppColors.pureWhite,
      ),

      // Bottom Sheet Theme (For camera tools, presets, grading controls)
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.dark900,
        modalBackgroundColor: AppColors.dark900,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.dark850,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.grey700, width: 0.8),
        ),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: AppColors.grey700,
        thickness: 0.8,
        space: 1,
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: AppColors.surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.grey700, width: 0.6),
        ),
      ),

      // Button Themes
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.pureWhite,
          foregroundColor: AppColors.pureBlack,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.pureWhite,
          side: const BorderSide(color: AppColors.grey500, width: 1),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.pureWhite;
          }
          return AppColors.grey400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.grey600;
          }
          return AppColors.dark800;
        }),
        trackOutlineColor: WidgetStateProperty.all(AppColors.grey600),
      ),

      // Extensions
      extensions: [
        CameraThemeExtension.dark(),
      ],
    );
  }
}
