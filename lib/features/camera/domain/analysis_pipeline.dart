import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:isometric/common/core/config/model_config.dart';
import 'package:isometric/features/camera/domain/object_labels.dart';
import 'package:isometric/features/camera/domain/scene_analysis.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

enum AnalysisStage { loadingModels, segmenting, estimatingDepth, refining }

const _kSegmentationTimeout = Duration(seconds: 12);

class AnalysisPipeline {
  AnalysisPipeline._();
  static final AnalysisPipeline instance = AnalysisPipeline._();

  final ValueNotifier<AnalysisStage?> stage = ValueNotifier<AnalysisStage?>(
    null,
  );

  /// Never throws: on any failure it returns [SceneAnalysis.none], so the
  /// editor still opens (with grading only, no blur).
  Future<SceneAnalysis> analyze(String imagePath) async {
    final total = Stopwatch()..start();
    final lapWatch = Stopwatch()..start();
    int lap() {
      final v = lapWatch.elapsedMilliseconds;
      lapWatch.reset();
      return v;
    }

    try {
      stage.value = AnalysisStage.loadingModels;
      final segModel = await ModelLoader.instance
          .loadModel(ModelType.segmentation)
          .timeout(_kSegmentationTimeout);
      final loadMs = lap();

      final bytes = await _prepareInput(imagePath);
      final readMs = lap();

      stage.value = AnalysisStage.segmenting;
      final seg = _asResults(
        await segModel.predict(bytes).timeout(_kSegmentationTimeout),
      );
      final segMs = lap();

      stage.value = AnalysisStage.refining;
      debugPrint('Detections found: ${seg.detections.length}');
      for (final d in seg.detections) {
        debugPrint(
          'Detected: ${d.className} (conf: ${d.confidence.toStringAsFixed(2)}, hasMask: ${d.mask != null && d.mask!.isNotEmpty})',
        );
      }

      // A subject mask is sufficient for the compositor's segmentation-only
      // bokeh mode. Skipping the depth pass keeps the capture flow responsive;
      // on slower devices it was the second inference that left the loader on
      // screen after segmentation had already finished.
      final input = _PostInput.from(seg);
      final result = await Isolate.run(() => _postProcess(input));
      final postMs = lap();

      debugPrint(
        'Analysis ${total.elapsedMilliseconds} ms '
        '(load $loadMs, read $readMs, seg $segMs, '
        'post $postMs) -> ${result.scene.name}, '
        'subject=${result.subjectClass}, instances=${seg.detections.length}',
      );
      return result;
    } catch (e, st) {
      debugPrint('Scene analysis failed: $e\n$st');
      return SceneAnalysis.none();
    } finally {
      stage.value = null;
    }
  }

  /// Upright, downscaled copy of the photo for the models. Flutter's decoder
  /// applies the JPEG rotation tag; the plugin's native decoder does not, so
  /// the rotation is baked into the pixels here, once.
  Future<Uint8List> _prepareInput(String path, {int maxWidth = 1280}) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: maxWidth,
      allowUpscaling: false,
    );
    final image = (await codec.getNextFrame()).image;
    codec.dispose();
    try {
      debugPrint('Model input: ${image.width}x${image.height}');
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  /// predict() may hand back a ready object or a raw map depending on the
  /// plugin version; accept both.
  YOLODetectionResults _asResults(Object raw) {
    if (raw is YOLODetectionResults) return raw;
    return YOLODetectionResults.fromMap(Map<dynamic, dynamic>.from(raw as Map));
  }
}

// ── Data sent to the isolate (plain, sendable objects only) ─────────────────
class _Instance {
  _Instance(
    this.name,
    this.confidence,
    this.x,
    this.y,
    this.w,
    this.h,
    this.mask,
  );

  final String name;
  final double confidence;
  final double x, y, w, h; // normalised 0..1
  final List<List<double>>? mask;
}

class _PostInput {
  _PostInput(this.instances);

  final List<_Instance> instances;

  factory _PostInput.from(YOLODetectionResults seg) {
    final instances = <_Instance>[
      for (final d in seg.detections)
        _Instance(
          d.className,
          d.confidence,
          d.normalizedBox.left,
          d.normalizedBox.top,
          d.normalizedBox.width,
          d.normalizedBox.height,
          d.mask,
        ),
    ];
    return _PostInput(instances);
  }
}

// ── Everything below runs in the background isolate ─────────────────────────

const int _kGrid = 640;
const double _kMinConfidence = 0.25;
const double _kMinArea = 0.01;
const int _kDepthRampPixels = 48;

SceneAnalysis _postProcess(_PostInput input) {
  final sw = Stopwatch()..start();

  final subject = _pickSubject(input.instances);
  if (subject == null) return SceneAnalysis.none();

  final mask = _rasterizeMask(subject);
  // Turn the segmentation into a depth cue: the selected subject is the
  // focus plane, and the background gains depth as it gets farther from that
  // subject. This produces a gradual DSLR-like falloff without a second,
  // slow depth-model inference.
  final depth = _depthFromSegmentation(mask);

  return SceneAnalysis(
    hasSubject: true,
    mask: mask,
    maskWidth: _kGrid,
    maskHeight: _kGrid,
    depth: depth,
    depthWidth: _kGrid,
    depthHeight: _kGrid,
    focusDepth: 0.0,
    subjectClass: subject.name,
    scene: _classify(subject),
    postProcessMs: sw.elapsedMilliseconds,
  );
}

