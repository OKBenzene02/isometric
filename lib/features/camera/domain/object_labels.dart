import 'package:isometric/features/camera/domain/scene_analysis.dart';

/// Semantic categories for detected objects to tailor post-processing effects.
enum ObjectCategory {
  person,
  animal,
  food,
  vehicle,
  electronic,
  indoorObject,
  furniture,
  accessory,
  sports,
  outdoor,
  other,
}

/// Comprehensive object label catalog (standard COCO 80 labels + extensible for custom datasets).
class ObjectLabels {
  ObjectLabels._();

  // ── All 80 standard COCO classes supported by YOLO ───────────────────────
  static const List<String> allCocoLabels = [
    // Persons & Living
    'person',
    'bicycle',
    'car',
    'motorcycle',
    'airplane',
    'bus',
    'train',
    'truck',
    'boat',
    'traffic light',
    'fire hydrant',
    'stop sign',
    'parking meter',
    'bench',
    'bird',
    'cat',
    'dog',
    'horse',
    'sheep',
    'cow',
    'elephant',
    'bear',
    'zebra',
    'giraffe',
    'backpack',
    'umbrella',
    'handbag',
    'tie',
    'suitcase',
    'frisbee',
    'skis',
    'snowboard',
    'sports ball',
    'kite',
    'baseball bat',
    'baseball glove',
    'skateboard',
    'surfboard',
    'tennis racket',
    'bottle',
    'wine glass',
    'cup',
    'fork',
    'knife',
    'spoon',
    'bowl',
    'banana',
    'apple',
    'sandwich',
    'orange',
    'broccoli',
    'carrot',
    'hot dog',
    'pizza',
    'donut',
    'cake',
    'chair',
    'couch',
    'potted plant',
    'bed',
    'dining table',
    'toilet',
    'tv',
    'laptop',
    'mouse',
    'remote',
    'keyboard',
    'cell phone',
    'microwave',
    'oven',
    'toaster',
    'sink',
    'refrigerator',
    'book',
    'clock',
    'vase',
    'scissors',
    'teddy bear',
    'hair drier',
    'toothbrush',
  ];

  // ── Category Sets ────────────────────────────────────────────────────────

  static const Set<String> people = {'person'};

  static const Set<String> animals = {
    'bird',
    'cat',
    'dog',
    'horse',
    'sheep',
    'cow',
    'elephant',
    'bear',
    'zebra',
    'giraffe',
  };

  static const Set<String> foods = {
    'banana',
    'apple',
    'sandwich',
    'orange',
    'broccoli',
    'carrot',
    'hot dog',
    'pizza',
    'donut',
    'cake',
    'bottle',
    'wine glass',
    'cup',
    'fork',
    'knife',
    'spoon',
    'bowl',
  };

  static const Set<String> vehicles = {
    'bicycle',
    'car',
    'motorcycle',
    'airplane',
    'bus',
    'train',
    'truck',
    'boat',
  };

  static const Set<String> electronics = {
    'tv',
    'laptop',
    'mouse',
    'remote',
    'keyboard',
    'cell phone',
    'microwave',
    'oven',
    'toaster',
    'hair drier',
    'clock',
  };

  static const Set<String> furniture = {
    'chair',
    'couch',
    'bed',
    'dining table',
    'toilet',
    'sink',
    'refrigerator',
  };

  static const Set<String> accessories = {
    'backpack',
    'umbrella',
    'handbag',
    'tie',
    'suitcase',
  };

  static const Set<String> sports = {
    'frisbee',
    'skis',
    'snowboard',
    'sports ball',
    'kite',
    'baseball bat',
    'baseball glove',
    'skateboard',
    'surfboard',
    'tennis racket',
  };

  static const Set<String> indoorObjects = {
    'book',
    'vase',
    'scissors',
    'teddy bear',
    'toothbrush',
    'potted plant',
  };

  static const Set<String> outdoor = {
    'traffic light',
    'fire hydrant',
    'stop sign',
    'parking meter',
    'bench',
  };

  /// Categorize any label name (case-insensitive).
  static ObjectCategory getCategory(String label) {
    final l = label.trim().toLowerCase();
    if (people.contains(l)) return ObjectCategory.person;
    if (animals.contains(l)) return ObjectCategory.animal;
    if (foods.contains(l)) return ObjectCategory.food;
    if (vehicles.contains(l)) return ObjectCategory.vehicle;
    if (electronics.contains(l)) return ObjectCategory.electronic;
    if (furniture.contains(l)) return ObjectCategory.furniture;
    if (accessories.contains(l)) return ObjectCategory.accessory;
    if (sports.contains(l)) return ObjectCategory.sports;
    if (indoorObjects.contains(l)) return ObjectCategory.indoorObject;
    if (outdoor.contains(l)) return ObjectCategory.outdoor;
    return ObjectCategory.other;
  }

  /// Map an object label to the appropriate DSLR SceneType preset.
  static SceneType mapToScene(String label) {
    final cat = getCategory(label);
    switch (cat) {
      case ObjectCategory.person:
      case ObjectCategory.animal:
        return SceneType.portrait;
      case ObjectCategory.food:
        return SceneType.food;
      case ObjectCategory.vehicle:
      case ObjectCategory.electronic:
      case ObjectCategory.indoorObject:
      case ObjectCategory.accessory:
      case ObjectCategory.sports:
      case ObjectCategory.furniture:
      case ObjectCategory.outdoor:
      case ObjectCategory.other:
        return SceneType.general;
    }
  }

  /// Subject weight bonus when prioritizing the main subject in a scene.
  /// Living subjects and food get a slight natural focal bonus, but any
  /// centered/prominent object is fully eligible.
  static double subjectPriorityWeight(String label) {
    final cat = getCategory(label);
    switch (cat) {
      case ObjectCategory.person:
        return 0.35;
      case ObjectCategory.animal:
        return 0.30;
      case ObjectCategory.food:
        return 0.25;
      case ObjectCategory.electronic:
      case ObjectCategory.indoorObject:
      case ObjectCategory.accessory:
      case ObjectCategory.sports:
        return 0.20;
      case ObjectCategory.vehicle:
        return 0.15;
      case ObjectCategory.furniture:
      case ObjectCategory.outdoor:
      case ObjectCategory.other:
        return 0.10;
    }
  }
}
