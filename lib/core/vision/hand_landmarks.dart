import 'dart:math' as math;
import 'dart:typed_data';

/// Los 21 puntos de una mano según MediaPipe Hand Landmarker.
///
/// - [points]: en la imagen (espejada, como la vista previa), x e y en [0,1]
///   (x a la derecha, y hacia abajo); z relativo a la muñeca.
/// - [world]: los mismos puntos en 3D, en metros, centrados en la mano y con
///   los mismos ejes (z negativo = hacia la cámara). Son la base de la forma
///   de la mano y de la orientación de la palma: no dependen de la distancia a
///   la cámara ni de cómo se inclina la mano en la imagen.
///
/// Trabajar sobre puntos (y no sobre píxeles) hace que anillos, relojes,
/// mangas largas o el color de piel no afecten la evaluación.
class HandLandmarks {
  HandLandmarks({
    required this.points,
    Float32List? world,
    required this.presence,
    required this.isRightHand,
    required this.timestamp,
  })  : world = world ?? points,
        assert(points.length == 63);

  /// x0, y0, z0, x1, y1, z1, ... (21 puntos) en la imagen.
  final Float32List points;

  /// Puntos 3D en metros (si el detector no los da, se usan los de imagen).
  final Float32List world;

  /// Confianza del detector en la mano y su lateralidad (0-1).
  final double presence;

  /// Mano derecha real de la persona.
  final bool isRightHand;

  final DateTime timestamp;

  static const int wrist = 0;
  static const int thumbIp = 3, thumbTip = 4;
  static const int indexMcp = 5, middleMcp = 9, ringMcp = 13, pinkyMcp = 17;
  static const int indexTip = 8, middleTip = 12;

  /// (MCP, PIP, DIP, TIP) de índice, medio, anular y meñique.
  static const List<List<int>> fingerChains = [
    [5, 6, 7, 8],
    [9, 10, 11, 12],
    [13, 14, 15, 16],
    [17, 18, 19, 20],
  ];

  /// Punto en la imagen.
  Vec3 point(int i) =>
      Vec3(points[i * 3], points[i * 3 + 1], points[i * 3 + 2]);

  /// Punto en 3D (metros).
  Vec3 worldPoint(int i) =>
      Vec3(world[i * 3], world[i * 3 + 1], world[i * 3 + 2]);

  /// Tamaño de la palma en la imagen (muñeca -> nudillo medio).
  double get palmSize => point(wrist).distanceTo(point(middleMcp));

  /// Centro de la palma en la imagen.
  Vec3 get palmCenter {
    final a = point(wrist), b = point(indexMcp);
    final c = point(middleMcp), d = point(pinkyMcp);
    return Vec3((a.x + b.x + c.x + d.x) / 4, (a.y + b.y + c.y + d.y) / 4, 0);
  }

  /// Qué tan recto está cada dedo (índice, medio, anular, meñique):
  /// distancia nudillo-punta dividida por el largo del dedo. ~1 = recto,
  /// ~0.4 = doblado contra la palma. Se mide en 3D.
  List<double> get fingerStraightness => [
        for (final c in fingerChains)
          _straightness(worldPoint(c[0]), worldPoint(c[1]), worldPoint(c[2]),
              worldPoint(c[3])),
      ];

  static double _straightness(Vec3 mcp, Vec3 pip, Vec3 dip, Vec3 tip) {
    final length =
        mcp.distanceTo(pip) + pip.distanceTo(dip) + dip.distanceTo(tip);
    return length < 1e-9 ? 0 : mcp.distanceTo(tip) / length;
  }

  /// Rectitud por debajo de la cual el dedo cuenta como doblado y por encima
  /// de la cual cuenta como extendido. Calibrado con video real y con el
  /// esqueleto del profesor (extendido 0.93-1.0; doblado 0.36-0.65).
  static const double curledBelow = 0.66, extendedAbove = 0.86;

  /// Grado de extensión de cada dedo (pulgar, índice, medio, anular, meñique)
  /// entre 0 (doblado) y 1 (extendido).
  List<double> get fingerExtension {
    double map(double s) =>
        ((s - curledBelow) / (extendedAbove - curledBelow)).clamp(0.0, 1.0);

    // Pulgar: punta separada del nudillo del índice, relativo al ancho de la
    // palma. Es el dedo menos confiable; ninguna seña lo exige hoy.
    final width = worldPoint(indexMcp).distanceTo(worldPoint(pinkyMcp));
    final thumb = width < 1e-9
        ? 0.0
        : ((worldPoint(thumbTip).distanceTo(worldPoint(indexMcp)) / width -
                    0.55) /
                0.35)
            .clamp(0.0, 1.0);
    return [thumb, for (final s in fingerStraightness) map(s)];
  }

  /// Vector normal a la palma, hacia el lado de la palma (unitario, en 3D).
  /// z negativo = la palma mira a la cámara.
  Vec3 get palmNormal {
    final w = worldPoint(wrist);
    final a = worldPoint(indexMcp) - w;
    final b = worldPoint(pinkyMcp) - w;
    final n = a.cross(b).normalized();
    // Calibrado con video real: para la mano derecha la normal geométrica
    // apunta al dorso.
    return isRightHand ? -n : n;
  }

  /// Rasgos invariantes a posición y escala: puntos relativos a la muñeca
  /// divididos por el tamaño de la palma.
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
