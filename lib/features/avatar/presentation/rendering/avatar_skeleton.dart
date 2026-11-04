import 'dart:math' as math;

import 'package:senasgo/core/vision/hand_landmarks.dart';
import 'package:senasgo/features/avatar/domain/sign_animation_model.dart';

/// Geometría 3D de una mano: palma y cadenas de los 5 dedos.
class HandGeometry {
  const HandGeometry({
    required this.wrist,
    required this.palm,
    required this.fingers,
    required this.normal,
  });

  final Vec3 wrist;

  /// Contorno de la palma (muñeca, nudillos y base del pulgar).
  final List<Vec3> palm;

  /// Pulgar, índice, medio, anular y meñique: base + 3 articulaciones.
  final List<List<Vec3>> fingers;

  /// Normal hacia afuera de la palma.
  final Vec3 normal;
}

class ArmGeometry {
  const ArmGeometry({
    required this.shoulder,
    required this.elbow,
    required this.hand,
  });

  final Vec3 shoulder;
  final Vec3 elbow;
  final HandGeometry hand;
}

/// Esqueleto resuelto para un [AvatarFrame]: IK de dos huesos para los
/// brazos y cadenas articuladas para los dedos.
class AvatarSkeleton {
  const AvatarSkeleton({
    required this.dominant,
    required this.passive,
    required this.neck,
    required this.headCenter,
    required this.hips,
    required this.headPitch,
    required this.headYaw,
    required this.headRoll,
  });

  static const double upperArm = 0.27;
  static const double forearm = 0.25;
  static const double headRadius = 0.155;

  final ArmGeometry dominant;
  final ArmGeometry passive;
  final Vec3 neck;
  final Vec3 headCenter;

  /// Cadera izquierda y derecha (vista del estudiante).
  final (Vec3, Vec3) hips;

  /// Rotación de la cabeza en radianes.
  final double headPitch;
  final double headYaw;
  final double headRoll;

  factory AvatarSkeleton.solve(AvatarFrame f, {double breath = 0}) {
    final body = f.body;
    final lean = body.torsoLean * math.pi / 180;
    final shrug = body.shrug * 0.03;

    // El torso se inclina sobre la cadera; todo lo de arriba lo acompaña.
    const pivotY = -0.5;
    Vec3 leanPt(Vec3 p) {
      final y = p.y - pivotY;
      return Vec3(
        p.x,
        pivotY + y * math.cos(lean) - p.z * math.sin(lean),
        y * math.sin(lean) + p.z * math.cos(lean),
      );
    }

    final up = Vec3(0, breath, 0);
    final shoulderD = leanPt(Vec3(-0.19, shrug, 0) + up);
    final shoulderP = leanPt(Vec3(0.19, shrug, 0) + up);

    return AvatarSkeleton(
      dominant: _arm(shoulderD, leanPt(f.dominant.wrist), f.dominant,
          dominantHand: true),
      passive: _arm(shoulderP, leanPt(f.passive.wrist), f.passive,
          dominantHand: false),
      neck: leanPt(Vec3(0, 0.07, 0) + up),
      headCenter: leanPt(Vec3(0, 0.27, 0.01) + up),
      hips: (const Vec3(-0.15, -0.52, 0), const Vec3(0.15, -0.52, 0)),
      headPitch: body.headPitch * math.pi / 180 + lean,
      headYaw: body.headYaw * math.pi / 180,
      headRoll: body.headRoll * math.pi / 180,
    );
  }

  /// IK de dos huesos: el codo cae hacia afuera, abajo y atrás (natural).
  static ArmGeometry _arm(Vec3 shoulder, Vec3 target, HandPose pose,
      {required bool dominantHand}) {
    final toTarget = target - shoulder;
    final reach = toTarget.length.clamp(0.08, upperArm + forearm - 0.002);
    final dir = toTarget.normalized();
    final wrist = shoulder + dir * reach;

    final a =
        (upperArm * upperArm - forearm * forearm + reach * reach) / (2 * reach);
    final h = math.sqrt(math.max(0, upperArm * upperArm - a * a));
    final side = dominantHand ? -1.0 : 1.0;
    final pole = Vec3(side * 0.7, -1, -0.45).normalized();
    final perp = (pole - dir * pole.dot(dir)).normalized();
    final elbow = shoulder + dir * a + perp * h;

    return ArmGeometry(
      shoulder: shoulder,
      elbow: elbow,
      hand: _hand(wrist, pose, dominantHand: dominantHand),
    );
  }

