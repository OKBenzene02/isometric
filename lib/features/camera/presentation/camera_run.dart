import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isometric/common/theme/theme.dart';
import 'package:isometric/common/widgets/full_screen_loader.dart';
import 'package:isometric/features/camera/presentation/camera_permission_screen.dart';
import 'package:isometric/features/camera/presentation/photo_editor_screen.dart';
import 'package:isometric/features/camera/presentation/widgets/camera_preview_fill.dart';
import 'package:isometric/features/camera/presentation/widgets/glass_button.dart';
import 'package:isometric/features/camera/presentation/widgets/no_permission_view.dart';
import 'package:isometric/features/camera/presentation/widgets/processing_overlay.dart';
import 'package:isometric/features/camera/presentation/widgets/shutter_button.dart';
import 'package:isometric/features/camera/presentation/widgets/simple_grid_overlay.dart';

/// What the screen is currently showing.
enum _Status { checking, ready, denied, permanentlyDenied, error }

class CameraRun extends StatefulWidget {
  const CameraRun({super.key});

  @override
  State<CameraRun> createState() => _CameraRunState();
}

class _CameraRunState extends State<CameraRun> with WidgetsBindingObserver {
  /// Must match CHANNEL in MainActivity.kt.
  static const _settingsChannel = MethodChannel(
    'com.example.isometric/app_settings',
  );

  // ── State ────────────────────────────────────────────────────────────────
  _Status _status = _Status.checking;
  String _errorMessage = '';

  List<CameraDescription> _cameras = [];
  CameraController? _controller; // null whenever there is no live camera
  int _cameraIndex = 0;

  bool _showGrid = true;
  FlashMode _flashMode = FlashMode.off;

  bool _isCapturing = false;
  bool _isSwitching = false;

  // Permission bookkeeping (the camera plugin asks for permission itself).
  bool _isStarting = false; // a start is in progress (dialog may be showing)
  bool _dialogShown = false; // app went inactive during start → dialog appeared
  int _denialCount = 0; // denials with a dialog; Android blocks after two
  bool _wentToSettings = false; // retry when the user comes back

  bool get _cameraLive => _controller?.value.isInitialized ?? false;

  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;

  // ── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // While starting, the permission dialog fires inactive/resumed.
    // Remember that a dialog appeared, but don't react to it.
    if (_isStarting) {
      if (state == AppLifecycleState.inactive) _dialogShown = true;
      return;
    }

