import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:isometric/common/theme/theme.dart';
import 'package:isometric/common/widgets/glass_container.dart';
import 'package:isometric/features/camera/domain/dslr_compositor.dart';
import 'package:isometric/features/camera/domain/scene_analysis.dart';

/// Clean DSLR Editor Screen:
/// Runs DslrCompositor shader on GPU with YOLO subject mask & depth.
class PhotoEditorScreen extends StatefulWidget {
  final String? imagePath;
  final SceneAnalysis? analysis;

  const PhotoEditorScreen({super.key, required this.imagePath, this.analysis});

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  late ComposeParams _params;
  bool _showingOriginal = false;
  String? _renderError;

  // One render at a time. If the user keeps dragging a slider meanwhile,
  // exactly one more render runs afterwards with the latest values.
  bool _renderInFlight = false;
  bool _renderQueued = false;

  ui.Image? _originalUiImage; // preview-sized copy of the photo
  ui.Image? _renderedUiImage;
  ui.Image? _maskImage;
  ui.Image? _depthImage;

  bool get _hasSubject => widget.analysis?.hasSubject ?? false;

  @override
  void initState() {
    super.initState();
    _params = _autoParams();
    _loadAndRender();
  }

  /// Scene preset; with no subject there is nothing to blur or light up.
  ComposeParams _autoParams() {
    final base = ComposeParams.forScene(
      widget.analysis?.scene ?? SceneType.general,
    );
    return _hasSubject
        ? base
        : base.copyWith(blurStrength: 0.0, lightsAmount: 0.0);
  }

  Future<void> _loadAndRender() async {
    final path = widget.imagePath;
    if (path == null || !File(path).existsSync()) {
      return;
    }

    try {
      final bytes = await File(path).readAsBytes();

      // Decode a preview-sized copy (max ~2048 px wide) instead of the full
      // 12 MP photo: far cheaper for the shader and for memory.
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 2048,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      _originalUiImage = frame.image;

      final a = widget.analysis;
      if (a != null && a.hasSubject && a.mask.isNotEmpty) {
        _maskImage = await imageFromGray(a.mask, a.maskWidth, a.maskHeight);
      } else {
        // No subject: an all-white mask means "everything is subject", so
        // nothing gets blurred, even if a blur value is set.
        _maskImage = await imageFromGray(Uint8List.fromList([255]), 1, 1);
      }

      final depth = a?.depth;
      if (a != null && a.hasSubject && depth != null && depth.isNotEmpty) {
        _depthImage = await imageFromGray(depth, a.depthWidth, a.depthHeight);
      }

      await _runRender();
    } catch (e, st) {
      debugPrint('Editor load error: $e\n$st');
      if (mounted) {
        setState(() {
          _renderError = e.toString();
        });
      }
    }
  }

  void _requestRender() {
    if (_renderInFlight) {
      _renderQueued = true;
      return;
    }
    _runRender();
  }

  Future<void> _runRender() async {
    final image = _originalUiImage;
    final mask = _maskImage;
    if (image == null || mask == null) return;

    _renderInFlight = true;
    try {
      final out = await DslrCompositor.render(
        image: image,
        mask: mask,
        depth: _depthImage,
        params: _params,
        focusDepth: widget.analysis?.focusDepth ?? 0.5,
        maxSide: 1280,
      );

      if (!mounted) {
        out.dispose();
        return;
      }
      setState(() {
        _renderedUiImage?.dispose();
        _renderedUiImage = out;
      });
    } catch (e, st) {
      debugPrint('Compositor render error: $e\n$st');
      if (mounted) {
        setState(() {
          _renderError = e.toString();
        });
      }
    } finally {
      _renderInFlight = false;
      if (_renderQueued && mounted) {
        _renderQueued = false;
        _runRender();
      }
    }
  }

  @override
  void dispose() {
    _originalUiImage?.dispose();
    _renderedUiImage?.dispose();
    _maskImage?.dispose();
    _depthImage?.dispose();
    super.dispose();
  }

