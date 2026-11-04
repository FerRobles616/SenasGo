import 'dart:ui' show lerpDouble;

import 'package:flutter/animation.dart';
import 'package:senasgo/core/vision/hand_landmarks.dart';

double _l(double a, double b, double t) => lerpDouble(a, b, t)!;

/// Configuración manual: flexión de cada dedo (0 = extendido, 1 = cerrado).
class HandShape {
  const HandShape({
    required this.curl,
    this.spread = 0.15,
    this.thumbAcross = 0,
  });

  /// Pulgar, índice, medio, anular, meñique.
  final List<double> curl;

  /// Separación de los dedos (0 = juntos, 1 = abiertos en abanico).
  final double spread;

  /// Pulgar cruzado sobre la palma (0 = al costado, 1 = sobre la palma).
  final double thumbAcross;

  // Configuraciones manuales base (ilustrativas, pendientes de validación LSPy).
  static const relaxed =
      HandShape(curl: [0.12, 0.12, 0.16, 0.2, 0.24], spread: 0.05);
  static const open = HandShape(curl: [0, 0, 0, 0, 0], spread: 0.8);
  static const flat = HandShape(curl: [0.1, 0, 0, 0, 0], spread: 0);
  static const fist = HandShape(curl: [0.6, 1, 1, 1, 1], thumbAcross: 1);
  static const index = HandShape(curl: [0.7, 0, 1, 1, 1], thumbAcross: 0.8);
  static const v =
      HandShape(curl: [0.7, 0, 0, 1, 1], spread: 0.6, thumbAcross: 0.8);
  static const three =
      HandShape(curl: [0.7, 0, 0, 0, 1], spread: 0.5, thumbAcross: 0.8);
  static const pinch =
      HandShape(curl: [0.45, 0.55, 0.55, 1, 1], thumbAcross: 0.3);

  static HandShape lerp(HandShape a, HandShape b, double t) => HandShape(
        curl: [for (var i = 0; i < 5; i++) _l(a.curl[i], b.curl[i], t)],
        spread: _l(a.spread, b.spread, t),
        thumbAcross: _l(a.thumbAcross, b.thumbAcross, t),
      );
}

/// Orientación de la palma como rotación (grados) desde la pose base:
/// dedos hacia arriba y palma mirando al estudiante.
class PalmOrientation {
  const PalmOrientation({this.pitch = 0, this.yaw = 0, this.roll = 0});

  /// Flexión de muñeca: + inclina los dedos hacia el lado de la palma,
  /// - hacia el dorso.
  final double pitch;

  /// Gira la palma: 0 = al estudiante, 90 = hacia el centro del cuerpo,
  /// 180 = hacia el señante. Se espeja solo para la mano no dominante.
  final double yaw;

  /// Rota la mano en el plano de la palma.
  final double roll;

  static const forward = PalmOrientation();
  static const toSigner = PalmOrientation(yaw: 180);
  static const side = PalmOrientation(yaw: 90);
  static const down = PalmOrientation(pitch: 90);
  static const up = PalmOrientation(pitch: -90);

  static PalmOrientation lerp(PalmOrientation a, PalmOrientation b, double t) =>
      PalmOrientation(
        pitch: _l(a.pitch, b.pitch, t),
        yaw: _l(a.yaw, b.yaw, t),
        roll: _l(a.roll, b.roll, t),
      );
}

/// Pose de una mano: lugar de articulación + configuración + orientación.
class HandPose {
  const HandPose({
    required this.wrist,
    this.shape = HandShape.relaxed,
    this.palm = PalmOrientation.forward,
  });

  /// Posición de la muñeca en el espacio del cuerpo (metros aprox.):
  /// x hacia la derecha del estudiante, y hacia arriba, z hacia el estudiante.
  /// Origen: centro entre los hombros.
  final Vec3 wrist;
  final HandShape shape;
  final PalmOrientation palm;

  static HandPose lerp(HandPose a, HandPose b, double t, {Vec3? wrist}) =>
      HandPose(
        wrist: wrist ?? Vec3.lerp(a.wrist, b.wrist, t),
        shape: HandShape.lerp(a.shape, b.shape, t),
        palm: PalmOrientation.lerp(a.palm, b.palm, t),
      );
}