  static HandGeometry _hand(Vec3 wrist, HandPose pose,
      {required bool dominantHand}) {
    // Base: dedos arriba, palma al estudiante, pulgar hacia el centro.
    var f = const Vec3(0, 1, 0);
    var n = const Vec3(0, 0, 1);
    var s = Vec3(dominantHand ? 1 : -1, 0, 0);

    final o = pose.palm;
    final yawSign = dominantHand ? 1.0 : -1.0;
    // Roll: en el plano de la palma.
    f = _rotate(f, n, o.roll * math.pi / 180 * yawSign);
    s = _rotate(s, n, o.roll * math.pi / 180 * yawSign);
    // Yaw: pronación / supinación alrededor del eje de los dedos.
    n = _rotate(n, f, o.yaw * math.pi / 180 * yawSign);
    s = _rotate(s, f, o.yaw * math.pi / 180 * yawSign);
    // Pitch: flexión de muñeca hacia el lado de la palma.
    final flexAxis = n.cross(f).normalized() * -1;
    f = _rotate(f, flexAxis, o.pitch * math.pi / 180);
    n = _rotate(n, flexAxis, o.pitch * math.pi / 180);

    final shape = pose.shape;
    const palmLength = 0.085;
    const knuckleOffsets = [0.027, 0.009, -0.009, -0.027];
    const fanAngles = [14.0, 4.0, -5.0, -15.0];
    const segments = [
      [0.042, 0.025, 0.020],
      [0.047, 0.028, 0.021],
      [0.044, 0.026, 0.020],
      [0.034, 0.020, 0.018],
    ];
    const jointBend = [80.0, 95.0, 70.0];

    List<Vec3> chain(Vec3 base, Vec3 dir, List<double> lengths, double curl) {
      final points = [base];
      var d = dir;
      var p = base;
      for (var j = 0; j < 3; j++) {
        // Doblar hacia el lado de la palma.
        d = _rotate(
            d, d.cross(n).normalized(), curl * jointBend[j] * math.pi / 180);
        p = p + d * lengths[j];
        points.add(p);
      }
      return points;
    }

    final fingers = <List<Vec3>>[];

    // Pulgar
    final thumbBase = wrist + f * 0.025 + s * 0.028 + n * 0.008;
    final thumbOut = (f * 0.55 + s * 0.8 + n * 0.25).normalized();
    final thumbIn = (f * 0.55 - s * 0.45 + n * 0.7).normalized();
    final thumbDir =
        Vec3.lerp(thumbOut, thumbIn, shape.thumbAcross).normalized();
    fingers.add(chain(
        thumbBase, thumbDir, const [0.035, 0.030, 0.024], shape.curl[0] * 0.6));

    final knuckles = <Vec3>[];
    for (var i = 0; i < 4; i++) {
      final knuckle = wrist + f * palmLength + s * knuckleOffsets[i];
      knuckles.add(knuckle);
      final fan = fanAngles[i] * shape.spread * math.pi / 180;
      final dir = _rotate(f, n, fan * (dominantHand ? -1 : 1));
      fingers.add(chain(knuckle, dir, segments[i], shape.curl[i + 1]));
    }

    return HandGeometry(
      wrist: wrist,
      palm: [
        wrist + s * 0.026,
        knuckles.first + s * 0.006,
        knuckles.last - s * 0.007,
        wrist - s * 0.03,
      ],
      fingers: fingers,
      normal: n,
    );
  }

  /// Rotación de Rodrigues de [v] alrededor del eje unitario [k].
  static Vec3 _rotate(Vec3 v, Vec3 k, double angle) {
    final c = math.cos(angle), sn = math.sin(angle);
    return v * c + k.cross(v) * sn + k * (k.dot(v) * (1 - c));
  }

  /// Punto relativo al centro de la cabeza (metros), rotado con ella.
  Vec3 headPoint(Vec3 local) {
    var p = local;
    p = _rotate(p, const Vec3(0, 0, 1), -headRoll);
    p = _rotate(p, const Vec3(1, 0, 0), headPitch);
    p = _rotate(p, const Vec3(0, 1, 0), headYaw);
    return headCenter + p;
  }

  /// Punto sobre la superficie de la cabeza: [u] horizontal, [v] vertical
  /// (-1..1) en la cara, ya rotado con la cabeza.
  Vec3 facePoint(double u, double v, {double out = 1}) {
    final z = math.sqrt(math.max(0.0, 1 - u * u - v * v));
    var p = Vec3(u, v, z) * (headRadius * out);
    p = _rotate(p, const Vec3(0, 0, 1), -headRoll);
    p = _rotate(p, const Vec3(1, 0, 0), headPitch);
    p = _rotate(p, const Vec3(0, 1, 0), headYaw);
    return headCenter + p;
  }
}
