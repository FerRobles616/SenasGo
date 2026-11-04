import 'dart:math' as math;

import 'package:senasgo/core/vision/dynamic_threshold.dart';

/// Tolerancia dinámica (Confidence Threshold) según el nivel del usuario.
///
/// Un principiante tiene las manos más rígidas y menos control fino, así que
/// se le acepta un margen de error más amplio. Al subir de nivel cada
/// parámetro se vuelve más estricto.
class ToleranceProfile {
  const ToleranceProfile({
    required this.level,
    required this.minHandPresence,
    required this.minShapeScore,
    required this.palmToleranceDeg,
    required this.minPalmScore,
    required this.minMovementScore,
    required this.minShapeStability,
    required this.stableFramesRequired,
  });

  factory ToleranceProfile.forLevel(int level) {
    final l = level.clamp(1, 5);
    // Interpolación lineal entre principiante (1) y experto (5).
    final t = (l - 1) / 4;
    double lerp(double a, double b) => a + (b - a) * t;
    final palmDeg = lerp(65, 35);
    // La confianza de la forma usa la curva de la documentación v3_05:
    // 0.52 en nivel 1 y sube más despacio después del nivel 3.
    final shape = const DynamicConfidenceThreshold().forLevel(l);
    return ToleranceProfile(
      level: l,
      minHandPresence: lerp(0.50, 0.70),
      minShapeScore: shape,
      palmToleranceDeg: palmDeg,
      minPalmScore: (math.cos(palmDeg * math.pi / 180) + 1) / 2,
      minMovementScore: lerp(0.45, 0.75),
      minShapeStability: lerp(0.55, 0.80),
      stableFramesRequired: (2 + t * 3).round(),
    );
  }

  final int level;

  /// Confianza mínima del modelo de que hay una mano en el recuadro.
  final double minHandPresence;

  /// Puntaje mínimo de configuración manual (forma de la mano y dedos).
  final double minShapeScore;

  /// Desvío máximo aceptado en la orientación de la palma, en grados.
  final double palmToleranceDeg;

  /// Puntaje continuo mínimo de orientación de la palma (0-1).
  final double minPalmScore;

  /// Puntaje mínimo de similitud con el movimiento esperado.
  final double minMovementScore;

  /// Estabilidad mínima de la geometría entre fotogramas.
  final double minShapeStability;

  /// Fotogramas seguidos con mano visible antes de evaluar (evita parpadeos).
  final int stableFramesRequired;
}
