import 'dart:math' as math;

/// Tolerancia según el nivel de la persona.
///
/// Un principiante tiene las manos más rígidas y menos control fino, así que
/// se le acepta un margen más amplio. Al subir de nivel cada parámetro se
/// vuelve más estricto, sin llegar a valores imposibles para una cámara de
/// teléfono. Los valores de nivel 1 y 5 están calibrados con video real y
/// con el esqueleto del profesor (test/sign_detection_test.dart).
class ToleranceProfile {
  const ToleranceProfile({
    required this.level,
    required this.minHandPresence,
    required this.minShapeScore,
    required this.palmToleranceDeg,
    required this.minPalmScore,
    required this.minPlaceFraction,
    required this.movementSlack,
    required this.stableFramesRequired,
  });

  factory ToleranceProfile.forLevel(int level) {
    final l = level.clamp(1, 5);
    final t = (l - 1) / 4; // 0 = principiante, 1 = experto
    double lerp(double a, double b) => a + (b - a) * t;
    final palmDeg = lerp(55, 45);
    return ToleranceProfile(
      level: l,
      minHandPresence: lerp(0.50, 0.65),
      minShapeScore: lerp(0.70, 0.82),
      palmToleranceDeg: palmDeg,
      minPalmScore: (math.cos(palmDeg * math.pi / 180) + 1) / 2,
      minPlaceFraction: lerp(0.35, 0.55),
      movementSlack: lerp(1.25, 1.0),
      stableFramesRequired: (3 + t * 2).round(),
    );
  }

  final int level;

  /// Confianza mínima del detector de que hay una mano.
  final double minHandPresence;

  /// Puntaje mínimo de configuración manual (forma de los dedos), 0-1.
  final double minShapeScore;

  /// Desvío máximo aceptado en la orientación de la palma, en grados.
  final double palmToleranceDeg;

  /// Puntaje continuo mínimo de orientación de la palma (0-1).
  final double minPalmScore;

  /// Fracción mínima de cuadros con la mano en el lugar de la seña.
  final double minPlaceFraction;

  /// Holgura del movimiento: >1 acepta movimientos más chicos o menos
  /// precisos (principiantes).
  final double movementSlack;

  /// Cuadros seguidos con la mano visible antes de empezar a evaluar.
  final int stableFramesRequired;
}
