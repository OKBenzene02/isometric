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

  /// Load one model.
  Future<YOLO> loadModel(ModelType type) async {
    // Return existing instance if already loaded.
    if (_loadedModels.containsKey(type)) {
      return _loadedModels[type]!;
    }

    final definition = ModelConfig.models[type]!;

    final model = YOLO(modelPath: definition.assetPath);

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
