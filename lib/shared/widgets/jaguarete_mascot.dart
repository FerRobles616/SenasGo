import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ánimo de la mascota.
enum MascotMood { happy, cheering, thinking }

/// Jaguareté, la mascota guía de SeñasGo. Se dibuja en código para no
/// depender de assets; se puede reemplazar por una ilustración o un Rive
/// sin tocar a quien lo usa.
class JaguareteMascot extends StatefulWidget {
  const JaguareteMascot(
      {this.size = 72, this.mood = MascotMood.happy, super.key});

  final double size;
  final MascotMood mood;

  @override
  State<JaguareteMascot> createState() => _JaguareteMascotState();
}

class _JaguareteMascotState extends State<JaguareteMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respeta "reducir animaciones" del sistema (accesibilidad).
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _idle.stop();
    } else if (!_idle.isAnimating) {
      _idle.repeat();
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(painter: _JaguarPainter(_idle, widget.mood)),
      ),
    );
  }
}

class _JaguarPainter extends CustomPainter {
  _JaguarPainter(this.idle, this.mood) : super(repaint: idle);

  final Animation<double> idle;
  final MascotMood mood;

  static const _fur = Color(0xFFF4A23B);
  static const _furShade = Color(0xFFDB8420);
  static const _cream = Color(0xFFFFF1DA);
  static const _ink = Color(0xFF3B2A20);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final t = idle.value;
    // Balanceo suave de la cabeza y parpadeo breve. Al celebrar, el jaguareté
    // da un pequeño salto para acompañar la recompensa sin mover el layout.
    final tiltAmount = switch (mood) {
      MascotMood.cheering => 0.075,
      MascotMood.thinking => -0.035,
      MascotMood.happy => 0.05,
    };
    final tilt = math.sin(t * 2 * math.pi) * tiltAmount;
    final bob = mood == MascotMood.cheering
        ? math.sin(t * 4 * math.pi).abs() * s * 0.02
        : 0.0;
    final blink = (t > 0.9 && t < 0.96) ? 0.15 : 1.0;

    canvas.save();
    canvas.translate(s / 2, s * 0.56 - bob);
    canvas.rotate(tilt);

    final fur = Paint()..color = _fur;
    final ink = Paint()..color = _ink;

    // Orejas
    for (final side in [-1.0, 1.0]) {
      final ear = Offset(side * s * 0.3, -s * 0.33);
      canvas.drawCircle(ear, s * 0.13, Paint()..color = _furShade);
      canvas.drawCircle(ear, s * 0.065, ink);
    }

    // Cabeza
    final head =
        Rect.fromCenter(center: Offset.zero, width: s * 0.84, height: s * 0.76);
    canvas.drawOval(head, fur);

    // Rosetas del jaguareté: grupos de manchas, no anillos.
    final spot = Paint()..color = _ink.withValues(alpha: 0.7);
    for (final (x, y) in const [
      (-0.17, -0.26),
      (0.17, -0.26),
      (0.0, -0.31),
      (-0.34, -0.04),
      (0.34, -0.04),
    ]) {
      for (final (dx, dy, r) in const [
        (-0.025, 0.0, 0.017),
        (0.022, -0.018, 0.014),
        (0.018, 0.024, 0.013),
      ]) {
        canvas.drawCircle(Offset((x + dx) * s, (y + dy) * s), r * s, spot);
      }
    }

    // Hocico
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(0, s * 0.13), width: s * 0.46, height: s * 0.32),
      Paint()..color = _cream,
    );

    // Ojos
    for (final side in [-1.0, 1.0]) {
      final eye = Offset(side * s * 0.16, -s * 0.06);
      canvas.drawOval(
        Rect.fromCenter(center: eye, width: s * 0.13, height: s * 0.16 * blink),
        ink,
      );
      if (blink > 0.5) {
        canvas.drawCircle(eye + Offset(s * 0.025, -s * 0.03), s * 0.025,
            Paint()..color = Colors.white);
      }
    }

    // Nariz
    final nose = Path()
      ..moveTo(-s * 0.06, s * 0.05)
      ..quadraticBezierTo(0, s * 0.03, s * 0.06, s * 0.05)
      ..quadraticBezierTo(0, s * 0.13, -s * 0.06, s * 0.05);
    canvas.drawPath(nose, Paint()..color = const Color(0xFF6B3A2A));

    // Boca
    final mouth = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.025
      ..strokeCap = StrokeCap.round;
    if (mood == MascotMood.cheering) {
      final open = Path()
        ..moveTo(-s * 0.09, s * 0.16)
        ..quadraticBezierTo(0, s * 0.3, s * 0.09, s * 0.16)
        ..close();
      canvas.drawPath(open, Paint()..color = const Color(0xFFB4433F));
    } else if (mood == MascotMood.thinking) {
      canvas.drawLine(
          Offset(-s * 0.05, s * 0.18), Offset(s * 0.05, s * 0.17), mouth);
    } else {
      for (final side in [-1.0, 1.0]) {
        canvas.drawArc(
          Rect.fromCircle(
              center: Offset(side * s * 0.045, s * 0.14), radius: s * 0.045),
          0.2,
          2.6,
          false,
          mouth,
        );
      }
    }

    // Mejillas
    for (final side in [-1.0, 1.0]) {
      canvas.drawCircle(
        Offset(side * s * 0.27, s * 0.08),
        s * 0.05,
        Paint()..color = const Color(0xFFFF8A80).withValues(alpha: 0.45),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _JaguarPainter old) => old.mood != mood;
}
