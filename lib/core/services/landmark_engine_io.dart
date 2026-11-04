import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:senasgo/core/constants/app_constants.dart';
import 'package:senasgo/core/services/landmark_engine.dart';
import 'package:senasgo/core/vision/hand_landmarks.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

LandmarkEngine createLandmarkEngine() => TfliteLandmarkEngine();

/// Motor real: MediaPipe Hands (.tflite) + clasificador opcional.
class TfliteLandmarkEngine implements LandmarkEngine {
  final Logger _logger = Logger();

  Interpreter? _landmarkModel;
  IsolateInterpreter? _landmarkIsolate;
  int _inputSize = 224;
  int _landmarksOut = 0, _presenceOut = 1, _handednessOut = 2;
  List<int> _outputSizes = const [];

  Interpreter? _classifier;
  List<String> _labels = const [];

  @override
  int get inputSize => _inputSize;

  @override
  Future<bool> load() async {
    try {
      final model = await Interpreter.fromAsset(
        AppConstants.handLandmarkModel,
        options: InterpreterOptions()..threads = 2,
      );
      _configureLandmarkOutputs(model);
      _landmarkModel = model;
      _landmarkIsolate =
          await IsolateInterpreter.create(address: model.address);
    } catch (e) {
      _logger.w('Sin modelo de landmarks ($e). Modo conceptual activo.');
      return false;
    }

    try {
      _classifier =
          await Interpreter.fromAsset(AppConstants.signClassifierModel);
      final raw =
          await rootBundle.loadString(AppConstants.signClassifierLabels);
      _labels = raw
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
    } catch (_) {
      // Opcional: sin clasificador se usa la plantilla de dedos.
      _classifier = null;
    }
    return true;
  }

  /// Ubica las salidas del modelo de MediaPipe por forma y nombre:
  /// 63 valores = landmarks (el primero por nombre es el de pantalla),
  /// 1 valor = presencia de mano y lateralidad (en ese orden).
  void _configureLandmarkOutputs(Interpreter model) {
    final input = model.getInputTensor(0);
    if (input.type != TensorType.float32 || input.shape.length != 4) {
      throw UnsupportedError(
          'Entrada no soportada: ${input.shape} ${input.type}');
    }
    _inputSize = input.shape[1];

    final outputs = model.getOutputTensors();
    _outputSizes = [for (final t in outputs) t.numElements()];
    final idx = List.generate(outputs.length, (i) => i)
      ..sort((a, b) => outputs[a].name.compareTo(outputs[b].name));
    final big = idx.where((i) => _outputSizes[i] == 63).toList();
    final single = idx.where((i) => _outputSizes[i] == 1).toList();
    if (big.isEmpty || single.isEmpty) {
      throw UnsupportedError('Salidas no reconocidas: $_outputSizes');
    }
    _landmarksOut = big.first;
    _presenceOut = single.first;
    _handednessOut = single.length > 1 ? single[1] : -1;
  }

  @override
  Future<HandLandmarks?> detect(Float32List input) async {
    final isolate = _landmarkIsolate;
    if (isolate == null) return null;

    final outputs = <int, Object>{
      for (var i = 0; i < _outputSizes.length; i++)
        i: Float32List(_outputSizes[i]).buffer,
    };
    await isolate.runForMultipleInputs([input.buffer.asUint8List()], outputs);

    final raw = (outputs[_landmarksOut]! as ByteBuffer).asFloat32List();
    double scalar(int i) =>
        i < 0 ? 0.5 : (outputs[i]! as ByteBuffer).asFloat32List()[0];
    double sigmoid(double x) => 1 / (1 + exp(-x));

    final points = Float32List(63);
    for (var i = 0; i < 63; i++) {
      points[i] = raw[i] / _inputSize;
    }
    return HandLandmarks(
      points: points,
      presence: sigmoid(scalar(_presenceOut)),
      isRightHand: sigmoid(scalar(_handednessOut)) > 0.5,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<double?> classify(List<double> features, String label) async {
    final model = _classifier;
    if (model == null) return null;
    final index = _labels.indexOf(label);
    if (index < 0) return null;
    try {
      final out = [List<double>.filled(_labels.length, 0)];
      model.run([features], out);
      final scores = out.first;
      final sum = scores.fold<double>(0, (a, b) => a + b);
      if ((sum - 1).abs() < 0.05) return scores[index];
      // Logits: aplicar softmax.
      final m = scores.reduce(max);
      final e = [for (final s in scores) exp(s - m)];
      return e[index] / e.reduce((a, b) => a + b);
    } catch (e) {
      _logger.e('Error en clasificador: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _landmarkIsolate?.close();
    _landmarkModel?.close();
    _classifier?.close();
  }
}
