import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:isometric/common/theme/theme.dart';
import 'package:isometric/common/widgets/glass_container.dart';
import 'package:isometric/features/camera/presentation/photo_editor_screen.dart';
import 'package:isometric/features/camera/presentation/widgets/simple_grid_overlay.dart';

/// Fullscreen Camera View:
/// - Real hardware camera access with live fullscreen preview
/// - Simple Grid ON/OFF toggle
/// - Responsive capture with loading indicator while transitioning to editor
class CameraRun extends StatefulWidget {
  const CameraRun({super.key});

  @override
  State<CameraRun> createState() => _CameraRunState();
}

class _CameraRunState extends State<CameraRun> with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  String? _errorMessage;

  // Viewfinder toggles
  bool _showGrid = true;
  FlashMode _flashMode = FlashMode.off;

  // Capture & Processing State
  bool _isCapturing = false;
  bool _isSwitchingCamera = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCameraController(controller.description);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        await _initCameraController(_cameras[_selectedCameraIndex]);
      } else {
        setState(() {
          _errorMessage = 'No camera found on this device.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Camera permission required or device unavailable.\n($e)';
      });
    }
  }

  Future<void> _initCameraController(CameraDescription description) async {
    final oldController = _cameraController;
    if (mounted) {
      setState(() {
        _isCameraInitialized = false;
      });
    }
    await oldController?.dispose();

    final controller = CameraController(
      description,
      ResolutionPreset.max,
      enableAudio: false,
    );

    try {
      await controller.initialize();

      // Front cameras typically do not support flash. Safely apply flash mode.
      try {
        await controller.setFlashMode(_flashMode);
      } catch (_) {
        _flashMode = FlashMode.off;
      }

      if (mounted) {
        setState(() {
          _cameraController = controller;
          _isCameraInitialized = true;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize camera: $e';
        });
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length <= 1 || _isCapturing || _isSwitchingCamera) return;

    setState(() => _isSwitchingCamera = true);

    try {
      // Find current lens direction (defaults to back)
      final currentDirection = _cameraController?.description.lensDirection ?? CameraLensDirection.back;
      final targetDirection = currentDirection == CameraLensDirection.back
          ? CameraLensDirection.front
          : CameraLensDirection.back;

      // Find camera matching the target direction
      CameraDescription? newCamera;
      for (final cam in _cameras) {
        if (cam.lensDirection == targetDirection) {
          newCamera = cam;
          break;
        }
      }

      // Fallback if no exact match found: pick the next different camera
      newCamera ??= _cameras.firstWhere(
        (c) => c.lensDirection != currentDirection,
        orElse: () => _cameras[(_selectedCameraIndex + 1) % _cameras.length],
      );

      _selectedCameraIndex = _cameras.indexOf(newCamera);
      await _initCameraController(newCamera);
    } catch (e) {
      debugPrint('Error switching camera: $e');
    } finally {
      if (mounted) {
        setState(() => _isSwitchingCamera = false);
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isCapturing || _isSwitchingCamera) return;

    final nextMode = switch (_flashMode) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };

    try {
      await _cameraController!.setFlashMode(nextMode);
      setState(() => _flashMode = nextMode);
    } catch (_) {
      setState(() => _flashMode = FlashMode.off);
    }
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing) return;

    // Show processing loader immediately
    setState(() => _isCapturing = true);

    String? capturedPath;

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final XFile file = await _cameraController!.takePicture();
        capturedPath = file.path;
      } catch (e) {
        debugPrint('Capture error: $e');
      }
    }

    if (!mounted) return;

    // Navigate to DSLR Editor Screen with the captured picture
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoEditorScreen(imagePath: capturedPath),
      ),
    );

    // Hide loader when returning back to camera
    if (mounted) {
      setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pureBlack,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Fullscreen Camera Viewport
          _buildCameraPreview(),

          // 2. Simple Camera Grid (ON/OFF)
          SimpleGridOverlay(isVisible: _showGrid),

          // 3. Clean Top Bar: Grid & Flash Toggles
          Positioned(
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
                    // Grid Toggle Button (ON / OFF)
                    GlassContainer(
                      shape: BoxShape.circle,
                      padding: const EdgeInsets.all(10),
                      backgroundColor: _showGrid ? AppColors.pureWhite : AppColors.glassBackground,
                      borderColor: _showGrid ? AppColors.pureWhite : AppColors.glassBorder,
                      onTap: () => setState(() => _showGrid = !_showGrid),
                      child: Icon(
                        _showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded,
                        size: 20,
                        color: _showGrid ? AppColors.pureBlack : AppColors.pureWhite,
                      ),
                    ),

                    // Flash Toggle Button
                    GlassContainer(
                      shape: BoxShape.circle,
                      padding: const EdgeInsets.all(10),
                      backgroundColor: _flashMode != FlashMode.off ? AppColors.pureWhite : AppColors.glassBackground,
                      borderColor: _flashMode != FlashMode.off ? AppColors.pureWhite : AppColors.glassBorder,
                      onTap: _toggleFlash,
                      child: Icon(
                        _flashIcon(_flashMode),
                        size: 20,
                        color: _flashMode != FlashMode.off ? AppColors.pureBlack : AppColors.pureWhite,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Clean Bottom Bar: Shutter & Camera Flip
          Positioned(
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
                    // Left spacer
                    const SizedBox(width: 48),

                    // Main Capture Shutter Button
                    _ShutterButton(
                      isProcessing: _isCapturing,
                      onTap: _capturePhoto,
                    ),

                    // Camera Switch (Front/Back)
                    if (_cameras.length > 1)
                      GlassContainer(
                        shape: BoxShape.circle,
                        padding: const EdgeInsets.all(12),
                        backgroundColor: AppColors.glassBackground,
                        borderColor: AppColors.glassBorder,
                        onTap: _isSwitchingCamera || _isCapturing ? null : _switchCamera,
                        child: _isSwitchingCamera
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.pureWhite,
                                ),
                              )
                            : const Icon(
                                Icons.flip_camera_ios_rounded,
                                size: 22,
                                color: AppColors.pureWhite,
                              ),
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),

          // 5. Sleek Loading Indicator while processing capture & navigating
          if (_isCapturing)
            Container(
              color: AppColors.pureBlack.withValues(alpha: 0.5),
              child: Center(
                child: GlassContainer(
                  borderRadius: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
                  backgroundColor: AppColors.glassBackground,
                  borderColor: AppColors.glassBorderHighlight,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.8,
                          color: AppColors.pureWhite,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'PROCESSING PHOTO...',
                        style: AppTypography.cameraTelemetry(
                          fontSize: 11,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_rounded, size: 54, color: AppColors.grey500),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppTypography.cameraTelemetry(fontSize: 13, color: AppColors.grey300),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _initCamera,
                child: const Text('RETRY CAMERA ACCESS'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.pureWhite, strokeWidth: 2),
      );
    }

    // Fullscreen Camera Feed filling the screen properly
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        var scale = size.aspectRatio * _cameraController!.value.aspectRatio;
        if (scale < 1) scale = 1 / scale;

        return ClipRect(
          child: Transform.scale(
            scale: scale,
            child: Center(
              child: CameraPreview(_cameraController!),
            ),
          ),
        );
      },
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

class _ShutterButton extends StatefulWidget {
  final bool isProcessing;
  final VoidCallback onTap;

  const _ShutterButton({
    required this.isProcessing,
    required this.onTap,
  });

  @override
  State<_ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<_ShutterButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.90).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (!widget.isProcessing) _controller.forward();
      },
      onTapUp: (_) {
        if (!widget.isProcessing) {
          _controller.reverse();
          widget.onTap();
        }
      },
      onTapCancel: () {
        if (!widget.isProcessing) _controller.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.pureWhite, width: 3.5),
            boxShadow: const [
              BoxShadow(
                color: AppColors.glassShadow,
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(5),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.pureWhite,
            ),
            child: widget.isProcessing
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.pureBlack,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