/// Componente no manual del rostro (gramaticalmente obligatorio en LSPy).
class FaceExpression {
  const FaceExpression({
    this.browRaise = 0,
    this.browFurrow = 0,
    this.eyesWide = 0,
    this.squint = 0,
    this.smile = 0,
    this.mouthOpen = 0,
    this.label = 'neutral',
  });

  final double browRaise;
  final double browFurrow;
  final double eyesWide;
  final double squint;
  final double smile;
  final double mouthOpen;

  /// Descripción para el estudiante ("cejas levantadas", "ceño fruncido"...).
  final String label;

  static const neutral = FaceExpression();
  static const friendly =
      FaceExpression(smile: 0.7, browRaise: 0.2, label: 'sonrisa amable');
  static const question =
      FaceExpression(browRaise: 1, eyesWide: 0.6, label: 'cejas levantadas');
  static const negation = FaceExpression(
      browFurrow: 0.9, squint: 0.3, smile: -0.4, label: 'ceño fruncido');
  static const affirm =
      FaceExpression(browRaise: 0.3, smile: 0.3, label: 'afirmación suave');
  static const pleading =
      FaceExpression(browRaise: 0.6, smile: 0.35, label: 'gesto de pedido');

  static FaceExpression lerp(FaceExpression a, FaceExpression b, double t) =>
      FaceExpression(
        browRaise: _l(a.browRaise, b.browRaise, t),
        browFurrow: _l(a.browFurrow, b.browFurrow, t),
        eyesWide: _l(a.eyesWide, b.eyesWide, t),
        squint: _l(a.squint, b.squint, t),
        smile: _l(a.smile, b.smile, t),
        mouthOpen: _l(a.mouthOpen, b.mouthOpen, t),
        label: t < 0.5 ? a.label : b.label,
      );
}

/// Lenguaje corporal: cabeza y torso (en grados).
class BodyPose {
  const BodyPose({
    this.headPitch = 0,
    this.headYaw = 0,
    this.headRoll = 0,
    this.torsoLean = 0,
    this.shrug = 0,
    this.label = '',
  });

  /// Asentir (+ hacia abajo).
  final double headPitch;

  /// Negar con la cabeza (giro lateral).
  final double headYaw;

  /// Inclinación lateral de la cabeza.
  final double headRoll;

  /// Torso hacia adelante (+).
  final double torsoLean;

  /// Hombros levantados (0-1).
  final double shrug;

  final String label;

  static const rest = BodyPose();

  static BodyPose lerp(BodyPose a, BodyPose b, double t) => BodyPose(
        headPitch: _l(a.headPitch, b.headPitch, t),
        headYaw: _l(a.headYaw, b.headYaw, t),
        headRoll: _l(a.headRoll, b.headRoll, t),
        torsoLean: _l(a.torsoLean, b.torsoLean, t),
        shrug: _l(a.shrug, b.shrug, t),
        label: t < 0.5 ? a.label : b.label,
      );
}

/// Un instante clave de la seña. Entre keyframes se interpola de forma
/// suave: trayectoria Catmull-Rom para las muñecas y [easing] para el resto.
class AvatarKeyframe {
  const AvatarKeyframe({
    required this.at,
    required this.dominant,
    this.passive,
    this.face = FaceExpression.neutral,
    this.body = BodyPose.rest,
    this.easing = Curves.easeInOutCubic,
    this.phase,
  });

  /// Tiempo normalizado (0-1) dentro de la duración de la seña.
  final double at;

  /// Mano dominante (derecha del avatar; se ve como en un espejo).
  final HandPose dominant;

  /// Mano no dominante; null = en reposo.
  final HandPose? passive;

  final FaceExpression face;
  final BodyPose body;

  /// Curva del tramo que termina en este keyframe.
  final Curve easing;

  /// Fase pedagógica que se muestra al estudiante.
  final String? phase;
}

/// Pose completa ya resuelta para un instante (lo que dibuja el renderer).
class AvatarFrame {
  const AvatarFrame({
    required this.dominant,
    required this.passive,
    required this.face,
    required this.body,
    this.phase = 'Reposo',
  });

  final HandPose dominant;
  final HandPose passive;
  final FaceExpression face;
  final BodyPose body;
  final String phase;

