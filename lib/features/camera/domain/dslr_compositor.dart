import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:isometric/features/camera/domain/scene_analysis.dart'
    show SceneType;

/// Everything the render shader needs, apart from the images.
class ComposeParams {
  // Background blur (depth of field)
  final double blurStrength; // 0 = off .. 1 = strongest
  final double focusRange; // depth distance that reaches full blur (0..1)
  final double highlightThreshold; // luminance where highlights start to bloom
  final double highlightBoost; // extra weight of highlights in the blur

  // Decorative bokeh lights
  final double lightsAmount; // 0 = off
  final double lightsDensity; // 0..1
  final double lightSize; // cell size as a fraction of the image height

  // Mask / local detail
  final double feather; // mask edge smoothing, px at a 1000 px image
  final double sharpen; // subject-only sharpening

  // Color grading
  final double exposure; // EV
  final double warmth; // -0.5..0.5
  final double satSubject;
  final double satBackground;
  final double greenToOlive; // 0..1
  final double contrast; // 1.0 neutral, <1 softer
  final double shoulder; // highlight roll-off start, 1.0 = off
  final double vignette; // 0..1
  final double shadowTintR;
  final double shadowTintG;
  final double shadowTintB;

  const ComposeParams({
    this.blurStrength = 0.0,
    this.focusRange = 0.25,
    this.highlightThreshold = 0.8,
    this.highlightBoost = 3.0,
    this.lightsAmount = 0.0,
    this.lightsDensity = 0.25,
    this.lightSize = 0.09,
    this.feather = 3.0,
    this.sharpen = 0.0,
    this.exposure = 0.0,
    this.warmth = 0.0,
    this.satSubject = 1.0,
    this.satBackground = 1.0,
    this.greenToOlive = 0.0,
    this.contrast = 1.0,
    this.shoulder = 1.0,
    this.vignette = 0.0,
    this.shadowTintR = 0.0,
    this.shadowTintG = 0.0,
    this.shadowTintB = 0.0,
  });

  /// Starting looks per scene. Tune these by eye on real photos.
  factory ComposeParams.forScene(SceneType scene) {
    switch (scene) {
      case SceneType.portrait:
        return const ComposeParams(
          blurStrength: 0.70,
          lightsAmount: 0.35,
          sharpen: 0.30,
          exposure: 0.05,
          warmth: 0.06,
          satSubject: 1.04,
          satBackground: 0.90,
          greenToOlive: 0.5,
          contrast: 0.96,
          shoulder: 0.80,
          vignette: 0.20,
          shadowTintB: 0.02,
          shadowTintR: -0.004,
        );
      case SceneType.landscape:
        return const ComposeParams(
          satSubject: 1.08,
          satBackground: 1.08,
          greenToOlive: 0.35,
          warmth: 0.03,
          contrast: 1.03,
          shoulder: 0.82,
          vignette: 0.15,
          shadowTintB: 0.015,
        );
      case SceneType.food:
        return const ComposeParams(
          blurStrength: 0.50,
          sharpen: 0.35,
          warmth: 0.08,
          satSubject: 1.12,
          satBackground: 0.95,
          contrast: 1.0,
          shoulder: 0.85,
          vignette: 0.25,
        );
      case SceneType.lowLight:
        return const ComposeParams(
          blurStrength: 0.40,
          lightsAmount: 0.50,
          lightsDensity: 0.35,
          exposure: 0.25,
          contrast: 0.95,
          shoulder: 0.75,
          vignette: 0.20,
          shadowTintB: 0.02,
        );
      case SceneType.general:
        return const ComposeParams(
          blurStrength: 0.55,
          lightsAmount: 0.20,
          sharpen: 0.25,
          warmth: 0.04,
          satSubject: 1.04,
          satBackground: 0.95,
          greenToOlive: 0.3,
          contrast: 0.97,
          shoulder: 0.82,
          vignette: 0.20,
          shadowTintB: 0.015,
        );
    }
  }

  ComposeParams copyWith({
    double? blurStrength,
    double? focusRange,
    double? highlightThreshold,
    double? highlightBoost,
    double? lightsAmount,
    double? lightsDensity,
    double? lightSize,
    double? feather,
    double? sharpen,
    double? exposure,
    double? warmth,
    double? satSubject,
    double? satBackground,
    double? greenToOlive,
    double? contrast,
    double? shoulder,
    double? vignette,
    double? shadowTintR,
    double? shadowTintG,
    double? shadowTintB,
  }) {
    return ComposeParams(
      blurStrength: blurStrength ?? this.blurStrength,
      focusRange: focusRange ?? this.focusRange,
      highlightThreshold: highlightThreshold ?? this.highlightThreshold,
      highlightBoost: highlightBoost ?? this.highlightBoost,
      lightsAmount: lightsAmount ?? this.lightsAmount,
      lightsDensity: lightsDensity ?? this.lightsDensity,
      lightSize: lightSize ?? this.lightSize,
      feather: feather ?? this.feather,
      sharpen: sharpen ?? this.sharpen,
      exposure: exposure ?? this.exposure,
      warmth: warmth ?? this.warmth,
      satSubject: satSubject ?? this.satSubject,
      satBackground: satBackground ?? this.satBackground,
      greenToOlive: greenToOlive ?? this.greenToOlive,
      contrast: contrast ?? this.contrast,
      shoulder: shoulder ?? this.shoulder,
      vignette: vignette ?? this.vignette,
      shadowTintR: shadowTintR ?? this.shadowTintR,
      shadowTintG: shadowTintG ?? this.shadowTintG,
      shadowTintB: shadowTintB ?? this.shadowTintB,
    );
  }
}

