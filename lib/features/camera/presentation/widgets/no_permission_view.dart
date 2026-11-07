import 'package:flutter/material.dart';
import 'package:isometric/common/theme/app_colors.dart';
import 'package:isometric/common/theme/app_typography.dart';

class NoPermissionView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const NoPermissionView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pureBlack,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_rounded,
                size: 48,
                color: AppColors.grey500,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.cameraTelemetry(
                  fontSize: 13,
                  color: AppColors.grey300,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('RETRY'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.pureWhite,
                  foregroundColor: AppColors.pureBlack,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}