  static const rest = AvatarFrame(
    dominant: HandPose(
        wrist: Vec3(-0.27, -0.42, 0.05), palm: PalmOrientation(yaw: 80)),
    passive: HandPose(
        wrist: Vec3(0.27, -0.42, 0.05), palm: PalmOrientation(yaw: 80)),
    face: FaceExpression.neutral,
    body: BodyPose.rest,
  );

  static AvatarFrame lerp(AvatarFrame a, AvatarFrame b, double t) =>
      AvatarFrame(
        dominant: HandPose.lerp(a.dominant, b.dominant, t),
        passive: HandPose.lerp(a.passive, b.passive, t),
        face: FaceExpression.lerp(a.face, b.face, t),
        body: BodyPose.lerp(a.body, b.body, t),
        phase: t < 0.5 ? a.phase : b.phase,
      );
}

/// Descripción completa de cómo el avatar ejecuta una seña.
class SignAnimationModel {
  const SignAnimationModel({
    required this.signId,
    required this.duration,
    required this.keyframes,
    this.riveSignIndex,
    this.validatedByLspyExpert = false,
  });

  final String signId;
  final Duration duration;

  /// Keyframes en orden; el reposo inicial y final se agrega solo.
  final List<AvatarKeyframe> keyframes;

  /// Índice de la seña en el input `signIndex` del archivo Rive.
  final int? riveSignIndex;

  /// Riesgo R3 de la documentación: mientras sea false la UI lo advierte.
  final bool validatedByLspyExpert;

  /// Tiempos normalizados de los keyframes (para marcar la barra de progreso).
  List<double> get keyframeTimes => [for (final k in keyframes) k.at];

  /// Pose del avatar en el instante [t] (0-1). Siempre parte y vuelve al
  /// reposo, así no hay cortes al reproducir ni al repetir.
  AvatarFrame sample(double t) {
    t = t.clamp(0.0, 1.0);
    final frames = <(double, AvatarFrame, Curve)>[
      (0, AvatarFrame.rest, Curves.linear),
      for (final k in keyframes)
        (
          k.at,
          AvatarFrame(
            dominant: k.dominant,
            passive: k.passive ?? AvatarFrame.rest.passive,
            face: k.face,
            body: k.body,
            phase: k.phase ?? 'Movimiento',
          ),
          k.easing,
        ),
      (1, AvatarFrame.rest, Curves.easeInOutCubic),
    ];

    var i = 0;
    while (i < frames.length - 2 && t > frames[i + 1].$1) {
      i++;
    }
    final (t0, a, _) = frames[i];
    final (t1, b, curve) = frames[i + 1];
    final span = t1 - t0;
    final e =
        curve.transform(span <= 0 ? 1.0 : ((t - t0) / span).clamp(0.0, 1.0));

    Vec3 path(HandPose Function(AvatarFrame f) hand) {
      final p0 = hand(frames[i > 0 ? i - 1 : i].$2).wrist;
      final p1 = hand(a).wrist;
      final p2 = hand(b).wrist;
      final p3 = hand(frames[i + 2 < frames.length ? i + 2 : i + 1].$2).wrist;
      return _catmullRom(p0, p1, p2, p3, e);
    }

    final frame = AvatarFrame.lerp(a, b, e);
    return AvatarFrame(
      dominant: HandPose.lerp(a.dominant, b.dominant, e,
          wrist: path((f) => f.dominant)),
      passive:
          HandPose.lerp(a.passive, b.passive, e, wrist: path((f) => f.passive)),
      face: frame.face,
      body: frame.body,
      // El nombre de la fase cambia a mitad del tramo, no al empezarlo.
      phase: e < 0.5 ? a.phase : b.phase,
    );
  }

  /// Curva suave que pasa por p1 y p2. En una retención (p1 == p2) la mano
  /// queda quieta en lugar de derivar.
  static Vec3 _catmullRom(Vec3 p0, Vec3 p1, Vec3 p2, Vec3 p3, double t) {
    if (p1.distanceTo(p2) < 1e-4) return p1;
    final t2 = t * t, t3 = t2 * t;
    Vec3 term(Vec3 p, double c) => p * c;
    return term(p1, 2) * 0.5 +
        term(p2 - p0, t) * 0.5 +
        term(p0 * 2 - p1 * 5 + p2 * 4 - p3, t2) * 0.5 +
        term(p1 * 3 - p0 - p2 * 3 + p3, t3) * 0.5;
  }
}