/// Renders the final photo on the GPU: mask/depth blur, light circles,
/// subject-aware grading and vignette, in one shader pass.
class DslrCompositor {
  static const _asset = 'shaders/dslr_compose.frag';

  static ui.FragmentProgram? _program;
  static ui.Image? _blank;

  /// [image]  the photo. [mask] subject mask (white = subject, R channel).
  /// [depth]  optional depth map (R channel, 0..1). [focusDepth] is the
  /// subject's depth, see [medianDepthUnderMask].
  /// [maxSide] caps the output's longer side (use ~1024 for live preview).
  static Future<ui.Image> render({
    required ui.Image image,
    required ui.Image mask,
    required ComposeParams params,
    ui.Image? depth,
    double focusDepth = 0.5,
    int maxSide = 4096,
  }) async {
    _program ??= await ui.FragmentProgram.fromAsset(_asset);
    final shader = _program!.fragmentShader();

    final scale = math.min(
      1.0,
      maxSide / math.max(image.width, image.height),
    );
    final w = (image.width * scale).round();
    final h = (image.height * scale).round();
    final longSide = math.max(w, h).toDouble();

    // ── Uniforms: keep this order identical to dslr_compose.frag ──────────
    var i = 0;
    void f(double v) => shader.setFloat(i++, v);

    f(w.toDouble()); // uSize.x
    f(h.toDouble()); // uSize.y
    f(params.blurStrength * 0.012 * longSide); // uMaxRadius (px)
    f(depth != null ? 1.0 : 0.0); // uUseDepth
    f(focusDepth); // uFocusDepth
    f(params.focusRange); // uFocusRange
    f(params.highlightThreshold); // uHlThreshold
    f(params.highlightBoost); // uHlBoost
    f(params.lightsAmount); // uLightsAmount
    f(params.lightSize * h); // uLightCell (px)
    f(params.lightsDensity); // uLightDensity
    f(params.feather * longSide / 1000.0); // uFeather (px)
    f(params.sharpen); // uSharpen
    f(params.exposure); // uExposure
    f(params.warmth); // uWarmth
    f(params.satSubject); // uSatSubject
    f(params.satBackground); // uSatBackground
    f(params.greenToOlive); // uGreenToOlive
    f(params.contrast); // uContrast
    f(params.shoulder); // uShoulder
    f(params.vignette); // uVignette
    f(params.shadowTintR); // uShadowTint.r
    f(params.shadowTintG); // uShadowTint.g
    f(params.shadowTintB); // uShadowTint.b

    shader.setImageSampler(0, image);
    shader.setImageSampler(1, mask);
    shader.setImageSampler(2, depth ?? await _blankImage());

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..shader = shader,
    );
    final picture = recorder.endRecording();
    final out = await picture.toImage(w, h);
    picture.dispose();
    shader.dispose();
    return out;
  }

  static Future<ui.Image> _blankImage() async =>
      _blank ??= await imageFromGray(Uint8List.fromList([128]), 1, 1);
}

// ── Helpers ──────────────────────────────────────────────────────────────

/// Builds a ui.Image from one byte per pixel (mask or depth). The value is
/// stored in the R channel, which is what the shader reads.
Future<ui.Image> imageFromGray(Uint8List gray, int width, int height) {
  final rgba = Uint8List(width * height * 4);
  for (var p = 0; p < width * height; p++) {
    final v = gray[p];
    final o = p * 4;
    rgba[o] = v;
    rgba[o + 1] = v;
    rgba[o + 2] = v;
    rgba[o + 3] = 255;
  }
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, width, height, ui.PixelFormat.rgba8888, c.complete);
  return c.future;
}

/// Decodes an image file (e.g. the captured photo) into a ui.Image.
Future<ui.Image> imageFromBytes(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

/// Median depth (0..1) of the pixels inside the subject mask. Both arrays
/// must be the same size (resample one if the model outputs differ).
double medianDepthUnderMask(Uint8List mask, Uint8List depth) {
  final hist = List<int>.filled(256, 0);
  var count = 0;
  final n = math.min(mask.length, depth.length);
  for (var i = 0; i < n; i++) {
    if (mask[i] > 127) {
      hist[depth[i]]++;
      count++;
    }
  }
  if (count == 0) return 0.5;
  var acc = 0;
  for (var v = 0; v < 256; v++) {
    acc += hist[v];
    if (acc >= count / 2) return v / 255.0;
  }
  return 0.5;
}