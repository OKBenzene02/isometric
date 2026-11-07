import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:isometric/common/theme/app_colors.dart';

/// App-wide typography system powered by Google Fonts: Open Sans.
/// https://fonts.google.com/specimen/Open+Sans
abstract final class AppTypography {
  /// Base Open Sans text theme mapped to Material 3 type scale.
  static TextTheme createTextTheme() {
    final baseTheme = ThemeData.dark().textTheme;
    final openSansTheme = GoogleFonts.openSansTextTheme(baseTheme);

    return openSansTheme.copyWith(
      // Display: Hero camera indicators, high-impact numbers
      displayLarge: GoogleFonts.openSans(
        fontSize: 57,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        color: AppColors.pureWhite,
      ),
      displayMedium: GoogleFonts.openSans(
        fontSize: 45,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: AppColors.pureWhite,
      ),
      displaySmall: GoogleFonts.openSans(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: AppColors.pureWhite,
      ),

      // Headline: Section headers, preset titles
      headlineLarge: GoogleFonts.openSans(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: AppColors.pureWhite,
      ),
      headlineMedium: GoogleFonts.openSans(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: AppColors.pureWhite,
      ),
      headlineSmall: GoogleFonts.openSans(
        fontSize: 24,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: AppColors.pureWhite,
      ),

      // Title: Card titles, modal headers, filter mode names
      titleLarge: GoogleFonts.openSans(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: AppColors.pureWhite,
      ),
      titleMedium: GoogleFonts.openSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        color: AppColors.pureWhite,
      ),
      titleSmall: GoogleFonts.openSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: AppColors.grey200,
      ),

      // Body: General text, descriptions, setting values
      bodyLarge: GoogleFonts.openSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: AppColors.pureWhite,
      ),
      bodyMedium: GoogleFonts.openSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: AppColors.grey200,
      ),
      bodySmall: GoogleFonts.openSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: AppColors.grey400,
      ),

      // Label: Buttons, badges, camera HUD telemetry (ISO, shutter, EV, Golden Ratio)
      labelLarge: GoogleFonts.openSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: AppColors.pureWhite,
      ),
      labelMedium: GoogleFonts.openSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: AppColors.grey200,
      ),
      labelSmall: GoogleFonts.openSans(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: AppColors.grey300,
      ),
    );
  }

  // Camera HUD specialized typography helpers
  /// Monospaced-feel telemetry readout (e.g. "ISO 100", "1/250s", "f/1.8", "GOLDEN RATIO")
  static TextStyle cameraTelemetry({
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.pureWhite,
    double letterSpacing = 1.0,
  }) {
    return GoogleFonts.openSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  /// Compact badge style for RAW, HDR, 4K, 60fps pill tags
  static TextStyle cameraBadge({
    double fontSize = 10,
    Color color = AppColors.pureWhite,
  }) {
    return GoogleFonts.openSans(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: color,
    );
  }

  /// Camera mode selector labels (PHOTO, VIDEO, GOLDEN, PRO)
  static TextStyle cameraMode({
    required bool isSelected,
  }) {
    return GoogleFonts.openSans(
      fontSize: 13,
      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      letterSpacing: 1.2,
      color: isSelected ? AppColors.pureWhite : AppColors.grey500,
    );
  }
}
