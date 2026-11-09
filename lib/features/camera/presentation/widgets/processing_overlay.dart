import 'package:flutter/material.dart';
import 'package:isometric/common/theme/app_colors.dart';
import 'package:isometric/common/theme/app_typography.dart';
import 'package:isometric/features/camera/domain/analysis_pipeline.dart';

class ProcessingOverlay extends StatelessWidget {
  const ProcessingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.pureBlack.withValues(alpha: 0.6),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.dark850,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.glassBorderHighlight),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const RepaintBoundary(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.8,
                      color: AppColors.pureWhite,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ValueListenableBuilder<AnalysisStage?>(
                  valueListenable: AnalysisPipeline.instance.stage,
                  builder: (context, stage, _) {
                    final text = switch (stage) {
                      AnalysisStage.loadingModels => 'LOADING YOLO MODELS...',
                      AnalysisStage.segmenting => 'DETECTING OBJECTS...',
                      AnalysisStage.estimatingDepth => 'ESTIMATING DEPTH...',
                      AnalysisStage.refining => 'REFINING SUBJECT...',
                      null => 'PROCESSING PHOTO...',
                    };
                    return Text(
                      text,
                      style: AppTypography.cameraTelemetry(
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}