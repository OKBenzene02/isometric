import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Parameters for on-device DSLR color grading and dynamic range enhancement.
class DslrParams {
  final double exposure; // -1.0 to 1.0 (0.0 = neutral)
  final double contrast; // 0.8 to 1.6 (1.0 = neutral)
  final double warmth; // -0.5 to 0.5 (0.0 = neutral)
  final double saturation; // 0.5 to 1.8 (1.0 = neutral)
  final double vignette; // 0.0 to 1.0 (0.0 = none)

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
      exposure: 0.15,
      contrast: 1.12,
      warmth: 0.05,
      saturation: 1.12,
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
    // 1. Exposure + warmth as per-channel gain (keeps the black point)
    final g = math.pow(2, exposure / 2.2).toDouble();
    final gain = _diag(
      g * (1 + warmth * 0.15),
      g,
      g * (1 - warmth * 0.15),
    );

    // 2. Saturation (Rec. 709 luminance)
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final s = saturation;
    final sat = _m5(
      [lr * (1 - s) + s, lg * (1 - s), lb * (1 - s)],
      [lr * (1 - s), lg * (1 - s) + s, lb * (1 - s)],
      [lr * (1 - s), lg * (1 - s), lb * (1 - s) + s],
    );

    // 3. Contrast around mid-grey (Flutter offsets are in 0–255 units)
    final c = contrast;
    final o = 127.5 * (1 - c);
    final con = _diag(c, c, c, offset: o);

    return _mul(con, _mul(sat, gain)).sublist(0, 20);
  }

  /// Diagonal RGB gain matrix (5x5), with an optional offset on R, G and B.
  static List<double> _diag(double r, double g, double b, {double offset = 0}) {
    return _m5(
      [r, 0, 0],
      [0, g, 0],
      [0, 0, b],
      offset: offset,
    );
  }

  /// Builds a 5x5 matrix from three RGB rows; alpha passes through unchanged.
  static List<double> _m5(
    List<double> rRow,
    List<double> gRow,
    List<double> bRow, {
    double offset = 0,
  }) {
    return <double>[
      rRow[0], rRow[1], rRow[2], 0, offset,
      gRow[0], gRow[1], gRow[2], 0, offset,
      bRow[0], bRow[1], bRow[2], 0, offset,
      0, 0, 0, 1, 0,
      0, 0, 0, 0, 1,
    ];
  }

  static List<double> _mul(List<double> a, List<double> b) {
    final out = List<double>.filled(25, 0);
    for (var r = 0; r < 5; r++) {
      for (var c = 0; c < 5; c++) {
        var sum = 0.0;
        for (var k = 0; k < 5; k++) {
          sum += a[r * 5 + k] * b[k * 5 + c];
        }
        out[r * 5 + c] = sum;
      }
    }
    return out;
  }

    /// Edge-darkening gradient shared by the editor preview and the export.
  RadialGradient? vignetteGradient() => vignette <= 0
      ? null
      : RadialGradient(
          radius: 1.0,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: (vignette * 0.75).clamp(0.0, 1.0)),
          ],
          stops: const [0.5, 1.0], // center stays clean
        );
}
