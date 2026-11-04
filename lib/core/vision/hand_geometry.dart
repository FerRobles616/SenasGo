import 'dart:math' as math;

import 'package:senasgo/core/vision/hand_landmarks.dart';

/// Geometría de la mano a partir de los 21 landmarks.
///
/// Compara posiciones relativas a la muñeca y escala de la palma, no píxeles
/// ni color de piel: anillos, relojes o mangas no cambian el resultado.
class HandGeometry {
  const HandGeometry();

  /// Vector de 63 valores invariante a posición y escala.
  List<double> embedding(HandLandmarks hand) => hand.toClassifierFeatures();

  /// Similitud coseno normalizada a [0,1] (1 = misma dirección).
  double cosine(List<double> a, List<double> b) {
    final n = math.min(a.length, b.length);
    var dot = 0.0, na = 0.0, nb = 0.0;
    for (var i = 0; i < n; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    final d = math.sqrt(na) * math.sqrt(nb);
    if (d < 1e-8) return 0;
    return ((dot / d) + 1) / 2;
  }

  /// 0 = dorso hacia la cámara; 1 = palma hacia la cámara.
  double palmFacingScore(HandLandmarks hand) {
    final n = hand.palmNormal;
    return ((-n.z) + 1) / 2;
  }

  /// Estabilidad de la forma de la mano en la ventana de evaluación.
  /// 1 = todos los fotogramas tienen la misma geometría.
  double shapeStability(List<HandLandmarks> frames) {
    if (frames.length < 2) return 1;
    final reference = embedding(frames.last);
    var sum = 0.0;
    for (var i = 0; i < frames.length - 1; i++) {
      sum += cosine(embedding(frames[i]), reference);
    }
    return (sum / (frames.length - 1)).clamp(0.0, 1.0);
  }

  /// 1 = muñeca en el centro del recuadro; 0 = en el borde.
  /// Es un proxy de encuadre hasta integrar detección de rostro/cuerpo.
  double framingScore(HandLandmarks hand, {double cx = 0.5, double cy = 0.5}) {
    final w = hand.point(HandLandmarks.wrist);
    final dx = w.x - cx;
    final dy = w.y - cy;
    final dist = math.sqrt(dx * dx + dy * dy);
    return (1 - dist * 2).clamp(0.0, 1.0);
  }
}