  void _onSave() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.dark850,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.glassBorder, width: 1),
        ),
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.pureWhite,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Photo saved with DSLR shader enhancement!',
                style: AppTypography.cameraTelemetry(fontSize: 12),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.of(context).pop();
  }

  void _resetToAuto() {
    setState(() => _params = _autoParams());
    _requestRender();
  }

  void _updateParam(ComposeParams next) {
    setState(() => _params = next);
    _requestRender();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pureBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),

            Expanded(
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  _buildImageView(),

                  // Hold-to-compare button
                  Positioned(
                    top: 14,
                    right: 16,
                    child: GestureDetector(
                      onTapDown: (_) => setState(() => _showingOriginal = true),
                      onTapUp: (_) => setState(() => _showingOriginal = false),
                      onTapCancel: () =>
                          setState(() => _showingOriginal = false),
                      child: GlassContainer(
                        borderRadius: 20,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        backgroundColor: _showingOriginal
                            ? AppColors.pureWhite
                            : AppColors.glassBackground,
                        borderColor: AppColors.glassBorder,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showingOriginal
                                  ? Icons.visibility_off_rounded
                                  : Icons.compare_rounded,
                              size: 14,
                              color: _showingOriginal
                                  ? AppColors.pureBlack
                                  : AppColors.pureWhite,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _showingOriginal ? 'ORIGINAL' : 'COMPARE',
                              style: AppTypography.cameraTelemetry(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _showingOriginal
                                    ? AppColors.pureBlack
                                    : AppColors.pureWhite,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Reset to Auto button
                  Positioned(
                    top: 14,
                    left: 16,
                    child: GlassContainer(
                      borderRadius: 20,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      backgroundColor: AppColors.glassBackground,
                      borderColor: AppColors.glassBorder,
                      onTap: _resetToAuto,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 12,
                            color: AppColors.pureWhite,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'RESET AUTO',
                            style: AppTypography.cameraTelemetry(
                              fontSize: 10,
                              color: AppColors.pureWhite,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            _buildAdjustmentPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            tooltip: 'Retake',
          ),
          Text(
            _hasSubject
                ? 'DSLR BOKEH: ${widget.analysis!.subjectClass?.toUpperCase() ?? "SUBJECT"}'
                : 'DSLR EDIT',
            style: AppTypography.cameraTelemetry(
              fontSize: 13,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          FilledButton(
            onPressed: _onSave,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.pureWhite,
              foregroundColor: AppColors.pureBlack,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  Widget _buildImageView() {
    final imgToShow = _showingOriginal
        ? _originalUiImage
        : (_renderedUiImage ?? _originalUiImage);

    if (imgToShow != null) {
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: RawImage(image: imgToShow, fit: BoxFit.contain),
          ),
        ),
      );
    }

    if (_renderError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Render error: $_renderError',
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ),
      );
    }

    return const Center(
      child: CircularProgressIndicator(color: AppColors.pureWhite),
    );
  }

  Widget _buildAdjustmentPanel() {
    return Container(
      color: AppColors.dark950,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sliderRow(
            'BLUR / BOKEH',
            '${(_params.blurStrength * 100).round()}%',
            _params.blurStrength,
            0.0,
            1.0,
            // Disabled when no subject was found: nothing to separate.
            _hasSubject
                ? (v) => _updateParam(_params.copyWith(blurStrength: v))
                : null,
          ),
          _sliderRow(
            'WARMTH',
            '${(_params.warmth * 100).round()}',
            _params.warmth,
            -0.3,
            0.3,
            (v) => _updateParam(_params.copyWith(warmth: v)),
          ),
          _sliderRow(
            'EXPOSURE',
            '${(_params.exposure * 100).round()}',
            _params.exposure,
            -0.5,
            0.5,
            (v) => _updateParam(_params.copyWith(exposure: v)),
          ),
          _sliderRow(
            'VIGNETTE',
            '${(_params.vignette * 100).round()}%',
            _params.vignette,
            0.0,
            0.6,
            (v) => _updateParam(_params.copyWith(vignette: v)),
          ),
        ],
      ),
    );
  }

  Widget _sliderRow(
    String label,
    String valueString,
    double value,
    double min,
    double max,
    ValueChanged<double>? onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: AppTypography.cameraTelemetry(
                fontSize: 10,
                color: AppColors.grey400,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 45,
            child: Text(
              valueString,
              textAlign: TextAlign.end,
              style: AppTypography.cameraTelemetry(
                fontSize: 10,
                color: AppColors.grey200,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
