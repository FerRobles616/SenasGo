import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:senasgo/core/vision/hand_landmarks.dart';

/// Puntos del cuerpo (MediaPipe Pose, 33 puntos: x, y, z, visibilidad).
///
/// Se usan para el "lugar" de la seña: cara, mentón, pecho, costado de la
/// cabeza. Las coordenadas están en la imagen espejada, en [0,1].
class BodyLandmarks {
  BodyLandmarks(this.data) : assert(data.length >= 33 * 4);

  final Float32List data;

  static const int nose = 0, leftEye = 2, rightEye = 5;
  static const int mouthLeft = 9, mouthRight = 10;
  static const int leftShoulder = 11, rightShoulder = 12;

  Vec3 point(int i) => Vec3(data[i * 4], data[i * 4 + 1], 0);
  double visibility(int i) => data[i * 4 + 3];

  /// Hay cara y hombros a la vista (lo mínimo para evaluar el lugar).
  bool get hasUpperBody =>
      visibility(nose) > 0.5 &&
      visibility(leftShoulder) > 0.5 &&
      visibility(rightShoulder) > 0.5;
}

/// Un cuadro analizado: manos detectadas y cuerpo, con la proporción de la
/// imagen para medir distancias reales (x e y en la misma escala).
class VisionFrame {
  VisionFrame({
    required this.hands,
    required this.body,
    required this.aspect,
    required this.timestamp,
  });

  final List<HandLandmarks> hands;
  final BodyLandmarks? body;

  /// Ancho / alto de la imagen analizada.
  final double aspect;
  final DateTime timestamp;

  /// La mano que hace la seña: la más alta (la otra suele quedar abajo).
  /// Con las dos a la misma altura, se prefiere la derecha.
  HandLandmarks? get activeHand {
    if (hands.isEmpty) return null;
    HandLandmarks? best;
    var bestY = double.infinity;
    for (final h in hands) {
      final y = h.point(HandLandmarks.middleMcp).y -
          (h.isRightHand ? 0.02 : 0.0); // leve preferencia por la derecha
      if (y < bestY) {
        bestY = y;
        best = h;
      }
    }
    return best;
  }

  /// Convierte un punto de la imagen a unidades de "ancho de hombros",
  /// relativo a un origen. Null si no hay cuerpo visible.
  Vec3? toBodyUnits(Vec3 p, Vec3 origin) {
    final s = shoulderWidth;
    if (s == null) return null;
    return Vec3((p.x - origin.x) * aspect / s, (p.y - origin.y) / s, 0);
  }

  /// Ancho de hombros en unidades de alto de imagen.
  double? get shoulderWidth {
    final b = body;
    if (b == null || !b.hasUpperBody) return null;
    final l = b.point(BodyLandmarks.leftShoulder);
    final r = b.point(BodyLandmarks.rightShoulder);
    final dx = (l.x - r.x) * aspect, dy = l.y - r.y;
    final w = math.sqrt(dx * dx + dy * dy);
    return w < 1e-4 ? null : w;
  }

  /// Desde el mapa que devuelve el canal nativo `senasgo/vision` (y las
  /// pruebas, con el mismo formato).
  factory VisionFrame.fromMap(
    Map<dynamic, dynamic> map, {
    required double aspect,
    required DateTime timestamp,
  }) {
    Float32List floats(Object? list) => Float32List.fromList([
          for (final v in (list as List? ?? const [])) (v as num).toDouble()
        ]);
    final hands = <HandLandmarks>[];
    for (final h in (map['hands'] as List? ?? const [])) {
      final m = h as Map;
      final points = floats(m['points']);
      if (points.length != 63) continue;
      final world = floats(m['world']);
      hands.add(HandLandmarks(
        points: points,
        world: world.length == 63 ? world : null,
        presence: (m['score'] as num?)?.toDouble() ?? 0,
        isRightHand: m['right'] == true,
        timestamp: timestamp,
      ));
    }
    final pose = floats(map['pose']);
    return VisionFrame(
      hands: hands,
      body: pose.length >= 33 * 4 ? BodyLandmarks(pose) : null,
      aspect: aspect,
      timestamp: timestamp,
    );
  }

  /// Carga una grabación de puntos (formato de tool/vision/*.py).
  static List<VisionFrame> listFromJson(String source) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    final aspect = (data['aspect'] as num?)?.toDouble() ?? 0.75;
    final start = DateTime(2026);
    return [
      for (final f in data['frames'] as List)
        VisionFrame.fromMap(
          f as Map,
          aspect: aspect,
          timestamp:
              start.add(Duration(milliseconds: (f['t'] as num).toInt())),
        ),
    ];
  }
}
