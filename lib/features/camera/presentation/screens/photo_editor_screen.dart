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

  const PhotoEditorScreen({
    super.key,
    required this.imagePath,
    this.analysis,
  });

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  late ComposeParams _params;
  bool _showingOriginal = false;
  bool _isRendering = true;
  String? _renderError;

  ui.Image? _originalUiImage;
  ui.Image? _renderedUiImage;
  ui.Image? _maskImage;
  ui.Image? _depthImage;

  @override
  void initState() {
    super.initState();
    final scene = widget.analysis?.scene ?? SceneType.general;
    _params = ComposeParams.forScene(scene);
    _loadAndRender();
  }

  Future<void> _loadAndRender() async {
    if (widget.imagePath == null || !File(widget.imagePath!).existsSync()) {
      if (mounted) setState(() => _isRendering = false);
      return;
    }

    try {
      final bytes = await File(widget.imagePath!).readAsBytes();
      final img = await imageFromBytes(bytes);
      _originalUiImage = img;

      final analysis = widget.analysis;
      if (analysis != null && analysis.hasSubject && analysis.mask.isNotEmpty) {
        _maskImage = await imageFromGray(
          analysis.mask,
          analysis.maskWidth,
          analysis.maskHeight,
        );
      } else {
        // Fallback: 1x1 black mask (all background, no subject cutout)
        _maskImage = await imageFromGray(Uint8List.fromList([0]), 1, 1);
      }

      if (analysis != null && analysis.depth != null && analysis.depth!.isNotEmpty) {
        _depthImage = await imageFromGray(
          analysis.depth!,
          analysis.depthWidth,
          analysis.depthHeight,
        );
      }

      await _applyShader();
    } catch (e, st) {
      debugPrint('Shader render error: $e\n$st');
      if (mounted) {
        setState(() {
          _isRendering = false;
          _renderError = e.toString();
        });
      }
    }
  }

  Future<void> _applyShader() async {
    if (_originalUiImage == null || _maskImage == null) return;
    if (mounted) setState(() => _isRendering = true);

    try {
      final out = await DslrCompositor.render(
        image: _originalUiImage!,
        mask: _maskImage!,
        depth: _depthImage,
        params: _params,
        focusDepth: widget.analysis?.focusDepth ?? 0.5,
        maxSide: 1920,
      );

      if (mounted) {
        setState(() {
          _renderedUiImage?.dispose();
          _renderedUiImage = out;
          _isRendering = false;
        });
      }
    } catch (e, st) {
      debugPrint('Compositor render error: $e\n$st');
      if (mounted) {
        setState(() {
          _isRendering = false;
          _renderError = e.toString();
        });
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
    final scene = widget.analysis?.scene ?? SceneType.general;
    setState(() {
      _params = ComposeParams.forScene(scene);
    });
    _applyShader();
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

                  if (_isRendering)
                    Container(
                      color: Colors.black45,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: AppColors.pureWhite,
                              strokeWidth: 2.5,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'APPLYING DSLR SHADER...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Hold-to-compare button
                  Positioned(
                    top: 14,
                    right: 16,
                    child: GestureDetector(
                      onTapDown: (_) => setState(() => _showingOriginal = true),
                      onTapUp: (_) => setState(() => _showingOriginal = false),
                      onTapCancel: () => setState(() => _showingOriginal = false),
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
            widget.analysis != null && widget.analysis!.hasSubject
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: RawImage(
            image: imgToShow,
            fit: BoxFit.contain,
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
            (v) => _updateParam(_params.copyWith(blurStrength: v)),
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

  void _updateParam(ComposeParams next) {
    setState(() => _params = next);
    _applyShader();
  }

  Widget _sliderRow(
    String label,
    String valueString,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
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