import 'package:flutter/material.dart';
import 'package:isometric/common/theme/theme.dart';

/// Clean, minimal framing grid overlay (ON/OFF).
class SimpleGridOverlay extends StatelessWidget {
  final bool isVisible;

  const SimpleGridOverlay({
    super.key,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _GridPainter(),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.pureWhite.withValues(alpha: 0.28)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // Horizontal framing lines
    final y1 = size.height / 3;
    final y2 = size.height * 2 / 3;
    canvas.drawLine(Offset(0, y1), Offset(size.width, y1), paint);
    canvas.drawLine(Offset(0, y2), Offset(size.width, y2), paint);

    // Vertical framing lines
    final x1 = size.width / 3;
    final x2 = size.width * 2 / 3;
    canvas.drawLine(Offset(x1, 0), Offset(x1, size.height), paint);
    canvas.drawLine(Offset(x2, 0), Offset(x2, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
