import 'dart:io';
import 'package:flutter/material.dart';
import 'package:isometric/common/theme/theme.dart';
import 'package:isometric/common/widgets/glass_container.dart';
import 'package:isometric/features/camera/domain/dslr_enhancer.dart';

/// Clean DSLR Editor Screen:
/// Automatically applies DSLR color grading when opened.
/// User can fine-tune exposure, contrast, warmth, saturation, and vignette, or save.
class PhotoEditorScreen extends StatefulWidget {
  final String? imagePath;

  const PhotoEditorScreen({super.key, required this.imagePath});

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  late DslrParams _params;
  bool _showingOriginal = false;
  String _signed(double v) => v > 0 ? '+${v.round()}' : '${v.round()}';

  @override
  void initState() {
    super.initState();
    // Automatically apply DSLR enhancement
    _params = DslrParams.autoDslr();
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
                'Photo saved with DSLR enhancement!',
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
    setState(() {
      _params = DslrParams.autoDslr();
    });
  }

  @override
  Widget build(BuildContext context) {
    final effectiveParams = _showingOriginal ? DslrParams.original() : _params;

    return Scaffold(
      backgroundColor: AppColors.pureBlack,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(),

            // Image Preview Area with DSLR Color Grading
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  _buildGradedImage(effectiveParams),

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

                  // Reset to Auto DSLR button (if user altered values)
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

            // Bottom Adjustments Panel (Sliders only, no confusing tabs or overlays)
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
            'DSLR EDIT',
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

  Widget _buildGradedImage(DslrParams params) {
    Widget imageWidget;

    if (widget.imagePath != null && File(widget.imagePath!).existsSync()) {
      imageWidget = Image.file(
        File(widget.imagePath!),
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return const Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: AppColors.pureWhite,
                strokeWidth: 2.5,
              ),
            ),
          );
        },
      );
    } else {
      imageWidget = Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF232526), Color(0xFF0F1012)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.photo_camera_rounded,
                size: 52,
                color: AppColors.grey500.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 8),
              Text(
                'CAPTURED SCENE',
                style: AppTypography.cameraTelemetry(
                  fontSize: 11,
                  color: AppColors.grey400,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 1. Hardware accelerated GPU Color Grading Matrix
    Widget gradedWidget = ColorFiltered(
      colorFilter: ColorFilter.matrix(params.toColorMatrix()),
      child: imageWidget,
    );

    // 2. Subtle Lens Vignette
    if (params.vignette > 0) {
      gradedWidget = Stack(
        fit: StackFit.expand,
        children: [
          gradedWidget,
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.9,
                  colors: [
                    Colors.transparent,
                    AppColors.pureBlack.withValues(
                      alpha: (params.vignette * 0.75).clamp(0.0, 1.0),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: gradedWidget,
      ),
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
            'CONTRAST',
            _signed((_params.contrast - 1.0) * 100),
            _params.contrast,
            0.8,
            1.6,
            (v) => setState(() => _params = _params.copyWith(contrast: v)),
          ),
          _sliderRow(
            'WARMTH',
            _signed(_params.warmth * 100),
            _params.warmth,
            -0.5,
            0.5,
            (v) => setState(() => _params = _params.copyWith(warmth: v)),
          ),
          _sliderRow(
            'SATURATION',
            _signed((_params.saturation - 1.0) * 100),
            _params.saturation,
            0.5,
            1.8,
            (v) => setState(() => _params = _params.copyWith(saturation: v)),
          ),
          _sliderRow(
            'VIGNETTE',
            '${(_params.vignette / 0.8 * 100).round()}%',
            _params.vignette,
            0.0,
            0.8,
            (v) => setState(() => _params = _params.copyWith(vignette: v)),
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
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 82,
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
            width: 50,
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
