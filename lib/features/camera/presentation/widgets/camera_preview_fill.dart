import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CameraPreviewFill extends StatelessWidget {
  final CameraController controller;
  final ValueChanged<Offset> onFocus;

  const CameraPreviewFill({
    super.key,
    required this.controller,
    required this.onFocus,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CameraValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (!value.isInitialized) return const SizedBox.shrink();
        final orientation =
            value.previewPauseOrientation ??
            value.lockedCaptureOrientation ??
            value.deviceOrientation;
        final landscape =
            orientation == DeviceOrientation.landscapeLeft ||
            orientation == DeviceOrientation.landscapeRight;
        final aspect = landscape ? value.aspectRatio : 1 / value.aspectRatio;
        const height = 1000.0;
        final width = height * aspect;
        return FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: width,
            height: height,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => onFocus(
                Offset(
                  (details.localPosition.dx / width).clamp(0.0, 1.0),
                  (details.localPosition.dy / height).clamp(0.0, 1.0),
                ),
              ),
              child: CameraPreview(controller),
            ),
          ),
        );
      },
    );
  }
}
