import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:isometric/features/camera/domain/analysis_pipeline.dart';
import 'package:isometric/features/camera/domain/scene_analysis.dart';

enum CameraSessionStatus { checking, ready, denied, permanentlyDenied, error }

/// Coordinates the camera hardware, permissions, and capture workflow.
class CameraSession extends ChangeNotifier {
  CameraSessionStatus get status => _status;
  String get errorMessage => _errorMessage;
  CameraController? get controller => _controller;
  bool get isLive => _cameraLive;
  bool get isCapturing => _isCapturing;
  bool get isSwitching => _isSwitching;
  FlashMode get flashMode => _flashMode;
  double get minZoom => _minZoom;
  double get maxZoom => _maxZoom;
  double get currentZoom => _currentZoom;
  bool get canFlip => _frontCameraIndex != null && _mainRearCameraIndex != null;
  bool get hasWideAngle => _hasWideAngle;
  bool get isWideActive => _isWideActive;
  bool get isOneXActive => _isOneXActive;
  String get wideLabel => _wideLabel;

  /// Must match CHANNEL in MainActivity.kt.
  static const _settingsChannel = MethodChannel(
    'com.example.isometric/app_settings',
  );

  // ── State ────────────────────────────────────────────────────────────────
  CameraSessionStatus _status = CameraSessionStatus.checking;
  String _errorMessage = '';

  List<CameraDescription> _cameras = [];
  CameraController? _controller; // null whenever there is no live camera
  Future<void>? _releasingCamera;
  int _cameraIndex = 0;

  bool _hasDiscoveredCameras = false;

  int? _mainRearCameraIndex;
  int? _wideRearCameraIndex; // null when the device has no real wide lens
  int? _frontCameraIndex;
  double _wideMinZoom = 1.0; // zoom level of the wide view (e.g. 0.6)

  bool _isFrontCamera = false;

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

  bool get _wideIsSeparateCamera =>
      _wideRearCameraIndex != null &&
      _wideRearCameraIndex != _mainRearCameraIndex;

  bool get _hasWideAngle =>
      !_isFrontCamera &&
      _mainRearCameraIndex != null &&
      _wideRearCameraIndex != null;

  bool get _isWideActive {
    if (!_hasWideAngle) return false;
    return _wideIsSeparateCamera
        ? _cameraIndex == _wideRearCameraIndex
        : _currentZoom < 0.95;
  }

  bool get _isOneXActive => !_isWideActive && (_currentZoom - 1.0).abs() < 0.05;

  String get _wideLabel =>
      _wideIsSeparateCamera ? 'Wide' : '${_wideMinZoom.toStringAsFixed(1)}x';

