import 'package:flutter/material.dart';
import 'package:isometric/common/theme/app_colors.dart';

class FullScreenLoader extends StatelessWidget {
  const FullScreenLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.pureBlack,
      body: Center(
        child: CircularProgressIndicator(
          color: AppColors.pureWhite,
          strokeWidth: 2,
        ),
      ),
    );
  }
}