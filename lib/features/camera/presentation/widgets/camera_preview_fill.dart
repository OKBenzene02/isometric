import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraPreviewFill extends StatelessWidget {
  final CameraController controller;

  const CameraPreviewFill({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var scale =
            constraints.biggest.aspectRatio * controller.value.aspectRatio;
        if (scale < 1) scale = 1 / scale;

        return ClipRect(
          child: Transform.scale(
            scale: scale,
            child: Center(child: CameraPreview(controller)),
          ),
        );
      },
    );
  }
}