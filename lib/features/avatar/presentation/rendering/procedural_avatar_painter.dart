import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:senasgo/core/vision/hand_landmarks.dart';
import 'package:senasgo/features/avatar/presentation/controllers/avatar_playback_controller.dart';
import 'package:senasgo/features/avatar/presentation/rendering/avatar_skeleton.dart';

/// Colores del profesor jaguareté. La túnica violeta es la identidad de
/// SeñasGo; ya no hay ropa desbloqueable.
class AvatarPalette {
  const AvatarPalette({
    this.skin = const Color(0xFFF6E7CA),
    this.skinShade = const Color(0xFFCFB48A),
    this.hair = const Color(0xFF3B2A20),
    this.fur = const Color(0xFFF2A33A),
    this.furShade = const Color(0xFFD07D1C),
    this.muzzle = const Color(0xFFFFF4DE),
    this.tunic = tunicBlue,
    this.pattern = const Color(0xFFFFF4E6),
    this.metal = const Color(0xFFC3CCD6),
    this.gold = const Color(0xFFE4B63E),
    this.leather = const Color(0xFF7B4A2A),
    this.accent = const Color(0xFF0F766E),
  });

  /// Túnica azul de la marca (color por defecto).
  static const Color tunicBlue = Color(0xFF0F766E);

  /// Túnica roja histórica, conservada por compatibilidad de assets.
  static const Color tunicRed = Color(0xFFC9372C);

  /// Manos (crema: contrastan con la túnica para leer la seña).
  final Color skin;
  final Color skinShade;

  /// Manchas, cejas y ojos.
  final Color hair;
  final Color fur;
  final Color furShade;
  final Color muzzle;
  final Color tunic;
  final Color pattern;
  final Color metal;
  final Color gold;
  final Color leather;
  final Color accent;

  Color get tunicShade => Color.lerp(tunic, Colors.black, 0.28)!;
  Color get tunicLight => Color.lerp(tunic, Colors.white, 0.18)!;
  Color get skinBack => Color.lerp(skin, skinShade, 0.35)!;
  Color get furLight => Color.lerp(fur, Colors.white, 0.22)!;
  Color get metalShade => Color.lerp(metal, Colors.black, 0.3)!;
}

/// Profesor jaguareté pseudo-3D dibujado en tiempo real: se puede girar con
/// el dedo, no necesita assets y corre fluido incluso en equipos de gama baja.
class ProceduralAvatarPainter extends CustomPainter {
  ProceduralAvatarPainter({
    required this.controller,
    required this.palette,
    required this.trail,
  }) : super(repaint: controller);

  final AvatarPlaybackController controller;
  final AvatarPalette palette;

  /// Trayectoria de la muñeca dominante durante la seña (guía de movimiento).
  final List<Vec3> trail;

  @override
  void paint(Canvas canvas, Size size) {
    final skeleton =
        AvatarSkeleton.solve(controller.frame, breath: controller.breath);
    final cam = _Camera(
      yaw: controller.yaw,
      pitch: controller.pitch,
      scale: math.min(size.height / 1.5, size.width / 1.1),
      center: Offset(size.width / 2, size.height * 0.55),
    );

    _shadow(canvas, cam);
    _trail(canvas, cam);

    final drawables = <_Drawable>[
      _Drawable(cam.depth(const Vec3(0, -0.2, -0.1)), () => _cape(canvas, cam)),
      _Drawable(cam.depth(const Vec3(0, -0.2, 0)), () => _torso(canvas, cam)),
      _Drawable(
          cam.depth(skeleton.neck) + 0.005, () => _neck(canvas, cam, skeleton)),
      _Drawable(cam.depth(skeleton.headCenter) + 0.01,
          () => _head(canvas, cam, skeleton)),
      ..._arm(canvas, cam, skeleton.passive, dominant: false),
      ..._arm(canvas, cam, skeleton.dominant, dominant: true),
    ]..sort((a, b) => a.depth.compareTo(b.depth));
    for (final d in drawables) {
      d.paint();
    }
  }

  // ───────────────────────────── Cuerpo ─────────────────────────────

