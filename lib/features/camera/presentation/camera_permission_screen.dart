import 'dart:io';
import 'package:flutter/material.dart';
import 'package:isometric/common/theme/theme.dart';
import 'package:isometric/common/widgets/glass_container.dart';

/// Shown when camera permission has been denied.
/// Guides the user to grant access — either via a system dialog or Settings.
class CameraPermissionScreen extends StatelessWidget {
  /// True  → user denied once (can still request via dialog).
  /// False → user denied permanently (must open Settings).
  final bool isPermanentlyDenied;

  /// Called when the user taps "Grant Permission" or "Open Settings".
  final VoidCallback onRetry;

  const CameraPermissionScreen({
    super.key,
    required this.isPermanentlyDenied,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pureBlack,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Icon — glass card with camera icon
              GlassContainer(
                shape: BoxShape.circle,
                padding: const EdgeInsets.all(28),
                backgroundColor: AppColors.glassSurface,
                borderColor: AppColors.glassBorderHighlight,
                child: Icon(
                  isPermanentlyDenied
                      ? Icons.no_photography_rounded
                      : Icons.camera_alt_outlined,
                  size: 56,
                  color: AppColors.grey200,
                ),
              ),

              const SizedBox(height: 36),

              // Title
              Text(
                isPermanentlyDenied ? 'Camera Access\nBlocked' : 'Camera Permission\nRequired',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.pureWhite,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),

              const SizedBox(height: 16),

              // Description
              Text(
                isPermanentlyDenied
                    ? 'Camera access was permanently denied.\n\nOpen Settings → Permissions → Camera\nand enable it to use Isometric.'
                    : 'Isometric needs access to your camera\nto capture and enhance photos.',
                textAlign: TextAlign.center,
                style: AppTypography.cameraTelemetry(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.3,
                  color: AppColors.grey400,
                ),
              ),

              const SizedBox(height: 48),

              // Primary Action Button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onRetry,
                  icon: Icon(
                    isPermanentlyDenied ? Icons.settings_rounded : Icons.camera_alt_rounded,
                    size: 18,
                  ),
                  label: Text(
                    isPermanentlyDenied ? 'OPEN SETTINGS' : 'GRANT CAMERA ACCESS',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.pureWhite,
                    foregroundColor: AppColors.pureBlack,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: AppTypography.cameraTelemetry(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: AppColors.pureBlack,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),

              if (isPermanentlyDenied) ...[
                const SizedBox(height: 14),
                // Step instruction
                _StepInstructionCard(),
              ],

              const Spacer(flex: 3),

              // App name at the bottom
              Text(
                'ISOMETRIC',
                style: AppTypography.cameraTelemetry(
                  fontSize: 10,
                  color: AppColors.grey700,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepInstructionCard extends StatelessWidget {
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
