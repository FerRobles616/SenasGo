import 'dart:typed_data';

import 'package:senasgo/core/vision/hand_landmarks.dart';

/// Contrato del motor de landmarks de mano.
///
/// La implementación real usa TensorFlow Lite (solo móvil/escritorio). En web
/// se usa un stub que devuelve `false` y la app cae al modo conceptual.
abstract class LandmarkEngine {
  /// Tamaño de entrada del modelo (224 por defecto).
  int get inputSize;

  /// Carga los modelos locales. Devuelve true si el motor Edge AI está listo.
  Future<bool> load();

  /// Detecta la mano en la entrada normalizada del modelo.
  Future<HandLandmarks?> detect(Float32List input);

  /// Puntaje del clasificador para [label], o null si no está disponible.
  Future<double?> classify(List<double> features, String label);

  void dispose();
}
