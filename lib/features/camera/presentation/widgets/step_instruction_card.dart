import 'dart:io';

import 'package:flutter/material.dart';
import 'package:isometric/common/theme/app_colors.dart';
import 'package:isometric/common/theme/app_typography.dart';
import 'package:isometric/common/widgets/glass_container.dart';

class StepInstructionCard extends StatelessWidget {
  const StepInstructionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final steps = Platform.isAndroid
        ? ['Open Settings', 'Tap Apps → Isometric', 'Permissions → Camera → Allow']
        : ['Open Settings', 'Scroll to Isometric', 'Camera → Allow'];

    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      backgroundColor: AppColors.glassSurface,
      borderColor: AppColors.glassBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: steps.asMap().entries.map((entry) {
          final i = entry.key;
          final step = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: i < steps.length - 1 ? 10 : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceHighlight,
                    border: Border.all(color: AppColors.grey700, width: 1),
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: AppTypography.cameraTelemetry(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.grey200,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step,
                    style: AppTypography.cameraTelemetry(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.2,
                      color: AppColors.grey300,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
