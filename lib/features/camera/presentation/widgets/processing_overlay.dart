import 'package:flutter/material.dart';
import 'package:isometric/common/theme/app_colors.dart';
import 'package:isometric/common/theme/app_typography.dart';
import 'package:isometric/common/widgets/glass_container.dart';

class ProcessingOverlay extends StatelessWidget {
  const ProcessingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}