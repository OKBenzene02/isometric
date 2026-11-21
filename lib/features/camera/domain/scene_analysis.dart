import 'dart:typed_data';

enum SceneType { portrait, landscape, food, lowLight, general }

/// Result of analysing one photo. Only plain data (typed lists, numbers, an
/// enum), so it can be returned from a background isolate without copying.
class SceneAnalysis {
  const SceneAnalysis({
    required this.hasSubject,
    required this.mask,
    required this.maskWidth,
    required this.maskHeight,
    required this.scene,
    this.depth,
    this.depthWidth = 0,
    this.depthHeight = 0,
    this.focusDepth = 0.5,
    this.focusRange,
    this.subjectClass,
    this.postProcessMs = 0,
  });

  /// No subject found, or the analysis failed. The compositor must NOT blur
  /// in this case: an empty mask would be treated as "all background".
  factory SceneAnalysis.none() => SceneAnalysis(
    hasSubject: false,
    mask: Uint8List(1),
    maskWidth: 1,
    maskHeight: 1,
    scene: SceneType.landscape,
  );

  final bool hasSubject;

  /// One byte per pixel, 255 = subject. Covers the whole photo in
  /// normalised coordinates (the shader samples it by UV).
  final Uint8List mask;
  final int maskWidth;
  final int maskHeight;

  /// One byte per pixel in the blur shader's depth coordinate system.
  final Uint8List? depth;
  final int depthWidth;
  final int depthHeight;

  /// Focus plane in the same 0..1 scale as [depth].
  final double focusDepth;

  /// Depth difference that reaches full blur, or null for the shader default.
  final double? focusRange;

  final String? subjectClass;
  final SceneType scene;
  final int postProcessMs;
}
