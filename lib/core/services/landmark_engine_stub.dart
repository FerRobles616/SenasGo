import 'dart:typed_data';

import 'package:senasgo/core/services/landmark_engine.dart';
import 'package:senasgo/core/vision/hand_landmarks.dart';

/// Sin TensorFlow Lite en web: la app funciona en modo conceptual.
LandmarkEngine createLandmarkEngine() => _StubLandmarkEngine();

class _StubLandmarkEngine implements LandmarkEngine {
  @override
  int get inputSize => 224;

  @override
  Future<bool> load() async => false;

  @override
  Future<HandLandmarks?> detect(Float32List input) async => null;

  @override
  Future<double?> classify(List<double> features, String label) async => null;

  @override
  void dispose() {}
}
