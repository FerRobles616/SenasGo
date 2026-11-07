import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:senasgo/core/theme/app_theme.dart';

/// Sendero continuo que une los nodos del camino.
///
/// En vez de una sucesión de puntos, dibuja una cinta de fondo y sobre ella el
/// tramo recorrido con color y el tramo pendiente con guiones largos. Los nodos
/// se apoyan encima, así el recorrido se lee como un solo camino.
class PathPainter extends CustomPainter {
  const PathPainter({
    required this.points,
    required this.reachedUntil,
    required this.color,
    this.progress = 1,
  });

  /// Centros de los nodos, en orden.
  final List<Offset> points;

  /// Índice del último nodo alcanzado (completado o actual); -1 = ninguno.
  final int reachedUntil;
  final Color color;

  /// Progreso de dibujo de 0 a 1 para la animación de entrada.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final segments = <_Segment>[];
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      final path = _segment(points[i], points[i + 1]);
      final length =
          path.computeMetrics().fold<double>(0, (a, m) => a + m.length);
      segments.add(_Segment(path, length, i + 1 <= reachedUntil));
      total += length;
    }
    if (total <= 0) return;

    final visibleLength = total * progress.clamp(0.0, 1.0);
    var walked = 0.0;

    // Cinta base: mantiene unido el camino incluso en los tramos pendientes.
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 20
      ..color = color.withValues(alpha: AppColors.isDark ? 0.24 : 0.20);
    final basePath = Path();
    for (final segment in segments) {
      basePath.addPath(segment.path, Offset.zero);
    }
    canvas.drawPath(basePath, basePaint);

    for (final segment in segments) {
      final available = (visibleLength - walked).clamp(0.0, segment.length);
      if (available <= 0) break;
      final visible = _trim(segment.path, available);
      if (segment.reached) {
        // Resplandor suave del tramo recorrido.
        canvas.drawPath(
          visible,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = 16
            ..color = color.withValues(alpha: 0.14)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        final shader = LinearGradient(
          colors: [color, Color.lerp(color, AppColors.gold, 0.22)!],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Offset.zero & size);
        canvas.drawPath(
          visible,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = 10
            ..shader = shader,
        );
        // Brillo central que da volumen al sendero.
        canvas.drawPath(
          visible,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = 2.2
            ..color = Colors.white.withValues(alpha: 0.38),
        );
      } else {
        canvas.drawPath(
          visible,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = 6
            ..color = color.withValues(alpha: 0.46),
        );
      }
      walked += segment.length;
      if (walked >= visibleLength) break;
    }
  }

  Path _segment(Offset a, Offset b) {
    final midY = (a.dy + b.dy) / 2;
    return Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(a.dx, midY, b.dx, midY, b.dx, b.dy);
  }

  Path _trim(Path path, double length) {
    final out = Path();
    var remaining = length;
    for (final metric in path.computeMetrics()) {
      if (remaining <= 0) break;
      final take = math.min(remaining, metric.length);
      out.addPath(metric.extractPath(0, take), Offset.zero);
      remaining -= take;
    }
    return out;
  }

  @override
  bool shouldRepaint(covariant PathPainter old) =>
      old.points != points ||
      old.reachedUntil != reachedUntil ||
      old.color != color ||
      old.progress != progress;
}

class _Segment {
  const _Segment(this.path, this.length, this.reached);

  final Path path;
  final double length;
  final bool reached;
}
