
import 'package:flutter/material.dart';
import 'package:isometric/common/theme/app_colors.dart';

class ShutterButton extends StatefulWidget {
  final bool isProcessing;
  final VoidCallback onTap;

  const ShutterButton({super.key, required this.isProcessing, required this.onTap});

  @override
  State<ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<ShutterButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.90).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (!widget.isProcessing) _controller.forward();
      },
      onTapUp: (_) {
        if (!widget.isProcessing) {
          _controller.reverse();
          widget.onTap();
        }
      },
      onTapCancel: () {
        if (!widget.isProcessing) _controller.reverse();
      },
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.pureWhite, width: 3.5),
            boxShadow: const [
              BoxShadow(
                color: AppColors.glassShadow,
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(5),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.pureWhite,
            ),
            child: widget.isProcessing
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.pureBlack,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}