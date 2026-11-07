import 'package:flutter/material.dart';
import 'package:isometric/common/theme/app_colors.dart';
import 'package:isometric/common/widgets/glass_container.dart';

/// Round glass button used for grid, flash and camera flip.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  final bool loading;
  final double padding;
  final double iconSize;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.active = false,
    this.loading = false,
    this.padding = 10,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.pureBlack : AppColors.pureWhite;

    return GlassContainer(
      shape: BoxShape.circle,
      padding: EdgeInsets.all(padding),
      backgroundColor: active ? AppColors.pureWhite : AppColors.glassBackground,
      borderColor: active ? AppColors.pureWhite : AppColors.glassBorder,
      onTap: onTap,
      child: loading
          ? SizedBox(
              width: iconSize,
              height: iconSize,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.pureWhite,
              ),
            )
          : Icon(icon, size: iconSize, color: fg),
    );
  }
}
