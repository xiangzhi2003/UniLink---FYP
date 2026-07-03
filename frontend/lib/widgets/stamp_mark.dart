import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// UniLink's signature mark: a ticked ring like a library due-date stamp or
/// wax seal. `sealed: false` is the idle brand mark (outline, gold);
/// `sealed: true` is the one-time "verified" payoff (filled, verified-green),
/// shown when the user's email or handover is actually confirmed.
class StampMark extends StatelessWidget {
  final double size;
  final bool sealed;

  const StampMark({super.key, this.size = 64, this.sealed = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StampPainter(sealed: sealed),
        child: Center(
          child: Icon(
            sealed ? Icons.check_circle : Icons.check_circle_outline,
            size: size * 0.38,
            color: sealed ? AppColors.verified : AppColors.gold,
          ),
        ),
      ),
    );
  }
}

class _StampPainter extends CustomPainter {
  final bool sealed;

  _StampPainter({required this.sealed});

  @override
  void paint(Canvas canvas, Size size) {
    final color = sealed ? AppColors.verified : AppColors.gold;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final ringPaint = Paint()
      ..color = color.withValues(alpha: sealed ? 1 : 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035;
    canvas.drawCircle(center, radius - ringPaint.strokeWidth, ringPaint);

    const tickCount = 24;
    final tickPaint = Paint()
      ..color = color.withValues(alpha: sealed ? 1 : 0.6)
      ..strokeWidth = size.width * 0.025
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < tickCount; i++) {
      final angle = (2 * math.pi / tickCount) * i;
      final outer = radius * 0.92;
      final inner = radius * 0.78;
      final p1 = center + Offset(math.cos(angle), math.sin(angle)) * outer;
      final p2 = center + Offset(math.cos(angle), math.sin(angle)) * inner;
      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StampPainter oldDelegate) => oldDelegate.sealed != sealed;
}
