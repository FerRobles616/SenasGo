import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:senasgo/core/constants/app_constants.dart';
import 'package:senasgo/core/services/landmark_engine.dart';
import 'package:senasgo/core/vision/frame_processor.dart';
import 'package:senasgo/core/vision/sign_evaluator.dart';
import 'package:senasgo/core/vision/tolerance_profile.dart';
import 'package:senasgo/core/vision/vision_frame.dart';
import 'package:senasgo/features/practice/domain/sign_evaluation.dart';
import 'package:senasgo/features/practice/domain/sign_reference.dart';

/// edgeAi: MediaPipe (manos + cuerpo) real en el dispositivo.
/// conceptual: sin detector disponible -> reconocimiento simulado, tal como
/// define el alcance de la documentación v3_04.
enum EngineMode { edgeAi, conceptual }

class FrameAnalysis {
  const FrameAnalysis({
    required this.lighting,
    required this.handVisible,
    this.bodyVisible = false,
    this.frame,
  });

  final LightingStatus lighting;
  final bool handVisible;

  /// Se ven la cara y los hombros (necesario para evaluar el lugar).
  final bool bodyVisible;
  final VisionFrame? frame;
}

/// Motor de inferencia local (Edge AI). Nada sale del teléfono.
class InferenceService extends ChangeNotifier {
  InferenceService({LandmarkEngine? engine})
      : _engine = engine ?? MediaPipeLandmarkEngine();

  /// Lado mayor de la imagen que recibe MediaPipe: suficiente para ver los
  /// dedos con la persona a medio cuerpo, sin calentar el teléfono.
  static const int detectorMaxSide = 512;

  final Logger _logger = Logger();
  final Random _random = Random();
  final SignEvaluator _evaluator = const SignEvaluator();
  final LandmarkEngine _engine;

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
    if (!edge) _logger.w('Sin detector de manos. Modo conceptual activo.');
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
      final timestamp = DateTime.now();
      final edge = _mode == EngineMode.edgeAi;
      final request = FrameRequest(
        FrameData.fromCameraImage(image,
            rotationDeg: rotationDeg, mirror: mirror),
        maxSide: edge ? detectorMaxSide : null,
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
        return FrameAnalysis(
            lighting: LightingStatus.ok, handVisible: visible);
      }

      final raw = await _engine.detect(
        processed.rgba!,
        width: processed.width,
        height: processed.height,
        timestamp: timestamp,
      );
      if (raw == null) {
        return const FrameAnalysis(
            lighting: LightingStatus.ok, handVisible: false);
      }
      final frame = VisionFrame(
        hands: [
          for (final h in raw.hands)
            if (h.presence >= tolerance.minHandPresence) h
        ],
        body: raw.body,
        aspect: raw.aspect,
        timestamp: raw.timestamp,
      );
      return FrameAnalysis(
        lighting: LightingStatus.ok,
        handVisible: frame.hands.isNotEmpty,
        bodyVisible: frame.shoulderWidth != null,
        frame: frame,
      );
    } catch (e) {
      _logger.e('Error analizando fotograma: $e');
      return null;
    } finally {
      _busy = false;
    }
  }

  /// Evalúa los fotogramas capturados contra la seña objetivo.
  SignEvaluation evaluate({
    required List<VisionFrame> frames,
    required String signId,
    required ToleranceProfile tolerance,
  }) {
    if (_mode == EngineMode.conceptual) {
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
    return _evaluator.evaluateBest(
      frames: frames,
      reference: SignReference.of(signId),
      tolerance: tolerance,
    );
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }
}
