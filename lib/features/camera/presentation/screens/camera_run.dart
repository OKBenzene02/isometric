import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:isometric/common/theme/theme.dart';
import 'package:isometric/common/widgets/full_screen_loader.dart';
import 'package:isometric/features/camera/presentation/screens/camera_permission_screen.dart';
import 'package:isometric/features/camera/domain/camera_session.dart';
import 'package:isometric/features/camera/presentation/widgets/camera_preview_fill.dart';
import 'package:isometric/features/camera/presentation/screens/photo_editor_screen.dart';
import 'package:isometric/features/camera/presentation/widgets/glass_button.dart';
import 'package:isometric/features/camera/presentation/widgets/no_permission_view.dart';
import 'package:isometric/features/camera/presentation/widgets/processing_overlay.dart';
import 'package:isometric/features/camera/presentation/widgets/shutter_button.dart';
import 'package:isometric/features/camera/presentation/widgets/simple_grid_overlay.dart';

class CameraRun extends StatefulWidget {
  const CameraRun({super.key});

  @override
  State<CameraRun> createState() => _CameraRunState();
}

class _CameraRunState extends State<CameraRun> with WidgetsBindingObserver {
  final _session = CameraSession();
  bool _showGrid = true;
  bool _showZoomSlider = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _session.handleLifecycle(state);

  Future<void> _capturePhoto() =>
      _session.capturePhoto((imagePath, analysis) async {
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) =>
                PhotoEditorScreen(imagePath: imagePath, analysis: analysis),
          ),
        );
      });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _session,
    builder: (_, _) => _buildContent(),
  );

  Widget _buildContent() {
    switch (_session.status) {
      case CameraSessionStatus.checking:
        return const FullScreenLoader();

      case CameraSessionStatus.denied:
      case CameraSessionStatus.permanentlyDenied:
        return CameraPermissionScreen(
          isPermanentlyDenied:
              _session.status == CameraSessionStatus.permanentlyDenied,
          onRetry: _session.retryPermission,
        );

      case CameraSessionStatus.error:
        return NoPermissionView(
          message: _session.errorMessage,
          onRetry: _session.start,
        );

      case CameraSessionStatus.ready:
        return _buildCameraScreen();
    }
  }

  Widget _buildCameraScreen() {
    final controller = _session.controller;

    // The screen (controls included) stays on screen when the camera restarts;
    // only the preview area goes black for a moment. No full-screen loader.
    return Scaffold(
      backgroundColor: AppColors.pureBlack,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            Center(
              child: FractionallySizedBox(
                widthFactor: 1,
                heightFactor: 0.90,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreviewFill(
                      controller: controller,
                      onFocus: _session.focusAt,
                    ),
                    SimpleGridOverlay(isVisible: _showGrid),
                  ],
                ),
              ),
            )
          else
            const ColoredBox(color: AppColors.pureBlack),
          _buildTopBar(),
          Positioned(
            left: 30,
            right: 30,
            bottom: 145,
            child: _buildZoomControls(),
          ),
          _buildBottomBar(),
          // Keep the full-screen capture-processing status visible while
          // the photo is analyzed. The shutter itself stays spinner-free.
          if (_session.isCapturing) const ProcessingOverlay(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final flashOn = _session.flashMode != FlashMode.off;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GlassIconButton(
                icon: _showGrid
                    ? Icons.grid_on_rounded
                    : Icons.grid_off_rounded,
                active: _showGrid,
                onTap: () => setState(() => _showGrid = !_showGrid),
              ),
              GlassIconButton(
                icon: _flashIcon(_session.flashMode),
                active: flashOn,
                onTap: _session.toggleFlash,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final canFlip = _session.canFlip;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 28, left: 32, right: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 48), // keeps the shutter centered
              ShutterButton(
                isProcessing: _session.isCapturing,
                onTap: _capturePhoto,
              ),
              if (canFlip)
                GlassIconButton(
                  icon: Icons.flip_camera_ios_rounded,
                  padding: 12,
                  iconSize: 22,
                  loading: _session.isSwitching,
                  onTap: (_session.isSwitching || _session.isCapturing)
                      ? null
                      : _session.switchCamera,
                )
              else
                const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZoomSlider() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${_session.currentZoom.toStringAsFixed(1)}x',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Slider(
          min: _session.minZoom,
          max: _session.maxZoom,
          value: _session.currentZoom.clamp(_session.minZoom, _session.maxZoom),
          onChanged: _session.isLive ? _session.setZoom : null,
          activeColor: Colors.white,
          inactiveColor: Colors.white38,
        ),
      ],
    );
  }

  Widget _lensPill(String label, bool active, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.black45,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildZoomControls() {
    final busy = _session.isSwitching || _session.isCapturing;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_session.hasWideAngle) ...[
              _lensPill(
                _session.wideLabel,
                _session.isWideActive,
                busy ? null : () => _session.selectWide(true),
              ),
              const SizedBox(width: 8),
              _lensPill(
                '1x',
                _session.isOneXActive,
                busy ? null : () => _session.selectWide(false),
              ),
              const SizedBox(width: 12),
            ],
            IconButton(
              onPressed: () {
                setState(() {
                  _showZoomSlider = !_showZoomSlider;
                });
              },
              icon: Icon(
                _showZoomSlider ? Icons.zoom_out : Icons.zoom_in,
                color: Colors.white,
              ),
              style: IconButton.styleFrom(backgroundColor: Colors.black45),
            ),
          ],
        ),

        if (_showZoomSlider) ...[const SizedBox(height: 8), _buildZoomSlider()],
      ],
    );
  }

  IconData _flashIcon(FlashMode mode) {
    switch (mode) {
      case FlashMode.off:
        return Icons.flash_off_rounded;
      case FlashMode.auto:
        return Icons.flash_auto_rounded;
      case FlashMode.always:
      case FlashMode.torch:
        return Icons.flash_on_rounded;
    }
  }
}
