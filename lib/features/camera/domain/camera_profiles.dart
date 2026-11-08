import 'dart:ui';
import 'package:camera/camera.dart';

class CameraProfile {
  final int index;
  final CameraDescription camera;
  final double minZoom;
  final double maxZoom;
  final Size? previewSize;

  const CameraProfile({
    required this.index,
    required this.camera,
    required this.minZoom,
    required this.maxZoom,
    required this.previewSize,
  });

  int get resolutionPixels {
    if (previewSize == null) return 0;

    return (previewSize!.width * previewSize!.height).round();
  }
}