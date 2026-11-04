import 'dart:math' as math;
import 'dart:typed_data';

/// Los 21 puntos de MediaPipe Hands, normalizados a [0,1] dentro del
/// recuadro guía (x a la derecha, y hacia abajo, z negativo = hacia la cámara).
///
/// Trabajar sobre landmarks (y no sobre píxeles) hace que anillos, relojes,
/// mangas largas o el color de piel no afecten la evaluación: solo cuenta la
/// geometría de las articulaciones.
class HandLandmarks {
  HandLandmarks({
    required this.points,
    required this.presence,
    required this.isRightHand,
    required this.timestamp,
  }) : assert(points.length == 63);

  /// x0, y0, z0, x1, y1, z1, ... (21 puntos).
  final Float32List points;

  /// Confianza del modelo de que hay una mano (0-1).
  final double presence;

  /// Lateralidad según MediaPipe (asume imagen espejada, como la nuestra).
  final bool isRightHand;

  final DateTime timestamp;

  static const int wrist = 0;
  static const int thumbIp = 3, thumbTip = 4;
  static const int indexMcp = 5, middleMcp = 9, pinkyMcp = 17;

  /// (PIP, TIP) de índice, medio, anular y meñique.
  static const List<(int, int)> _fingerJoints = [
    (6, 8),
    (10, 12),
    (14, 16),
    (18, 20)
  ];

  Vec3 point(int i) =>
      Vec3(points[i * 3], points[i * 3 + 1], points[i * 3 + 2]);

  /// Tamaño de la palma (muñeca -> nudillo medio); escala de referencia.
  double get palmSize => point(wrist).distanceTo(point(middleMcp));

  /// Grado de extensión de cada dedo (pulgar, índice, medio, anular, meñique)
  /// entre 0 (doblado) y 1 (extendido).
  List<double> get fingerExtension {
    final w = point(wrist);
    double soft(double ratio) =>
        ((ratio - 0.95) / (1.30 - 0.95)).clamp(0.0, 1.0);

    // Pulgar: punta más lejos del nudillo medio que la articulación IP.
    final m = point(middleMcp);
    final thumb = soft(point(thumbTip).distanceTo(m) /
        math.max(point(thumbIp).distanceTo(m), 1e-6));

    return [
      thumb,
      for (final (pip, tip) in _fingerJoints)
        soft(point(tip).distanceTo(w) /
            math.max(point(pip).distanceTo(w), 1e-6)),
    ];
  }

  /// Vector normal hacia afuera de la palma (unitario).
  Vec3 get palmNormal {
    final w = point(wrist);
    final a = point(indexMcp) - w;
    final b = point(pinkyMcp) - w;
    final n = a.cross(b).normalized();
    // En imagen espejada, la mano derecha da la normal hacia el dorso.
    return isRightHand ? -n : n;
  }

  /// Rasgos invariantes a posición y escala para el clasificador TFLite:
  /// puntos relativos a la muñeca divididos por el tamaño de la palma.
  Float32List toClassifierFeatures() {
    final w = point(wrist);
    final s = math.max(palmSize, 1e-6);
    final out = Float32List(63);
    for (var i = 0; i < 21; i++) {
      final p = point(i);
      out[i * 3] = (p.x - w.x) / s;
      out[i * 3 + 1] = (p.y - w.y) / s;
      out[i * 3 + 2] = (p.z - w.z) / s;
    }
    return out;
  }
}

class Vec3 {
  const Vec3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator -() => Vec3(-x, -y, -z);

  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;

  Vec3 cross(Vec3 o) =>
      Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);

  double get length => math.sqrt(dot(this));

  double distanceTo(Vec3 o) => (this - o).length;

  Vec3 normalized() {
    final l = length;
    return l < 1e-9 ? this : Vec3(x / l, y / l, z / l);
  }

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);

  static const Vec3 zero = Vec3(0, 0, 0);

  static Vec3 lerp(Vec3 a, Vec3 b, double t) =>
      Vec3(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t);
}