/// Picks the most prominent subject: big, near the centre, with good confidence,
/// supporting ANY object class from the object catalog.
_Instance? _pickSubject(List<_Instance> items) {
  _Instance? best;
  var bestScore = 0.0;

  for (final i in items) {
    final mask = i.mask;
    if (i.confidence < _kMinConfidence || mask == null || mask.isEmpty)
      continue;
    if (mask.first.isEmpty) continue;

    final area = i.w * i.h;
    if (area < _kMinArea) continue;

    final dx = i.x + i.w / 2 - 0.5;
    final dy = i.y + i.h / 2 - 0.5;
    final centrality = 1 - math.min(1.0, math.sqrt(dx * dx + dy * dy) / 0.7071);
    final priority = ObjectLabels.subjectPriorityWeight(i.name);

    final score =
        0.45 * math.min(1.0, area * 2.5) +
        0.30 * centrality +
        0.15 * priority +
        0.10 * i.confidence;

    if (score > bestScore) {
      bestScore = score;
      best = i;
    }
  }
  return best;
}

SceneType _classify(_Instance subject) {
  return ObjectLabels.mapToScene(subject.name);
}

/// Turns one instance mask into a 640x640 byte mask covering the whole photo.
///
/// The plugin docs don't say whether an instance mask covers the full frame
/// or only the box, so this decides from the data: a mask that is mostly
/// "on" while its box is small can only be box-cropped. Verify on real photos.
Uint8List _rasterizeMask(_Instance s) {
  final grid = s.mask!;
  final rows = grid.length;
  final cols = grid.first.length;

  // Value range: probabilities (0..1) or raw logits?
  var minV = double.infinity, maxV = -double.infinity;
  var on = 0;
  for (final row in grid) {
    for (final v in row) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
  }
  final isLogit = minV < -0.01 || maxV > 1.01;
  for (final row in grid) {
    for (final v in row) {
      final p = isLogit ? 1 / (1 + math.exp(-v)) : v;
      if (p > 0.5) on++;
    }
  }

  final coverage = on / (rows * cols);
  final boxCropped = coverage > 0.30 && (s.w * s.h) < 0.60;

  // Region of the output canvas the mask maps onto.
  final rx = boxCropped ? s.x * _kGrid : 0.0;
  final ry = boxCropped ? s.y * _kGrid : 0.0;
  final rw = boxCropped ? s.w * _kGrid : _kGrid.toDouble();
  final rh = boxCropped ? s.h * _kGrid : _kGrid.toDouble();

  final out = Uint8List(_kGrid * _kGrid);
  final yStart = math.max(0, ry.floor());
  final yEnd = math.min(_kGrid, (ry + rh).ceil());
  final xStart = math.max(0, rx.floor());
  final xEnd = math.min(_kGrid, (rx + rw).ceil());

  for (var y = yStart; y < yEnd; y++) {
    final fy = ((y + 0.5 - ry) / rh) * rows - 0.5;
    final y0 = fy.floor().clamp(0, rows - 1);
    final y1 = (y0 + 1).clamp(0, rows - 1);
    final ty = (fy - y0).clamp(0.0, 1.0);

    for (var x = xStart; x < xEnd; x++) {
      final fx = ((x + 0.5 - rx) / rw) * cols - 0.5;
      final x0 = fx.floor().clamp(0, cols - 1);
      final x1 = (x0 + 1).clamp(0, cols - 1);
      final tx = (fx - x0).clamp(0.0, 1.0);

      double sample(int yy, int xx) {
        final v = grid[yy][xx];
        return isLogit ? 1 / (1 + math.exp(-v)) : v;
      }

      final top = sample(y0, x0) * (1 - tx) + sample(y0, x1) * tx;
      final bottom = sample(y1, x0) * (1 - tx) + sample(y1, x1) * tx;
      final v = top * (1 - ty) + bottom * ty;
      out[y * _kGrid + x] = (v * 255).clamp(0.0, 255.0).toInt();
    }
  }
  return out;
}

/// Generates a dense, mask-guided depth map. A two-pass chamfer distance
/// transform makes pixels near the subject only slightly blurred and lets
/// distant background ramp smoothly to full bokeh.
Uint8List _depthFromSegmentation(Uint8List mask) {
  const infinity = 1 << 20;
  const straight = 10;
  const diagonal = 14;
  final distances = Int32List(_kGrid * _kGrid);

  for (var i = 0; i < distances.length; i++) {
    distances[i] = mask[i] > 127 ? 0 : infinity;
  }

  for (var y = 0; y < _kGrid; y++) {
    for (var x = 0; x < _kGrid; x++) {
      final i = y * _kGrid + x;
      var best = distances[i];
      if (x > 0) best = math.min(best, distances[i - 1] + straight);
      if (y > 0) {
        best = math.min(best, distances[i - _kGrid] + straight);
        if (x > 0) best = math.min(best, distances[i - _kGrid - 1] + diagonal);
        if (x + 1 < _kGrid) {
          best = math.min(best, distances[i - _kGrid + 1] + diagonal);
        }
      }
      distances[i] = best;
    }
  }

  final maxDistance = _kDepthRampPixels * straight;
  final depth = Uint8List(distances.length);
  for (var y = _kGrid - 1; y >= 0; y--) {
    for (var x = _kGrid - 1; x >= 0; x--) {
      final i = y * _kGrid + x;
      var best = distances[i];
      if (x + 1 < _kGrid) best = math.min(best, distances[i + 1] + straight);
      if (y + 1 < _kGrid) {
        best = math.min(best, distances[i + _kGrid] + straight);
        if (x > 0) best = math.min(best, distances[i + _kGrid - 1] + diagonal);
        if (x + 1 < _kGrid) {
          best = math.min(best, distances[i + _kGrid + 1] + diagonal);
        }
      }
      distances[i] = best;
      depth[i] = (best.clamp(0, maxDistance) * 255 ~/ maxDistance);
    }
  }
  return depth;
}
