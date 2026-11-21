import 'package:flutter/material.dart';
import 'package:isometric/common/theme/theme.dart';
import 'package:isometric/common/widgets/glass_container.dart';
import 'package:isometric/features/camera/domain/photo_editor_session.dart';
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
  late final PhotoEditorSession _session;
  bool _showingOriginal = false;
  PhotoAdjustment _selectedAdjustment = PhotoAdjustment.blur;

  @override
  void initState() {
    super.initState();
    _session = PhotoEditorSession(
      imagePath: widget.imagePath,
      analysis: widget.analysis,
    )..load();
  }

  @override
  void dispose() {
    _session.dispose();
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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _session,
    builder: (_, _) => _buildEditor(),
  );

  Widget _buildEditor() {
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

                  // Reset manual adjustments
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
                      onTap: _session.reset,
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
                            'RESET',
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
            _session.hasSubject
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
    final imgToShow = _showingOriginal ? _session.original : _session.preview;

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

    if (_session.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Render error: ${_session.error}',
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ),
      );
    }

    return const SizedBox.expand();
  }

  Widget _buildAdjustmentPanel() {
    final selected = _selectedAdjustment;
    final value = _session.valueOf(selected);
    final percent =
        selected == PhotoAdjustment.blur ||
        selected == PhotoAdjustment.vignette;
    final display = '${(value * 100).round()}${percent ? '%' : ''}';

    return Container(
      color: AppColors.dark950,
      padding: const EdgeInsets.only(top: 14, bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Active adjustment: name + value
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selected.name.toUpperCase(),
                  style: AppTypography.cameraTelemetry(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppColors.pureWhite,
                  ),
                ),
                Text(
                  display,
                  style: AppTypography.cameraTelemetry(
                    fontSize: 11,
                    color: AppColors.grey200,
                  ),
                ),
              ],
            ),
          ),

          // One slider for whichever circle is selected
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Slider(
              value: value,
              min: selected.min,
              max: selected.max,
              onChanged: _session.canAdjust(selected)
                  ? (value) => _session.setAdjustment(selected, value)
                  : null,
            ),
          ),

          const SizedBox(height: 4),

          // Circle carousel
          SizedBox(
            height: 84,
            child: Center(
              child: ListView.separated(
                shrinkWrap: true,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: PhotoAdjustment.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 18),
                itemBuilder: (_, i) =>
                    _adjustmentCircle(PhotoAdjustment.values[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _adjustmentCircle(PhotoAdjustment item) {
    final active = item == _selectedAdjustment;
    final enabled = _session.canAdjust(item);
    final icon = switch (item) {
      PhotoAdjustment.blur => Icons.blur_on_rounded,
      PhotoAdjustment.warmth => Icons.thermostat_rounded,
      PhotoAdjustment.exposure => Icons.exposure_rounded,
      PhotoAdjustment.vignette => Icons.vignette_rounded,
    };
    final fg = active ? AppColors.pureBlack : AppColors.pureWhite;

    return Opacity(
      opacity: enabled ? 1.0 : 0.35,
      child: GestureDetector(
        onTap: enabled
            ? () => setState(() => _selectedAdjustment = item)
            : null,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? AppColors.pureWhite : AppColors.glassBackground,
                border: Border.all(
                  color: active ? AppColors.pureWhite : AppColors.glassBorder,
                  width: 1,
                ),
              ),
              child: Icon(icon, size: 22, color: fg),
            ),
            const SizedBox(height: 6),
            Text(
              item.name.toUpperCase(),
              style: AppTypography.cameraTelemetry(
                fontSize: 9,
                color: active ? AppColors.pureWhite : AppColors.grey400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
