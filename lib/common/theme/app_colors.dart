import 'package:flutter/material.dart';

/// Defines the black and greys monochrome color palette for the camera app.
/// Designed specifically for dark mode, glassmorphism, and professional camera HUDs.
abstract final class AppColors {
  // Pure OLED Blacks & Deep Backgrounds
  static const Color pureBlack = Color(0xFF000000);
  static const Color dark950 = Color(0xFF070707);
  static const Color dark900 = Color(0xFF0D0D0E);
  static const Color dark850 = Color(0xFF141416);
  static const Color dark800 = Color(0xFF1A1A1D);

  // Surfaces & Elevated Containers
  static const Color surfaceBlack = Color(0xFF000000);
  static const Color surfaceDefault = Color(0xFF121214);
  static const Color surfaceElevated = Color(0xFF1E1E22);
  static const Color surfaceHighlight = Color(0xFF28282D);
  static const Color surfaceSelected = Color(0xFF333339);

  // Mid & Light Greys (Borders, Sliders, Inactive Elements)
  static const Color grey700 = Color(0xFF3E3E44);
  static const Color grey600 = Color(0xFF505058);
  static const Color grey500 = Color(0xFF6B6B75);
  static const Color grey400 = Color(0xFF8B8B94);
  static const Color grey300 = Color(0xFFA9A9B2);
  static const Color grey200 = Color(0xFFC7C7CF);
  static const Color grey100 = Color(0xFFE2E2E6);
  static const Color grey50 = Color(0xFFF1F1F4);

  // Pure White & High Contrast
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF8F8F8);

  // Glassmorphic translucent tokens (frosted glass over dark viewport)
  static const Color glassBackground = Color(0x80141418); // 50% opacity dark grey
  static const Color glassSurface = Color(0x6624242A);    // 40% opacity mid grey
  static const Color glassBorder = Color(0x26FFFFFF);     // 15% crisp white edge
  static const Color glassBorderHighlight = Color(0x4DFFFFFF); // 30% white highlight
  static const Color glassShadow = Color(0x59000000);     // 35% black shadow

  // Scrims & Camera HUD overlays
  static const Color scrimBlack = Color(0xCC000000);
  static const Color hudGlass = Color(0x401E1E22);
  static const Color hudGlassBorder = Color(0x26FFFFFF);
  static const Color controlOverlay = Color(0x59000000);

  // Camera Overlay Guides (Golden Ratio, Rule of Thirds, Focus Reticle)
  static const Color goldenRatioGuide = Color(0x99FFFFFF); // 60% white line
  static const Color goldenRatioAccent = Color(0xE6FFFFFF); // 90% white accent
  static const Color gridLineSubtle = Color(0x40FFFFFF);   // 25% white grid
  static const Color focusReticle = Color(0xF2FFFFFF);     // 95% focus reticle
  static const Color cropBorder = Color(0xCCFFFFFF);       // Golden ratio crop border
  static const Color activeIndicator = Color(0xFFFFFFFF);  // Active shutter / toggle
  static const Color inactiveIndicator = Color(0xFF505058);// Inactive state
}
