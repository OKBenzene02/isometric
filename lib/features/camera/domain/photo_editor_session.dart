import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:isometric/features/camera/domain/dslr_compositor.dart';
import 'package:isometric/features/camera/domain/scene_analysis.dart';

enum PhotoAdjustment {
  blur(0, 1),
  warmth(-0.3, 0.3),
  exposure(-0.5, 0.5),
  vignette(0, 0.6);

  const PhotoAdjustment(this.min, this.max);

  final double min;
  final double max;
}

/// Owns one editor's adjustments, image resources, and preview render queue.
class PhotoEditorSession extends ChangeNotifier {
  PhotoEditorSession({required this.imagePath, this.analysis}) {
    final base = ComposeParams.forScene(analysis?.scene ?? SceneType.general);
    _defaults = hasSubject
        ? base
        : base.copyWith(blurStrength: 0, lightsAmount: 0);
    _params = _defaults;
  }

  final String? imagePath;
  final SceneAnalysis? analysis;
  late final ComposeParams _defaults;
  late ComposeParams _params;
  bool _disposed = false;
  bool _loadStarted = false;
  bool _texturesReady = false;
  bool _renderInFlight = false;
  bool _renderQueued = false;
  String? _error;
  ui.Image? _original;
  ui.Image? _rendered;
  ui.Image? _mask;
  ui.Image? _depth;

  bool get hasSubject => analysis?.hasSubject ?? false;
  String? get error => _error;
  ui.Image? get original => _original;
  ui.Image? get preview => _rendered ?? _original;

  bool canAdjust(PhotoAdjustment adjustment) =>
      adjustment != PhotoAdjustment.blur || hasSubject;

  double valueOf(PhotoAdjustment adjustment) {
    final value = switch (adjustment) {
      PhotoAdjustment.blur => _params.blurStrength,
      PhotoAdjustment.warmth => _params.warmth,
      PhotoAdjustment.exposure => _params.exposure,
      PhotoAdjustment.vignette => _params.vignette,
    };
    return value.clamp(adjustment.min, adjustment.max);
  }

  void setAdjustment(PhotoAdjustment adjustment, double value) {
    if (_disposed || !canAdjust(adjustment)) return;
    final next = value.clamp(adjustment.min, adjustment.max);
    _params = switch (adjustment) {
      PhotoAdjustment.blur => _params.copyWith(blurStrength: next),
      PhotoAdjustment.warmth => _params.copyWith(warmth: next),
      PhotoAdjustment.exposure => _params.copyWith(exposure: next),
      PhotoAdjustment.vignette => _params.copyWith(vignette: next),
    };
    notifyListeners();
    _requestRender();
  }

  void reset() {
    if (_disposed) return;
    _params = _defaults;
    notifyListeners();
    _requestRender();
  }

  Future<void> load() async {
    final path = imagePath;
    if (_disposed || _loadStarted || path == null) return;
    _loadStarted = true;
    try {
      final bytes = await File(path).readAsBytes();
      if (_disposed) return;
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 2048,
        allowUpscaling: false,
      );
      late final ui.Image original;
      try {
        original = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      if (_disposed) {
        original.dispose();
        return;
      }
      _original = original;
      notifyListeners();

      final scene = analysis;
      final mask = scene != null && hasSubject && scene.mask.isNotEmpty
          ? await imageFromGray(scene.mask, scene.maskWidth, scene.maskHeight)
          : await imageFromGray(Uint8List.fromList([255]), 1, 1);
      if (_disposed) {
        mask.dispose();
        return;
      }
      _mask = mask;

      final depth = scene?.depth;
      if (scene != null && hasSubject && depth != null && depth.isNotEmpty) {
        final depthImage = await imageFromGray(
          depth,
          scene.depthWidth,
          scene.depthHeight,
        );
        if (_disposed) {
          depthImage.dispose();
          return;
        }
        _depth = depthImage;
      }
      _texturesReady = true;
      _requestRender();
    } catch (error, stack) {
      _reportError(error, stack);
    }
  }

  void _requestRender() {
    if (_disposed || !_texturesReady) return;
    if (_renderInFlight) {
      _renderQueued = true;
      return;
    }
    _renderPreview();
  }

  Future<void> _renderPreview() async {
    _renderInFlight = true;
    // Retain input handles until the compositor finishes, even if the editor
    // closes while the shader is loading or rendering.
    final image = _original!.clone();
    final mask = _mask!.clone();
    final depth = _depth?.clone();
    try {
      final rendered = await DslrCompositor.render(
        image: image,
        mask: mask,
        depth: depth,
        params: _params.copyWith(focusRange: analysis?.focusRange),
        focusDepth: analysis?.focusDepth ?? 0.5,
        maxSide: 1280,
      );
      if (_disposed) {
        rendered.dispose();
        return;
      }
      _rendered?.dispose();
      _rendered = rendered;
      _error = null;
      notifyListeners();
    } catch (error, stack) {
      _reportError(error, stack);
    } finally {
      image.dispose();
      mask.dispose();
      depth?.dispose();
      _renderInFlight = false;
      if (_renderQueued) {
        _renderQueued = false;
        _requestRender();
      }
    }
  }

  void _reportError(Object error, StackTrace stack) {
    debugPrint('Photo preview failed: $error\n$stack');
    if (_disposed) return;
    _error = error.toString();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _original?.dispose();
    _rendered?.dispose();
    _mask?.dispose();
    _depth?.dispose();
    super.dispose();
  }
}
