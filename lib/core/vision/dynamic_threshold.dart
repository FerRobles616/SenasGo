import 'package:senasgo/core/constants/app_constants.dart';

/// Umbral de confianza dinámico según el nivel de la persona.
///
/// Un principiante tiene más rigidez de muñeca y dedos, así que se le exige
/// menos precisión. El umbral sube con el nivel, pero nunca llega a valores
/// imposibles para una cámara de teléfono.
class DynamicConfidenceThreshold {
  const DynamicConfidenceThreshold();

  double forLevel(int level) {
    final l = level.clamp(1, 5);
    if (l <= AppConstants.beginnerLevelCap) {
      return 0.52 + (l - 1) * 0.04;
    }
    return (0.64 + (l - AppConstants.beginnerLevelCap) * 0.03)
        .clamp(0.64, 0.88);
  }
}
