/// Parameters for on-device DSLR color grading and dynamic range enhancement.
class DslrParams {
  final double exposure;    // -1.0 to 1.0 (0.0 = neutral)
  final double contrast;    // 0.8 to 1.6 (1.0 = neutral)
  final double warmth;      // -0.5 to 0.5 (0.0 = neutral)
  final double saturation;  // 0.5 to 1.8 (1.0 = neutral)
  final double vignette;    // 0.0 to 1.0 (0.0 = none)

  const DslrParams({
    this.exposure = 0.0,
    this.contrast = 1.0,
    this.warmth = 0.0,
    this.saturation = 1.0,
    this.vignette = 0.0,
  });

  /// Automatically applied DSLR color grading enhancement.
  factory DslrParams.autoDslr() {
    return const DslrParams(
      exposure: 0.10,
      contrast: 1.25,
      warmth: 0.06,
      saturation: 1.20,
      vignette: 0.25,
    );
  }

  /// Original raw unaltered parameters.
  factory DslrParams.original() {
    return const DslrParams(
      exposure: 0.0,
      contrast: 1.0,
      warmth: 0.0,
      saturation: 1.0,
      vignette: 0.0,
    );
  }

  DslrParams copyWith({
    double? exposure,
    double? contrast,
    double? warmth,
    double? saturation,
    double? vignette,
  }) {
    return DslrParams(
      exposure: exposure ?? this.exposure,
      contrast: contrast ?? this.contrast,
      warmth: warmth ?? this.warmth,
      saturation: saturation ?? this.saturation,
      vignette: vignette ?? this.vignette,
    );
  }

  /// Calculates a 4x5 color matrix for hardware-accelerated GPU color grading.
  List<double> toColorMatrix() {
    // Contrast
    final c = contrast;
    final cOffset = 128.0 * (1.0 - c) + (exposure * 60.0);

    // Saturation (standard luminance coefficients)
    final s = saturation;
    const lumR = 0.2126;
    const lumG = 0.7152;
    const lumB = 0.0722;

    final sr = (1 - s) * lumR;
    final sg = (1 - s) * lumG;
    final sb = (1 - s) * lumB;

    // Warmth (subtle red lift, blue trim)
    final wR = 1.0 + (warmth * 0.2);
    final wB = 1.0 - (warmth * 0.2);

    return [
      (sr + s) * c * wR, sg * c,           sb * c,           0, cOffset,
      sr * c,           (sg + s) * c,     sb * c,           0, cOffset,
      sr * c,           sg * c,           (sb + s) * c * wB, 0, cOffset,
      0,                0,                0,                 1, 0,
    ];
  }
}