  void _shadow(Canvas canvas, _Camera cam) {
    // Degradado radial en lugar de MaskFilter.blur: mismo aspecto, mucho
    // más barato para la GPU (y evita un crash del emulador API 37).
    final c = cam.project(const Vec3(0, -0.6, 0));
    final rx = cam.scale * 0.3;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(1, 0.14);
    canvas.drawCircle(
      Offset.zero,
      rx,
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, rx, [
          Colors.black.withValues(alpha: 0.13),
          Colors.black.withValues(alpha: 0),
        ]),
    );
    canvas.restore();
  }

  /// Capa roja detrás de los hombros (se ve al girar al profesor).
  void _cape(Canvas canvas, _Camera cam) {
    const pts = [
      Vec3(-0.25, 0.05, -0.07),
      Vec3(0.25, 0.05, -0.07),
      Vec3(-0.28, -0.5, -0.11),
      Vec3(0.28, -0.5, -0.11),
      Vec3(-0.14, 0.08, -0.05),
      Vec3(0.14, 0.08, -0.05),
    ];
    final path = Path()
      ..addPolygon(_convexHull([for (final p in pts) cam.project(p)]), true);
    canvas.drawPath(path, Paint()..color = palette.tunicShade);
    canvas.drawPath(
      path,
      Paint()
        ..color = palette.tunicShade
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = cam.scale * 0.06,
    );
  }

  void _torso(Canvas canvas, _Camera cam) {
    // Silueta con hombros caídos, pecho y cintura (sin forma de caja).
    const pts = [
      Vec3(-0.11, 0.075, 0.05),
      Vec3(0.11, 0.075, 0.05),
      Vec3(-0.11, 0.075, -0.05),
      Vec3(0.11, 0.075, -0.05),
      Vec3(-0.225, 0.0, 0.06),
      Vec3(0.225, 0.0, 0.06),
      Vec3(-0.225, 0.0, -0.06),
      Vec3(0.225, 0.0, -0.06),
      Vec3(-0.205, -0.24, 0.09),
      Vec3(0.205, -0.24, 0.09),
      Vec3(-0.205, -0.24, -0.08),
      Vec3(0.205, -0.24, -0.08),
      Vec3(-0.17, -0.62, 0.08),
      Vec3(0.17, -0.62, 0.08),
      Vec3(-0.17, -0.62, -0.08),
      Vec3(0.17, -0.62, -0.08),
    ];
    final hull = _convexHull([for (final p in pts) cam.project(p)]);
    final path = Path()..addPolygon(hull, true);
    final bounds = path.getBounds();
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          bounds.topCenter,
          bounds.bottomCenter,
          [palette.tunicLight, palette.tunic, palette.tunicShade],
          const [0, 0.45, 1],
        ),
    );
    // Bordes suaves (sin esquinas duras).
    canvas.drawPath(
      path,
      Paint()
        ..color = palette.tunic
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = cam.scale * 0.08,
    );

    // Detalles del frente: guarda de la túnica, pechera y cinturón.
    if (cam.facing(const Vec3(0, 0, 1)) > -0.15) {
      _skirtPanel(canvas, cam);
      _chestPlate(canvas, cam);
      _belt(canvas, cam);
    }
    _scarf(canvas, cam);
  }

  /// Pechera plateada redondeada con chevrones y medallón (sin pinchos).
  void _chestPlate(Canvas canvas, _Camera cam) {
    const pts = [
      Vec3(-0.17, 0.03, 0.08),
      Vec3(0.17, 0.03, 0.08),
      Vec3(-0.18, -0.12, 0.1),
      Vec3(0.18, -0.12, 0.1),
      Vec3(-0.16, -0.24, 0.105),
      Vec3(0.16, -0.24, 0.105),
    ];
    final path = Path()
      ..addPolygon(_convexHull([for (final p in pts) cam.project(p)]), true);
    final b = path.getBounds();
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(b.topLeft, b.bottomRight, [
          Color.lerp(palette.metal, Colors.white, 0.45)!,
          palette.metal,
          palette.metalShade,
        ], const [
          0,
          0.5,
          1
        ]),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = palette.metalShade
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = cam.scale * 0.012,
    );
    final chevron = Paint()
      ..color = palette.gold
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = cam.scale * 0.011;
    for (var k = 0; k < 3; k++) {
      final y = -0.1 - k * 0.042;
      final a = cam.project(Vec3(-0.11, y, 0.104));
      final m = cam.project(Vec3(0, y - 0.04, 0.108));
      final c = cam.project(Vec3(0.11, y, 0.104));
      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(m.dx, m.dy)
          ..lineTo(c.dx, c.dy),
        chevron,
      );
    }
    _medallion(canvas, cam, const Vec3(0, -0.035, 0.1), 0.03);
  }

  void _belt(Canvas canvas, _Camera cam) {
    final quad = [
      cam.project(const Vec3(-0.2, -0.255, 0.1)),
      cam.project(const Vec3(0.2, -0.255, 0.1)),
      cam.project(const Vec3(0.19, -0.315, 0.095)),
      cam.project(const Vec3(-0.19, -0.315, 0.095)),
    ];
    canvas.drawPath(
        Path()..addPolygon(quad, true), Paint()..color = palette.leather);
    _medallion(canvas, cam, const Vec3(0, -0.285, 0.11), 0.032);
  }

  /// Panel central de la túnica con rombos (guarda geométrica).
  void _skirtPanel(Canvas canvas, _Camera cam) {
    final panel = [
      cam.project(const Vec3(-0.06, -0.31, 0.093)),
      cam.project(const Vec3(0.06, -0.31, 0.093)),
      cam.project(const Vec3(0.06, -0.62, 0.083)),
      cam.project(const Vec3(-0.06, -0.62, 0.083)),
    ];
    canvas.drawPath(
        Path()..addPolygon(panel, true), Paint()..color = palette.tunicShade);
    final ink = Paint()
      ..color = palette.pattern
      ..style = PaintingStyle.stroke
      ..strokeWidth = cam.scale * 0.009;
    for (final y in [-0.37, -0.45, -0.53]) {
      final diamond = [
        cam.project(Vec3(0, y + 0.03, 0.095)),
        cam.project(Vec3(0.035, y, 0.095)),
        cam.project(Vec3(0, y - 0.03, 0.095)),
        cam.project(Vec3(-0.035, y, 0.095)),
      ];
      canvas.drawPath(Path()..addPolygon(diamond, true), ink);
      canvas.drawCircle(cam.project(Vec3(0, y, 0.096)), cam.scale * 0.007,
          Paint()..color = palette.pattern);
    }
  }

  /// Pañuelo rojo anudado al cuello.
  void _scarf(Canvas canvas, _Camera cam) {
    final c = cam.project(const Vec3(0, 0.07, 0.02));
    final rect = Rect.fromCenter(
        center: c,
        width: cam.scale * (0.17 + 0.05 * (1 - cam.cosYaw)),
        height: cam.scale * 0.075);
    canvas.drawOval(rect.translate(0, cam.scale * 0.01),
        Paint()..color = palette.tunicShade);
    canvas.drawOval(rect, Paint()..color = palette.tunic);
  }

  void _medallion(Canvas canvas, _Camera cam, Vec3 at, double radius) {
    final c = cam.project(at);
    final r = cam.scale * radius * cam.perspective(at);
    canvas.drawCircle(
        c, r, Paint()..color = Color.lerp(palette.gold, Colors.black, 0.25)!);
    canvas.drawCircle(
      c,
      r * 0.8,
      Paint()
        ..shader = ui.Gradient.radial(c + Offset(-r * 0.3, -r * 0.3), r,
            [Color.lerp(palette.gold, Colors.white, 0.5)!, palette.gold]),
    );
    canvas.drawCircle(
      c,
      r * 0.42,
      Paint()
        ..color = Color.lerp(palette.gold, Colors.black, 0.3)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.14,
    );
  }

  void _neck(Canvas canvas, _Camera cam, AvatarSkeleton s) {
    _capsule(canvas, cam, s.neck, s.headCenter - const Vec3(0, 0.06, 0), 0.085,
        palette.furShade);
  }

  // ───────────────────────────── Cabeza ─────────────────────────────

  void _head(Canvas canvas, _Camera cam, AvatarSkeleton s) {
    const rr = AvatarSkeleton.headRadius;
    final r =
        AvatarSkeleton.headRadius * cam.scale * cam.perspective(s.headCenter);
    final c = cam.project(s.headCenter);

    // Orejas redondas de jaguareté (detrás de la cabeza).
    for (final side in [-1.0, 1.0]) {
      final ear =
          cam.project(s.headPoint(Vec3(side * rr * 0.7, rr * 0.8, -rr * 0.1)));
      canvas.drawCircle(ear, r * 0.34, Paint()..color = palette.furShade);
      canvas.drawCircle(ear, r * 0.18, Paint()..color = palette.hair);
    }

    // Cabeza con volumen (luz desde arriba a la izquierda).
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          c + Offset(-r * 0.3, -r * 0.35),
          r * 1.4,
          [palette.furLight, palette.fur, palette.furShade],
          const [0, 0.55, 1],
        ),
    );

    final facing = cam.facing(s.facePoint(0, 0) - s.headCenter);
    if (facing > 0.08) _face(canvas, cam, s, r, facing.clamp(0.0, 1.0));
  }

  void _face(
      Canvas canvas, _Camera cam, AvatarSkeleton s, double r, double facing) {
    final f = controller.frame.face;
    final alpha = ((facing - 0.08) / 0.3).clamp(0.0, 1.0);
    final ink = palette.hair.withValues(alpha: alpha);

    // Rosetas: grupos de manchas que acompañan el giro de la cabeza.
    final spot = Paint()..color = palette.hair.withValues(alpha: 0.75 * alpha);
    for (final (u, v) in const [
      (0.0, 0.76),
      (-0.36, 0.7),
      (0.36, 0.7),
      (-0.74, 0.42),
      (0.74, 0.42),
      (-0.84, 0.05),
      (0.84, 0.05),
    ]) {
      for (final (du, dv, k) in const [
        (-0.05, 0.0, 0.06),
        (0.045, 0.035, 0.05),
        (0.04, -0.045, 0.045),
      ]) {
        canvas.drawCircle(
            cam.project(s.facePoint(u + du, v + dv)), r * k, spot);
      }
    }

    // Hocico crema con "cachetes" de felino.
    final muzzle = Paint()..color = palette.muzzle.withValues(alpha: alpha);
    for (final u in [-0.2, 0.2]) {
      canvas.drawCircle(cam.project(s.facePoint(u, -0.36)), r * 0.27, muzzle);
    }
    canvas.drawOval(
      Rect.fromCenter(
          center: cam.project(s.facePoint(0, -0.22)),
          width: r * 0.62 * facing,
          height: r * 0.42),
      muzzle,
    );

    // Ojos grandes y amables (con parpadeo y apertura según la expresión).
    final open = (1 - controller.blink) *
        (1 - f.squint * 0.45) *
        (1 + f.eyesWide * 0.35);
    for (final u in [-0.34, 0.34]) {
      final e = cam.project(s.facePoint(u, 0.13));
      canvas.drawOval(
        Rect.fromCenter(
            center: e,
            width: r * 0.22 * facing,
            height: math.max(r * 0.27 * open, r * 0.03)),
        Paint()..color = ink,
      );
      if (open > 0.4) {
        final white = Paint()
          ..color = Colors.white.withValues(alpha: 0.95 * alpha);
        canvas.drawCircle(e + Offset(r * 0.04, -r * 0.05), r * 0.045, white);
        canvas.drawCircle(e + Offset(-r * 0.03, r * 0.05), r * 0.022, white);
      }
    }

    // Cejas de pelaje: suben (pregunta) o se juntan y bajan (negación).
    final brow = Paint()
      ..color = ink
      ..strokeWidth = r * 0.065
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final side in [-1.0, 1.0]) {
      final inner = cam.project(s.facePoint(
          side * 0.15, 0.37 + f.browRaise * 0.12 - f.browFurrow * 0.1));
      final outer = cam.project(s.facePoint(
          side * 0.48, 0.36 + f.browRaise * 0.09 + f.browFurrow * 0.02));
      final mid = cam.project(s.facePoint(
          side * 0.32, 0.42 + f.browRaise * 0.13 - f.browFurrow * 0.04));
      canvas.drawPath(
        Path()
          ..moveTo(inner.dx, inner.dy)
          ..quadraticBezierTo(mid.dx, mid.dy, outer.dx, outer.dy),
        brow,
      );
    }

    // Nariz de felino
    final nl = cam.project(s.facePoint(-0.12, -0.12, out: 1.04));
    final nr = cam.project(s.facePoint(0.12, -0.12, out: 1.04));
    final nb = cam.project(s.facePoint(0, -0.23, out: 1.05));
    canvas.drawPath(
      Path()
        ..moveTo(nl.dx, nl.dy)
        ..quadraticBezierTo((nl.dx + nr.dx) / 2, nl.dy - r * 0.04, nr.dx, nr.dy)
        ..quadraticBezierTo(nr.dx, nb.dy - r * 0.02, nb.dx, nb.dy)
        ..quadraticBezierTo(nl.dx, nb.dy - r * 0.02, nl.dx, nl.dy),
      Paint()..color = const Color(0xFF5A3324).withValues(alpha: alpha),
    );

    // Mejillas cuando sonríe
    if (f.smile > 0.25) {
      for (final u in [-0.55, 0.55]) {
        final cheek = cam.project(s.facePoint(u, -0.2));
        const blush = Color(0xFFFF7F7F);
        canvas.drawCircle(
          cheek,
          r * 0.16,
          Paint()
            ..shader = ui.Gradient.radial(cheek, r * 0.16, [
              blush.withValues(alpha: 0.4 * alpha * f.smile),
              blush.withValues(alpha: 0),
            ]),
        );
      }
    }

    // Boca de felino ("w"): sonríe, se abre o baja las comisuras (negación).
    final top = cam.project(s.facePoint(0, -0.3, out: 1.03));
    final left = cam.project(s.facePoint(-0.2, -0.37 + f.smile * 0.08));
    final right = cam.project(s.facePoint(0.2, -0.37 + f.smile * 0.08));
    final ctrlL = cam.project(s.facePoint(-0.1, -0.43 - f.smile * 0.04));
    final ctrlR = cam.project(s.facePoint(0.1, -0.43 - f.smile * 0.04));
    if (f.mouthOpen > 0.05 || f.smile > 0.55) {
      final low = cam
          .project(s.facePoint(0, -0.5 - f.smile * 0.08 - f.mouthOpen * 0.16));
      final open = Path()
        ..moveTo(left.dx, left.dy)
        ..quadraticBezierTo(top.dx, top.dy + r * 0.05, right.dx, right.dy)
        ..quadraticBezierTo(low.dx, low.dy + r * 0.1, left.dx, left.dy);
      canvas.drawPath(open,
          Paint()..color = const Color(0xFF8E2F35).withValues(alpha: alpha));
      canvas.drawCircle(low - Offset(0, r * 0.03), r * 0.07,
          Paint()..color = const Color(0xFFFF8F96).withValues(alpha: alpha));
    }
    final stroke = Paint()
      ..color = const Color(0xFF5A3324).withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.05;
    canvas.drawLine(nb, top, stroke);
    canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy)
        ..quadraticBezierTo(ctrlL.dx, ctrlL.dy, left.dx, left.dy)
        ..moveTo(top.dx, top.dy)
        ..quadraticBezierTo(ctrlR.dx, ctrlR.dy, right.dx, right.dy),
      stroke,
    );

    // Bigotes
    final whisker = Paint()
      ..color = palette.hair.withValues(alpha: 0.45 * alpha)
      ..strokeWidth = r * 0.022
      ..strokeCap = StrokeCap.round;
    for (final side in [-1.0, 1.0]) {
      final root = cam.project(s.facePoint(side * 0.32, -0.3));
      for (final dy in [-0.1, 0.02, 0.14]) {
        canvas.drawLine(
            root, root + Offset(side * r * 0.55 * facing, r * dy), whisker);
      }
    }
  }

  // ───────────────────────────── Brazos y manos ─────────────────────────────

  List<_Drawable> _arm(Canvas canvas, _Camera cam, ArmGeometry arm,
      {required bool dominant}) {
    final fur = dominant
        ? palette.fur
        : Color.lerp(palette.fur, palette.furShade, 0.4)!;
    final leather = dominant
        ? palette.leather
        : Color.lerp(palette.leather, Colors.black, 0.15)!;
    final hand = arm.hand;
    return [
      _Drawable(cam.depth(Vec3.lerp(arm.shoulder, arm.elbow, 0.5)) - 0.02, () {
        _capsule(canvas, cam, arm.shoulder, arm.elbow, 0.088, fur);
        _spots(canvas, cam, arm.shoulder, arm.elbow);
        _shoulderPad(canvas, cam, arm.shoulder);
      }),
      _Drawable(cam.depth(Vec3.lerp(arm.elbow, hand.wrist, 0.5)), () {
        _capsule(canvas, cam, arm.elbow, hand.wrist, 0.074, fur);
        // Brazalete de cuero con franja dorada.
        final from = Vec3.lerp(arm.elbow, hand.wrist, 0.38);
        final to = Vec3.lerp(arm.elbow, hand.wrist, 0.94);
        _capsule(canvas, cam, from, to, 0.084, leather);
        _capsule(canvas, cam, Vec3.lerp(from, to, 0.48),
            Vec3.lerp(from, to, 0.52), 0.086, palette.gold);
      }),
      _Drawable(cam.depth(hand.wrist) + 0.03,
          () => _hand(canvas, cam, hand, dominant: dominant)),
    ];
  }

  void _spots(Canvas canvas, _Camera cam, Vec3 a, Vec3 b) {
    final paint = Paint()..color = palette.hair.withValues(alpha: 0.55);
    for (final (t, off) in const [(0.35, 0.012), (0.62, -0.01)]) {
      final p = Vec3.lerp(a, b, t) + Vec3(off, 0, 0.04);
      canvas.drawCircle(cam.project(p), cam.scale * 0.011, paint);
    }
  }

  /// Hombrera redondeada (amigable, sin puntas).
  void _shoulderPad(Canvas canvas, _Camera cam, Vec3 shoulder) {
    final at = shoulder + const Vec3(0, 0.015, 0.02);
    final c = cam.project(at);
    final r = cam.scale * 0.058 * cam.perspective(at);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader =
            ui.Gradient.radial(c + Offset(-r * 0.35, -r * 0.4), r * 1.3, [
          Color.lerp(palette.metal, Colors.white, 0.5)!,
          palette.metal,
          palette.metalShade,
        ], const [
          0,
          0.5,
          1
        ]),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = palette.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.16,
    );
  }

  void _hand(Canvas canvas, _Camera cam, HandGeometry h,
      {required bool dominant}) {
    final palmVisible = cam.facing(h.normal) > 0;
    final skin = palmVisible ? palette.skin : palette.skinBack;
    final k = cam.perspective(h.wrist);

    // Brillo de foco en la mano que ejecuta la seña.
    if (dominant && controller.frame.phase != 'Reposo') {
      final c = cam.project(h.wrist + (h.fingers[2][1] - h.wrist) * 0.6);
      canvas.drawCircle(
        c,
        cam.scale * 0.11 * k,
        Paint()
          ..shader = ui.Gradient.radial(c, cam.scale * 0.11 * k, [
            palette.accent.withValues(alpha: 0.22),
            palette.accent.withValues(alpha: 0),
          ]),
      );
    }

    void palm() {
      final poly = [for (final p in h.palm) cam.project(p)];
      final path = Path()..addPolygon(poly, true);
      canvas.drawPath(
        path,
        Paint()
          ..color = palette.skinShade
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = cam.scale * 0.03 * k,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = skin
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = cam.scale * 0.022 * k,
      );
      canvas.drawPath(path, Paint()..color = skin);
    }

    void fingers() {
      final chains = [...h.fingers]
        ..sort((a, b) => cam.depth(a.last).compareTo(cam.depth(b.last)));
      for (final chain in chains) {
        final thumb = identical(chain, h.fingers.first);
        final width = cam.scale * (thumb ? 0.022 : 0.019) * k;
        final path = Path();
        final first = cam.project(chain.first);
        path.moveTo(first.dx, first.dy);
        for (final p in chain.skip(1)) {
          final o = cam.project(p);
          path.lineTo(o.dx, o.dy);
        }
        final stroke = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(
            path,
            stroke
              ..color = palette.skinShade
              ..strokeWidth = width + cam.scale * 0.005);
        canvas.drawPath(
            path,
            stroke
              ..color = skin
              ..strokeWidth = width);
      }
    }

    // Con la palma visible los dedos doblados quedan delante; con el dorso,
    // detrás de la mano.
    if (palmVisible) {
      palm();
      fingers();
    } else {
      fingers();
      palm();
    }
  }

  void _trail(Canvas canvas, _Camera cam) {
    if (trail.length < 2) return;
    final dot = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < trail.length; i++) {
      final t = i / (trail.length - 1);
      dot.color = palette.accent.withValues(alpha: 0.10 + 0.25 * t);
      canvas.drawCircle(
          cam.project(trail[i]), cam.scale * (0.004 + 0.004 * t), dot);
    }
  }

  void _capsule(
      Canvas canvas, _Camera cam, Vec3 a, Vec3 b, double width, Color color) {
    canvas.drawLine(
      cam.project(a),
      cam.project(b),
      Paint()
        ..color = color
        ..strokeCap = StrokeCap.round
        ..strokeWidth =
            width * cam.scale * cam.perspective(Vec3.lerp(a, b, 0.5)),
    );
  }

  static List<Offset> _convexHull(List<Offset> points) {
    final p = [...points]..sort(
        (a, b) => a.dx != b.dx ? a.dx.compareTo(b.dx) : a.dy.compareTo(b.dy));
    double cross(Offset o, Offset a, Offset b) =>
        (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
    final lower = <Offset>[], upper = <Offset>[];
    for (final pt in p) {
      while (lower.length >= 2 &&
          cross(lower[lower.length - 2], lower.last, pt) <= 0) {
        lower.removeLast();
      }
      lower.add(pt);
    }
    for (final pt in p.reversed) {
      while (upper.length >= 2 &&
          cross(upper[upper.length - 2], upper.last, pt) <= 0) {
        upper.removeLast();
      }
      upper.add(pt);
    }
    return [...lower..removeLast(), ...upper..removeLast()];
  }

  @override
  bool shouldRepaint(covariant ProceduralAvatarPainter old) =>
      old.palette != palette ||
      old.trail != trail ||
      old.controller != controller;
}

