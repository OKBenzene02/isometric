import 'package:flutter/material.dart';
import 'package:isometric/common/theme/app_colors.dart';

/// Custom theme extension providing camera-specific monochrome tokens.
@immutable
class CameraThemeExtension extends ThemeExtension<CameraThemeExtension> {
  final Color shutterButton;
  final Color shutterRing;
  final Color hudBackground;
  final Color hudForeground;
  final Color gridLine;
  final Color goldenRatioLine;
  final Color goldenRatioSpiral;
  final Color cropGuide;
  final Color focusRing;
  final Color histogramBackground;

  const CameraThemeExtension({
    required this.shutterButton,
    required this.shutterRing,
    required this.hudBackground,
    required this.hudForeground,
    required this.gridLine,
    required this.goldenRatioLine,
    required this.goldenRatioSpiral,
    required this.cropGuide,
    required this.focusRing,
    required this.histogramBackground,
  });

  /// Default camera theme values in dark monochrome (black & greys).
  factory CameraThemeExtension.dark() {
    return const CameraThemeExtension(
      shutterButton: AppColors.pureWhite,
      shutterRing: AppColors.grey600,
      hudBackground: AppColors.scrimBlack,
      hudForeground: AppColors.pureWhite,
      gridLine: AppColors.gridLineSubtle,
      goldenRatioLine: AppColors.goldenRatioGuide,
      goldenRatioSpiral: AppColors.goldenRatioAccent,
      cropGuide: AppColors.cropBorder,
      focusRing: AppColors.focusReticle,
      histogramBackground: AppColors.dark800,
    );
  }

  @override
  CameraThemeExtension copyWith({
    Color? shutterButton,
    Color? shutterRing,
    Color? hudBackground,
    Color? hudForeground,
    Color? gridLine,
    Color? goldenRatioLine,
    Color? goldenRatioSpiral,
    Color? cropGuide,
    Color? focusRing,
    Color? histogramBackground,
  }) {
    return CameraThemeExtension(
      shutterButton: shutterButton ?? this.shutterButton,
      shutterRing: shutterRing ?? this.shutterRing,
      hudBackground: hudBackground ?? this.hudBackground,
      hudForeground: hudForeground ?? this.hudForeground,
      gridLine: gridLine ?? this.gridLine,
      goldenRatioLine: goldenRatioLine ?? this.goldenRatioLine,
      goldenRatioSpiral: goldenRatioSpiral ?? this.goldenRatioSpiral,
      cropGuide: cropGuide ?? this.cropGuide,
      focusRing: focusRing ?? this.focusRing,
      histogramBackground: histogramBackground ?? this.histogramBackground,
    );
  }

  @override
  CameraThemeExtension lerp(ThemeExtension<CameraThemeExtension>? other, double t) {
    if (other is! CameraThemeExtension) return this;
    return CameraThemeExtension(
      shutterButton: Color.lerp(shutterButton, other.shutterButton, t) ?? shutterButton,
      shutterRing: Color.lerp(shutterRing, other.shutterRing, t) ?? shutterRing,
      hudBackground: Color.lerp(hudBackground, other.hudBackground, t) ?? hudBackground,
      hudForeground: Color.lerp(hudForeground, other.hudForeground, t) ?? hudForeground,
      gridLine: Color.lerp(gridLine, other.gridLine, t) ?? gridLine,
      goldenRatioLine: Color.lerp(goldenRatioLine, other.goldenRatioLine, t) ?? goldenRatioLine,
      goldenRatioSpiral: Color.lerp(goldenRatioSpiral, other.goldenRatioSpiral, t) ?? goldenRatioSpiral,
      cropGuide: Color.lerp(cropGuide, other.cropGuide, t) ?? cropGuide,
      focusRing: Color.lerp(focusRing, other.focusRing, t) ?? focusRing,
      histogramBackground: Color.lerp(histogramBackground, other.histogramBackground, t) ?? histogramBackground,
    );
  }
}
