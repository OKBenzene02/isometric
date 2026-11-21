import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

enum ModelType { detection, segmentation, semanticSegmentation, depth }

class ModelInformation {
  final String name;
  final String assetPath;
  final String description;
  final YOLOTask task;

  const ModelInformation({
    required this.name,
    required this.assetPath,
    required this.description,
    required this.task,
  });
}

class ModelConfig {
  ModelConfig._();

  static const Map<ModelType, ModelInformation> models = {
    ModelType.detection: ModelInformation(
      name: 'YOLO26 Detection',
      assetPath: 'assets/models/yolo26n.tflite',
      description: 'Object detection.',
      task: YOLOTask.detect,
    ),
    ModelType.segmentation: ModelInformation(
      name: 'YOLO26 Segmentation',
      assetPath: 'assets/models/yolo26n-seg.tflite',
      description: 'Instance segmentation.',
      task: YOLOTask.segment,
    ),
    ModelType.semanticSegmentation: ModelInformation(
      name: 'YOLO26 Semantic Segmentation',
      assetPath: 'assets/models/yolo26n-sem.tflite',
      description: 'Semantic segmentation.',
      task: YOLOTask.semantic,
    ),
    ModelType.depth: ModelInformation(
      name: 'YOLO26 Depth',
      assetPath: 'assets/models/yolo26n-depth.tflite',
      description: 'Depth estimation.',
      task: YOLOTask.depth,
    ),
  };
}

class ModelLoader {
  ModelLoader._internal();
  static final ModelLoader instance = ModelLoader._internal();
  final Map<ModelType, YOLO> _loadedModels = {};
  final Map<ModelType, Future<YOLO>> _loadingModels = {};

  /// Load one model.
  Future<YOLO> loadModel(ModelType type) async {
    // Return existing instance if already loaded.
    if (_loadedModels.containsKey(type)) {
      return _loadedModels[type]!;
    }

    // A capture can begin while the launch warm-up is still running. Reuse
    // that load rather than creating a second native model instance.
    final inFlight = _loadingModels[type];
    if (inFlight != null) return inFlight;

    final loading = _loadNewModel(type);
    _loadingModels[type] = loading;
    try {
      return await loading;
    } finally {
      _loadingModels.remove(type);
    }
  }

  Future<YOLO> _loadNewModel(ModelType type) async {
    final definition = ModelConfig.models[type]!;

    // Each model needs its own native inference instance.  The plugin's
    // default instance is shared, so using it for segmentation and depth
    // causes the last loaded model to replace the one used by the other call.
    // That left the segmentation request running the depth model and returning
    // no masks, which in turn disabled background blur.
    final model = YOLO(
      modelPath: definition.assetPath,
      task: definition.task,
      useMultiInstance: true,
    );

    try {
      await model.loadModel();
      _loadedModels[type] = model;
      return model;
    } catch (error) {
      throw Exception('Failed to load ${definition.name}: $error');
    }
  }

  /// Load all four models sequentially.
  Future<void> loadAllModels() async {
    for (final type in ModelType.values) {
      await loadModel(type);
    }
  }

  /// Warm segmentation on launch. Depth loads when capture finds a subject.
  Future<void> preloadBokehModels() async {
    if (Platform.isAndroid) {
      await _photoChannel.invokeMethod<void>(
        'warm',
        _photoArguments(ModelType.segmentation),
      );
      return;
    }
    await loadModel(ModelType.segmentation);
  }

  Future<YOLODetectionResults> predictPhoto(
    ModelType type,
    Uint8List bytes,
  ) async {
    if (Platform.isAndroid) {
      final token = RootIsolateToken.instance!;
      final arguments = _photoArguments(type)..['image'] = bytes;
      return _predictOffUiThread(token, arguments);
    }
    final model = await loadModel(type);
    return YOLODetectionResults.fromMap(await model.predict(bytes));
  }

  /// Get an already loaded model.
  YOLO? getModel(ModelType type) {
    return _loadedModels[type];
  }

  /// Check whether a model has been loaded.
  bool isLoaded(ModelType type) {
    return _loadedModels.containsKey(type);
  }

  /// Number of currently loaded models.
  int get loadedCount => _loadedModels.length;
}

const _photoChannel = MethodChannel('com.example.isometric/photo_inference');

Map<String, Object> _photoArguments(ModelType type) {
  final model = ModelConfig.models[type]!;
  return {'task': model.task.name, 'asset': model.assetPath};
}

Future<YOLODetectionResults> _predictOffUiThread(
  RootIsolateToken token,
  Map<String, Object> arguments,
) => Isolate.run(() async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  final result = await _photoChannel.invokeMapMethod<Object?, Object?>(
    'predict',
    arguments,
  );
  // Decoding dense masks into Dart objects can also stall the UI isolate.
  return YOLODetectionResults.fromMap(result!);
});