class _Drawable {
  _Drawable(this.depth, this.paint);

  final double depth;
  final VoidCallback paint;
}

/// Cámara orbital con leve perspectiva.
class _Camera {
  _Camera(
      {required this.yaw,
      required this.pitch,
      required this.scale,
      required this.center});

  final double yaw;
  final double pitch;
  final double scale;
  final Offset center;
  static const double _focal = 3.2;

  double get cosYaw => math.cos(yaw).abs();

  Vec3 _view(Vec3 p) {
    final cy = math.cos(yaw), sy = math.sin(yaw);
    final x = p.x * cy + p.z * sy;
    final z1 = -p.x * sy + p.z * cy;
    final cp = math.cos(pitch), sp = math.sin(pitch);
    return Vec3(x, p.y * cp - z1 * sp, p.y * sp + z1 * cp);
  }

  double perspective(Vec3 p) => _focal / (_focal - _view(p).z);

  double depth(Vec3 p) => _view(p).z;

  /// Cuánto mira un vector (normal) hacia el estudiante (-1..1).
  double facing(Vec3 direction) => _view(direction.normalized()).z;

  Offset project(Vec3 p) {
    final v = _view(p);
    final k = _focal / (_focal - v.z);
    return center + Offset(v.x * k * scale, -v.y * k * scale);
  }
}