    if (state == AppLifecycleState.inactive && _status == _Status.ready) {
      _releaseCamera();
    } else if (state == AppLifecycleState.resumed) {
      _onResumed();
    }
  }

  Future<void> _onResumed() async {
    if (_status == _Status.ready) {
      await _startCamera();
    } else if (_wentToSettings) {
      // Back from Settings: try again (no loop — only after a Settings trip).
      _wentToSettings = false;
      _denialCount = 0;
      await _startCamera();
    }
  }

  // ── Permission ───────────────────────────────────────────────────────────
  Future<void> _onPermissionRetry() async {
    if (_status == _Status.permanentlyDenied) {
      await _openAppSettings();
    } else {
      await _startCamera();
    }
  }

  Future<void> _openAppSettings() async {
    try {
      _wentToSettings = true;
      await _settingsChannel.invokeMethod('openAppSettings');
    } on PlatformException catch (_) {
      _wentToSettings = false;
      _showError('Open Settings → Apps → Isometric → Permissions → Camera.');
    } on MissingPluginException catch (_) {
      // No native handler on this platform (e.g. iOS).
      _wentToSettings = false;
      _showError('Open Settings → Isometric and allow Camera access.');
    }
  }

  // ── Camera start / stop ──────────────────────────────────────────────────
  void _releaseCamera() {
    final old = _controller;
    _controller = null;
    old?.dispose();
    if (mounted) setState(() {});
  }

  /// The single entry point: asks for permission (through the camera plugin)
  /// and starts the preview.
  Future<void> _startCamera([CameraDescription? camera]) async {
    if (_isStarting) return;
    _isStarting = true;
    _dialogShown = false;

    // Detach the old controller first so the UI never uses a disposed one.
    final old = _controller;
    if (mounted) {
      setState(() {
        _controller = null;
        // Spinner (not the permission screen) while the dialog is up.
        if (_status != _Status.ready) _status = _Status.checking;
      });
    }
    await old?.dispose();

    try {
      if (_cameras.isEmpty) _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _showError('No camera found on this device.');
        return;
      }

      final controller = CameraController(
        camera ?? _cameras[_cameraIndex],
        ResolutionPreset.max,
        enableAudio: false,
      );

      try {
        await controller.initialize(); // shows the permission dialog if needed
      } catch (_) {
        await controller.dispose();
        rethrow;
      }

      try {
        _minZoom = await controller.getMinZoomLevel();
        _maxZoom = await controller.getMaxZoomLevel();

        _currentZoom = 1.0.clamp(_minZoom, _maxZoom).toDouble();

        await controller.setZoomLevel(_currentZoom);
      } catch (e) {
        debugPrint('Zoom initialization failed: $e');
        _minZoom = 1.0;
        _maxZoom = 1.0;
        _currentZoom = 1.0;
      }

      try {
        await controller.setFlashMode(_flashMode);
      } catch (_) {
        _flashMode = FlashMode.off; // e.g. front camera has no flash
      }

      if (!mounted) {
        await controller.dispose();
        return;
      }
      _denialCount = 0;
      setState(() {
        _controller = controller;
        _status = _Status.ready;
      });
    } on CameraException catch (e) {
      _onCameraException(e);
    } catch (e) {
      _showError('Failed to start the camera: $e');
    } finally {
      _isStarting = false;
    }
  }

  void _onCameraException(CameraException e) {
    debugPrint('CameraException: ${e.code} — ${e.description}');
    if (!mounted) return;

    final denied =
        e.code.contains('AccessDenied') || e.code.contains('AccessRestricted');
    if (!denied) {
      _showError('Camera error: ${e.description}');
      return;
    }

    _denialCount++;
    // Permanent if the plugin says so, if no dialog appeared this time
    // (Android no longer asks), or after two denials.
    final permanent =
        e.code.contains('WithoutPrompt') ||
        e.code.contains('Restricted') ||
        !_dialogShown ||
        _denialCount >= 2;

    setState(() {
      _status = permanent ? _Status.permanentlyDenied : _Status.denied;
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _status = _Status.error;
      _errorMessage = message;
    });
  }

  // ── Actions ──────────────────────────────────────────────────────────────
  Future<void> _switchCamera() async {
    if (_cameras.length <= 1 || _isCapturing || _isSwitching) return;
    setState(() => _isSwitching = true);

    final current = _cameras[_cameraIndex].lensDirection;
    final target = current == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    final index = _cameras.indexWhere((c) => c.lensDirection == target);
    _cameraIndex = index >= 0 ? index : (_cameraIndex + 1) % _cameras.length;

    await _startCamera(_cameras[_cameraIndex]);
    if (mounted) setState(() => _isSwitching = false);
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !_cameraLive || _isCapturing) return;

    final next = switch (_flashMode) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };

    try {
      await controller.setFlashMode(next);
      setState(() => _flashMode = next);
    } catch (_) {
      setState(() => _flashMode = FlashMode.off);
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (_isCapturing || controller == null || !_cameraLive) return;

    setState(() => _isCapturing = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PhotoEditorScreen(imagePath: file.path),
        ),
      );
    } catch (e) {
      debugPrint('Capture error: $e');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case _Status.checking:
        return const FullScreenLoader();

      case _Status.denied:
      case _Status.permanentlyDenied:
        return CameraPermissionScreen(
          isPermanentlyDenied: _status == _Status.permanentlyDenied,
          onRetry: _onPermissionRetry,
        );

      case _Status.error:
        return NoPermissionView(message: _errorMessage, onRetry: _startCamera);

      case _Status.ready:
        return _buildCameraScreen();
    }
  }

  Widget _buildCameraScreen() {
    final controller = _controller;

    // Camera is still starting (or restarting after a flip / resume).
    if (controller == null || !_cameraLive) {
      return const FullScreenLoader();
    }

    return Scaffold(
      backgroundColor: AppColors.pureBlack,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => _focusOnTap(details, context),
            child: CameraPreviewFill(controller: controller),
          ),
          SimpleGridOverlay(isVisible: _showGrid),
          _buildTopBar(),
          Positioned(
            left: 30,
            right: 30,
            bottom: 150,
            child: _buildZoomSlider(),
          ),
          _buildBottomBar(),
          if (_isCapturing) const ProcessingOverlay(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final flashOn = _flashMode != FlashMode.off;

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
                icon: _flashIcon(_flashMode),
                active: flashOn,
                onTap: _toggleFlash,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
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
              ShutterButton(isProcessing: _isCapturing, onTap: _capturePhoto),
              if (_cameras.length > 1)
                GlassIconButton(
                  icon: Icons.flip_camera_ios_rounded,
                  padding: 12,
                  iconSize: 22,
                  loading: _isSwitching,
                  onTap: (_isSwitching || _isCapturing) ? null : _switchCamera,
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
          '${_currentZoom.toStringAsFixed(1)}x',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Slider(
          min: _minZoom,
          max: _maxZoom,
          value: _currentZoom.clamp(_minZoom, _maxZoom),
          onChanged: (value) async {
            setState(() {
              _currentZoom = value;
            });

            await _controller?.setZoomLevel(value);
          },
          activeColor: Colors.white,
          inactiveColor: Colors.white38,
        ),
      ],
    );
  }

  // ── Tap to focus ─────────────────────────────────────
  Future<void> _focusOnTap(TapDownDetails details, BuildContext context) async {
    final controller = _controller;

    if (controller == null || !_cameraLive || _isCapturing) return;

    // Get the preview dimensions.
    final renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final size = renderBox.size;

    // Convert tap position to normalized coordinates (0.0 - 1.0).
    final focusPoint = Offset(
      (localPosition.dx / size.width).clamp(0.0, 1.0),
      (localPosition.dy / size.height).clamp(0.0, 1.0),
    );

    try {
      await controller.setFocusPoint(focusPoint);
      await controller.setExposurePoint(focusPoint);
    } catch (e) {
      debugPrint('Focus failed: $e');
    }
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