  // ── Lifecycle ────────────────────────────────────────────────────────────
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    final controller = _controller;
    _controller = null;
    if (controller != null) _disposeCamera(controller);
    super.dispose();
  }

  void handleLifecycle(AppLifecycleState state) {
    if (_disposed) return;
    if (_isStarting) {
      if (state == AppLifecycleState.inactive) _dialogShown = true;
      return;
    }

    if (state == AppLifecycleState.inactive &&
        _status == CameraSessionStatus.ready) {
      _releaseCamera();
    } else if (state == AppLifecycleState.resumed) {
      _onResumed();
    }
  }

  Future<void> _onResumed() async {
    if (_status == CameraSessionStatus.ready) {
      await start();
    } else if (_wentToSettings) {
      // Back from Settings: try again (no loop — only after a Settings trip).
      _wentToSettings = false;
      _denialCount = 0;
      await start();
    }
  }

  // ── Permission ───────────────────────────────────────────────────────────
  Future<void> retryPermission() async {
    if (_status == CameraSessionStatus.permanentlyDenied) {
      await _openAppSettings();
    } else {
      await start();
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
    if (old == null) return;
    _releasingCamera = _disposeCamera(old);
    notifyListeners();
  }

  Future<void> _disposeCamera(CameraController controller) async {
    try {
      await controller.dispose();
    } catch (error) {
      debugPrint('Failed to release camera: $error');
    }
  }

  /// The single entry point: asks for permission (through the camera plugin)
  /// and starts the preview.
  Future<void> start([CameraDescription? camera]) async {
    if (_disposed || _isStarting) return;
    _isStarting = true;
    _dialogShown = false;

    // Detach the old controller first so the UI never uses a disposed one.
    // While the status stays `ready`, the controls remain on screen over a
    // black preview — no full-screen loader on lens switches.
    final old = _controller;
    _change(() {
      _controller = null;
      if (_status != CameraSessionStatus.ready) {
        _status = CameraSessionStatus.checking;
      }
    });
    try {
      await _releasingCamera;
      _releasingCamera = null;
      if (old != null) await _disposeCamera(old);
      if (_disposed) return;
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }

      if (_cameras.isEmpty) {
        _showError('No camera found on this device.');
        return;
      }

      // Discover cameras only once (this is also where the permission dialog
      // first appears, so denial is handled by the catch below).
      if (_disposed) return;
      _discoverCameras();

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
        // set wide angle zoom level in the sliders
        if (!_isFrontCamera &&
            _cameraIndex == _mainRearCameraIndex &&
            _minZoom < 0.95) {
          _wideMinZoom = _minZoom;
          _wideRearCameraIndex = _mainRearCameraIndex;
        }

        // Keep the zoom the user had (e.g. wide) across resume; reset it to
        // 1.0 on lens/camera switches by setting _currentZoom before calling.
        _currentZoom = _currentZoom.clamp(_minZoom, _maxZoom).toDouble();
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

      if (_disposed) {
        await controller.dispose();
        return;
      }
      _denialCount = 0;
      _change(() {
        _controller = controller;
        _status = CameraSessionStatus.ready;
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
    if (_disposed) return;

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

    _change(() {
      _status = permanent
          ? CameraSessionStatus.permanentlyDenied
          : CameraSessionStatus.denied;
    });
  }

  void _showError(String message) {
    if (_disposed) return;
    _change(() {
      _status = CameraSessionStatus.error;
      _errorMessage = message;
    });
  }

  // ── Actions ──────────────────────────────────────────────────────────────
  Future<void> switchCamera() async {
    if (_isCapturing || _isSwitching) return;

    final targetIndex = _isFrontCamera
        ? _mainRearCameraIndex
        : _frontCameraIndex;

    if (targetIndex == null) return;

    _change(() => _isSwitching = true);

    _isFrontCamera = !_isFrontCamera;
    _cameraIndex = targetIndex;
    _currentZoom = 1.0; // always start a new camera at 1x

    await start(_cameras[_cameraIndex]);

    if (!_disposed) _change(() => _isSwitching = false);
  }

  Future<void> toggleFlash() async {
    final controller = _controller;
    if (controller == null || !_cameraLive || _isCapturing) return;

    final next = switch (_flashMode) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };

    try {
      await controller.setFlashMode(next);
      _change(() => _flashMode = next);
    } catch (_) {
      _change(() => _flashMode = FlashMode.off);
    }
  }

  /// Keeps the preview paused until the caller finishes presenting the photo.
  Future<void> capturePhoto(
    Future<void> Function(String imagePath, SceneAnalysis analysis)
    presentPhoto,
  ) async {
    final controller = _controller;
    if (_disposed ||
        _isCapturing ||
        _isSwitching ||
        controller == null ||
        !_cameraLive) {
      return;
    }
    bool previewPaused = false;

    _change(() => _isCapturing = true);
    try {
      final file = await controller.takePicture();
      debugPrint('Captured photo: ${file.path}, running YOLO analysis...');
      if (_disposed) return;
      try {
        await controller.pausePreview();
        previewPaused = true;
      } catch (error) {
        debugPrint('Could not pause camera preview: $error');
      }
      if (_disposed) return;
      SceneAnalysis analysis = SceneAnalysis.none();
      try {
        analysis = await AnalysisPipeline.instance.analyze(file.path);
        debugPrint(
          'YOLO analysis completed: ${analysis.scene.name}, '
          'hasSubject: ${analysis.hasSubject}',
        );
      } catch (e, st) {
        debugPrint('YOLO analysis error: $e\n$st');
      }

      if (!_disposed) await presentPhoto(file.path, analysis);
    } catch (e) {
      debugPrint('Capture error: $e');
    } finally {
      // Resume camera when returning from Photo Editor.
      if (previewPaused &&
          !_disposed &&
          identical(_controller, controller) &&
          controller.value.isInitialized) {
        try {
          await controller.resumePreview();
          debugPrint('Camera preview resumed.');
        } catch (e) {
          debugPrint('Failed to resume camera preview: $e');
        }
      }

      if (!_disposed) {
        _change(() => _isCapturing = false);
      }
    }
  }

  /// Sets the zoom without restarting the camera.
  Future<void> setZoom(double zoom) async {
    final controller = _controller;
    if (controller == null || !_cameraLive) return;

    final target = zoom.clamp(_minZoom, _maxZoom).toDouble();
    try {
      await controller.setZoomLevel(target);
      if (!_disposed) _change(() => _currentZoom = target);
    } catch (e) {
      debugPrint('Zoom failed: $e');
    }
  }

  /// Wide (true) or normal 1x (false).
  /// - Logical camera (one ID that can zoom below 1x): only changes the zoom,
  ///   so there is no restart and no loader.
  /// - Separate wide camera ID: switches camera.
  Future<void> selectWide(bool wide) async {
    if (!_hasWideAngle || _isCapturing || _isSwitching) return;

    // If tapping wide when already wide, or tapping 1x when already at 1x, ignore.
    if (wide && _isWideActive) return;
    if (!wide && _isOneXActive) return;

    if (_wideIsSeparateCamera) {
      final target = wide ? _wideRearCameraIndex! : _mainRearCameraIndex!;
      if (_cameraIndex != target) {
        _change(() => _isSwitching = true);
        _cameraIndex = target;
        _currentZoom = 1.0;
        await start(_cameras[target]);
        if (!_disposed) _change(() => _isSwitching = false);
      } else {
        await setZoom(1.0);
      }
    } else {
      await setZoom(wide ? _wideMinZoom : 1.0);
    }
  }

  void _discoverCameras() {
    if (_hasDiscoveredCameras || _cameras.isEmpty) return;
    int? firstRearIndex;
    int? secondRearIndex;
    int? frontIndex;
    for (int i = 0; i < _cameras.length; i++) {
      final cam = _cameras[i];
      if (cam.lensDirection == CameraLensDirection.back) {
        if (firstRearIndex == null) {
          firstRearIndex = i;
        } else {
          secondRearIndex ??= i;
        }
      } else if (cam.lensDirection == CameraLensDirection.front) {
        frontIndex ??= i;
      }
    }
    _mainRearCameraIndex = firstRearIndex ?? 0;
    _wideRearCameraIndex = secondRearIndex;
    _frontCameraIndex = frontIndex;
    _cameraIndex = _mainRearCameraIndex!;
    _hasDiscoveredCameras = true;
  }

  Future<void> focusAt(Offset point) async {
    final controller = _controller;
    if (controller == null || !_cameraLive || _isCapturing) return;
    try {
      await controller.setFocusPoint(point);
      await controller.setExposurePoint(point);
    } catch (error) {
      debugPrint('Focus failed: $error');
    }
  }

  void _change(VoidCallback update) {
    if (_disposed) return;
    update();
    notifyListeners();
  }
}
