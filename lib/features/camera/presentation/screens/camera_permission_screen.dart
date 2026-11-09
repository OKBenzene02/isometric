import 'package:flutter/material.dart';
import 'package:isometric/common/theme/theme.dart';
import 'package:isometric/common/widgets/glass_container.dart';
import 'package:isometric/features/camera/presentation/widgets/step_instruction_card.dart';

class CameraPermissionScreen extends StatelessWidget {
  final bool isPermanentlyDenied;
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
                StepInstructionCard(),
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