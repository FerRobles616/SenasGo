import 'package:flutter/material.dart';
import 'package:senasgo/core/theme/app_theme.dart';

/// Camino curvo que une los nodos. El tramo ya recorrido va en el color de
/// la unidad; el que falta, gris y punteado.
class PathPainter extends CustomPainter {
  const PathPainter({
    required this.points,
    required this.reachedUntil,
    required this.color,
  });

  /// Centros de los nodos, en orden.
  final List<Offset> points;

  /// Índice del último nodo alcanzado (completado o actual); -1 = ninguno.
  final int reachedUntil;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i], b = points[i + 1];
      final midY = (a.dy + b.dy) / 2;
      final segment = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx, midY, b.dx, midY, b.dx, b.dy);
      final reached = i + 1 <= reachedUntil;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 13
        ..color = reached ? color.withValues(alpha: 0.42) : AppColors.border;
      if (reached) {
        // Un trazo claro debajo separa el camino del fondo y le da volumen.
        canvas.drawPath(
          segment,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 19
            ..color = Colors.white.withValues(alpha: 0.8),
        );
        canvas.drawPath(segment, paint);
      } else {
        _dashed(canvas, segment, paint);
      }
    }
  }

  void _dashed(Canvas canvas, Path path, Paint paint) {
    const dash = 2.0, gap = 22.0;
    for (final metric in path.computeMetrics()) {
      var d = 6.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant PathPainter old) =>
      old.points != points ||
      old.reachedUntil != reachedUntil ||
      old.color != color;
}
