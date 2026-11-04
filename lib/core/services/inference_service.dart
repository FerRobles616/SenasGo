import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:senasgo/core/constants/app_constants.dart';
import 'package:senasgo/core/services/landmark_engine.dart';
import 'package:senasgo/core/services/landmark_engine_stub.dart'
    if (dart.library.io) 'package:senasgo/core/services/landmark_engine_io.dart'
    as engine;
import 'package:senasgo/core/vision/frame_processor.dart';
import 'package:senasgo/core/vision/hand_landmarks.dart';
import 'package:senasgo/core/vision/sign_evaluator.dart';
import 'package:senasgo/core/vision/tolerance_profile.dart';
import 'package:senasgo/features/practice/domain/sign_evaluation.dart';
import 'package:senasgo/features/practice/domain/sign_reference.dart';

/// edgeAi: MediaPipe Hands (.tflite) real en el dispositivo.
/// conceptual: sin modelos en assets/models/ -> reconocimiento simulado,
/// tal como define el alcance de la documentación v3_04.
enum EngineMode { edgeAi, conceptual }

class FrameAnalysis {
  const FrameAnalysis(
      {required this.lighting, required this.handVisible, this.hand});

  final LightingStatus lighting;
  final bool handVisible;
  final HandLandmarks? hand;
}

/// Motor de inferencia local (Edge AI). Nada sale del teléfono.
class InferenceService extends ChangeNotifier {
  final Logger _logger = Logger();
  final Random _random = Random();
  final SignEvaluator _evaluator = const SignEvaluator();
  final LandmarkEngine _engine = engine.createLandmarkEngine();

  bool _loaded = false;
  bool _busy = false;
  EngineMode _mode = EngineMode.conceptual;

  // Simulación del modo conceptual (se sortea una vez por intento).
  bool _simHandVisible = true;
  bool _simCorrect = true;
  int _simFrames = 0;

  EngineMode get mode => _mode;
  bool get isLoaded => _loaded;

  Future<void> loadModels() async {
    if (_loaded) return;
    _loaded = true;
    final edge = await _engine.load();
    _mode = edge ? EngineMode.edgeAi : EngineMode.conceptual;
    if (!edge) {
      _logger.w('Sin modelo de landmarks. Modo conceptual activo.');
    }
    notifyListeners();
  }

  /// Sortea el resultado simulado de un nuevo intento (modo conceptual).
  void beginAttempt(int userLevel) {
    _simFrames = 0;
    _simHandVisible = _random.nextDouble() < 0.85;
    // Principiantes: más probabilidad de acierto (tolerancia más amplia).
    _simCorrect = _random.nextDouble() < (0.75 - (userLevel - 1) * 0.05);
  }

  /// Analiza un fotograma. Devuelve null si se descartó porque el anterior
  /// todavía se está procesando (control térmico adicional al límite de FPS).
  Future<FrameAnalysis?> analyzeFrame(
    CameraImage image, {
    required int rotationDeg,
    required bool mirror,
    required ToleranceProfile tolerance,
  }) async {
    if (_busy) return null;
    _busy = true;
    try {
      final edge = _mode == EngineMode.edgeAi;
      final request = FrameRequest(
        FrameData.fromCameraImage(image,
            rotationDeg: rotationDeg, mirror: mirror),
        inputSize: edge ? _engine.inputSize : null,
      );
      // compute() con función top-level: no captura `this` (no enviable).
      final processed = await compute(processFrame, request);

      if (processed.lighting != LightingStatus.ok) {
        return FrameAnalysis(lighting: processed.lighting, handVisible: false);
      }
      if (!edge) {
        _simFrames++;
        // La mano "aparece" tras ~1 s de captura si el sorteo lo permite.
        final visible =
            _simHandVisible && _simFrames > AppConstants.targetFpsMin;
        return FrameAnalysis(lighting: LightingStatus.ok, handVisible: visible);
      }

      final hand = await _engine.detect(processed.modelInput!);
      final visible =
          hand != null && hand.presence >= tolerance.minHandPresence;
      return FrameAnalysis(
        lighting: LightingStatus.ok,
        handVisible: visible,
        hand: visible ? hand : null,
      );
    } catch (e) {
      _logger.e('Error analizando fotograma: $e');
      return null;
    } finally {
      _busy = false;
    }
  }

  /// Evalúa los fotogramas capturados contra la seña objetivo.
  Future<SignEvaluation> evaluate({
    required List<HandLandmarks> frames,
    required String signId,
    required String? classifierLabel,
    required ToleranceProfile tolerance,
  }) async {
    final reference = SignReference.of(signId);

    if (_mode == EngineMode.conceptual || frames.isEmpty) {
      const simulated = ParameterResult(ParameterStatus.notEvaluated,
          hint: 'Evaluación simulada.');
      return SignEvaluation({
        for (final p in SignParameter.values) p: simulated,
        if (!_simCorrect)
          SignParameter.manualConfig: const ParameterResult(
            ParameterStatus.failed,
            hint:
                'Vuelve a observar la guía con calma y mantén la mano visible.',
          ),
      });
    }

    double? classifierScore;
    if (classifierLabel != null) {
      classifierScore = await _engine.classify(
        frames.last.toClassifierFeatures(),
        classifierLabel,
      );
    }

    return _evaluator.evaluate(
      frames: frames,
      reference: reference,
      tolerance: tolerance,
      classifierScore: classifierScore,
    );
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }
}
