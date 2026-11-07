import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:senasgo/core/constants/app_constants.dart';
import 'package:senasgo/core/services/camera_service.dart';
import 'package:senasgo/core/services/device_performance.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/core/services/inference_service.dart';
import 'package:senasgo/core/vision/frame_processor.dart';
import 'package:senasgo/core/vision/hand_landmarks.dart';
import 'package:senasgo/core/vision/tolerance_profile.dart';
import 'package:senasgo/features/practice/domain/sign_evaluation.dart';
import 'package:senasgo/shared/models/sign_model.dart';
import 'package:senasgo/shared/models/user_model.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Estados del módulo de práctica (Diagrama de 11 estados, documentación v3_04).
/// El estado 1 (Selección de seña) vive en la pantalla de lección; los
/// estados 5 y 8 son decisiones internas del controlador.
enum PracticeStage {
  loading,
  demonstration, // 2. Demostración
  framing, // 3. Preparación de encuadre (obligatoria antes de capturar)
  capturing, // 4. Captura -> 5. ¿Mano detectada?
  handNotDetected, // 6. Feedback de reintento si no detecta
  environmentIssue, // Contingencia: contraluz / ambiente oscuro
  evaluating, // 7. Evaluación de ejecución -> 8. ¿Gesto correcto?
  incorrect, // 9. Feedback incorrecto
  correct, // 10. Feedback correcto (+10 XP)
  lessonSummary, // 11. Actualización de progreso y cierre de lección
  cameraUnavailable, // Contingencia: permiso denegado / sensor ocupado
}

@immutable
class PracticeState {
  const PracticeState({
    this.stage = PracticeStage.loading,
    this.signs = const [],
    this.index = 0,
    this.completedIds = const {},
    this.sessionXp = 0,
    this.combo = 0,
    this.lighting = LightingStatus.ok,
    this.handVisible = false,
    this.cameraIssue = CameraIssue.none,
    this.evaluation,
    this.mode = EngineMode.conceptual,
    this.user,
  });

  final PracticeStage stage;
  final List<SignModel> signs;
  final int index;
  final Set<String> completedIds;
  final int sessionXp;

  /// Aciertos seguidos en esta sesión; un error lo vuelve a 0.
  final int combo;
  final LightingStatus lighting;
  final bool handVisible;
  final CameraIssue cameraIssue;
  final SignEvaluation? evaluation;
  final EngineMode mode;
  final UserModel? user;

  SignModel? get currentSign => signs.isEmpty ? null : signs[index];
  int get completedCount => completedIds.length;
  int get totalSigns => signs.length;
  bool get isLastPending => completedCount >= totalSigns;

  /// La cámara se muestra en vivo en estos estados.
  bool get showsCamera =>
      stage == PracticeStage.framing ||
      stage == PracticeStage.capturing ||
      stage == PracticeStage.evaluating;

  PracticeState copyWith({
    PracticeStage? stage,
    List<SignModel>? signs,
    int? index,
    Set<String>? completedIds,
    int? sessionXp,
    int? combo,
    LightingStatus? lighting,
    bool? handVisible,
    CameraIssue? cameraIssue,
    SignEvaluation? evaluation,
    EngineMode? mode,
    UserModel? user,
  }) {
    return PracticeState(
      stage: stage ?? this.stage,
      signs: signs ?? this.signs,
      index: index ?? this.index,
      completedIds: completedIds ?? this.completedIds,
      sessionXp: sessionXp ?? this.sessionXp,
      combo: combo ?? this.combo,
      lighting: lighting ?? this.lighting,
      handVisible: handVisible ?? this.handVisible,
      cameraIssue: cameraIssue ?? this.cameraIssue,
      evaluation: evaluation ?? this.evaluation,
      mode: mode ?? this.mode,
      user: user ?? this.user,
    );
  }
}

/// ViewModel de la pantalla de práctica (MVVM).
class PracticeController extends ChangeNotifier {
  PracticeController(
      {required this.cameraService, required this.inferenceService});

  final CameraService cameraService;
  final InferenceService inferenceService;

  PracticeState _state = const PracticeState();
  PracticeState get state => _state;

  String? _lessonId;
  ToleranceProfile _tolerance = ToleranceProfile.forLevel(1);

  // Buffers del intento actual
  int _attempt = 0;
  DateTime _captureStart = DateTime.now();
  DateTime _evalStart = DateTime.now();
  int _stableFrames = 0;
  int _missedFrames = 0;
  int _badLightFrames = 0;
  final List<HandLandmarks> _window = [];
  bool _disposed = false;

  void _emit(PracticeState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  // ───────────────────────── Ciclo de la lección ─────────────────────────

  /// Carga la lección y abre la demostración de la primera seña pendiente.
  Future<void> startLesson(String? lessonId, {String? startSignId}) async {
    _lessonId = lessonId;
    var signs =
        lessonId == null ? <SignModel>[] : HiveService.signsOf(lessonId);
    if (signs.isEmpty) signs = HiveService.vocabularyBox.values.toList();

    final user = HiveService.currentUser;
    _tolerance = ToleranceProfile.forLevel(user.level);
    await inferenceService.loadModels();

    final start = signs.indexWhere((s) => s.id == startSignId);
    // Las señas ya aprendidas cuentan como completadas en esta sesión.
    final learned = HiveService.learnedSignIds;
    _emit(_state.copyWith(
      stage: PracticeStage.demonstration,
      signs: signs,
      index: start < 0 ? 0 : start,
      completedIds: {
        for (final s in signs)
          if (learned.contains(s.id) && s.id != startSignId) s.id
      },
      user: user,
      mode: inferenceService.mode,
    ));
  }

  /// 2 -> 3: [PRACTICAR] abre la cámara en fase de preparación.
  Future<void> goToFraming() async {
    _emit(_state.copyWith(stage: PracticeStage.loading));
    final issue = await cameraService.initialize();
    if (issue != CameraIssue.none) {
      await _stopAnalysis();
      _emit(_state.copyWith(
          stage: PracticeStage.cameraUnavailable, cameraIssue: issue));
      return;
    }
    _attempt++;
    _badLightFrames = 0;
    _emit(_state.copyWith(
      stage: PracticeStage.framing,
      cameraIssue: CameraIssue.none,
      lighting: LightingStatus.ok,
      handVisible: false,
    ));
    await WakelockPlus.enable();
    await cameraService.startImageStream(_onFrame);
  }

  /// 3 -> 4: [Comenzar] inicia la captura evaluada.
  Future<void> startCapture() async {
    if (_state.stage != PracticeStage.framing &&
        _state.stage != PracticeStage.incorrect) {
      return;
    }
    _attempt++;
    _captureStart = DateTime.now();
    _stableFrames = 0;
    _missedFrames = 0;
    _badLightFrames = 0;
    _window.clear();
    inferenceService.beginAttempt(_tolerance.level);
    _emit(_state.copyWith(stage: PracticeStage.capturing, handVisible: false));
    if (!cameraService.isStreaming) {
      await cameraService.startImageStream(_onFrame);
    }
  }

  /// 9 -> 4: [INTENTAR DE NUEVO].
  Future<void> tryAgain() async {
    await startCapture();
  }

  /// 6 -> 3 (y contingencia de luz): [Intentar nuevamente] vuelve al encuadre.
  Future<void> retryFraming() => goToFraming();

  /// 9 -> 2: [VER GUÍA].
  Future<void> viewGuide() async {
    await _stopAnalysis();
    _emit(_state.copyWith(stage: PracticeStage.demonstration));
  }

  /// 10 -> siguiente seña (2) o cierre de lección (11).
  Future<void> next() async {
    await _stopAnalysis();
    if (_state.isLastPending) {
      if (_lessonId != null) await HiveService.markLessonCompleted(_lessonId!);
      _emit(_state.copyWith(
          stage: PracticeStage.lessonSummary, user: HiveService.currentUser));
      return;
    }
    // Siguiente seña pendiente, en orden.
    var i = _state.index;
    do {
      i = (i + 1) % _state.totalSigns;
    } while (_state.completedIds.contains(_state.signs[i].id));
    _emit(_state.copyWith(stage: PracticeStage.demonstration, index: i));
  }

  // ───────────────────────── Análisis de fotogramas ─────────────────────────

  Future<void> _onFrame(CameraImage image) async {
    final stage = _state.stage;
    if (stage != PracticeStage.framing &&
        stage != PracticeStage.capturing &&
        stage != PracticeStage.evaluating) {
      return;
    }
    final attempt = _attempt;
    final analysis = await inferenceService.analyzeFrame(
      image,
      rotationDeg: cameraService.rotationDeg,
      mirror: cameraService.isFrontCamera,
      tolerance: _tolerance,
    );
    // Descartar resultados de un intento anterior o de un fotograma omitido.
    if (analysis == null || attempt != _attempt || _disposed) return;

    switch (_state.stage) {
      case PracticeStage.framing:
        _onFramingFrame(analysis);
      case PracticeStage.capturing:
        await _onCaptureFrame(analysis);
      case PracticeStage.evaluating:
        await _onEvaluationFrame(analysis);
      default:
        break;
    }
  }

  /// Estado 3: solo informa luz y mano en vivo; no evalúa nada.
  /// En modo conceptual no hay detector real: no se afirma ver la mano.
  void _onFramingFrame(FrameAnalysis a) {
    final visible = _state.mode == EngineMode.edgeAi && a.handVisible;
    if (a.lighting != _state.lighting || visible != _state.handVisible) {
      _emit(_state.copyWith(lighting: a.lighting, handVisible: visible));
    }
  }

  /// Estados 4 y 5: espera la mano estable dentro del recuadro.
  Future<void> _onCaptureFrame(FrameAnalysis a) async {
    if (!await _lightingOk(a)) return;

    if (a.handVisible) {
      _stableFrames++;
      if (a.hand != null) _window.add(a.hand!);
      if (_stableFrames >= _tolerance.stableFramesRequired) {
        _evalStart = DateTime.now();
        _missedFrames = 0;
        _emit(_state.copyWith(
            stage: PracticeStage.evaluating, handVisible: true));
        return;
      }
    } else {
      _stableFrames = 0;
      _window.clear();
      if (DateTime.now().difference(_captureStart) >
          AppConstants.captureTimeout) {
        // 5 -> 6: se pausa el análisis y se pide reencuadrar.
        await _stopAnalysis();
        _emit(_state.copyWith(
            stage: PracticeStage.handNotDetected, handVisible: false));
        return;
      }
    }
    if (a.handVisible != _state.handVisible) {
      _emit(_state.copyWith(handVisible: a.handVisible));
    }
  }

  /// Estado 7: junta la ventana de movimiento y decide (estado 8).
  Future<void> _onEvaluationFrame(FrameAnalysis a) async {
    if (!await _lightingOk(a)) return;

    if (a.handVisible) {
      _missedFrames = 0;
      if (a.hand != null) _window.add(a.hand!);
    } else if (++_missedFrames > DevicePerformance.targetFps ~/ 2) {
      await _stopAnalysis();
      _emit(_state.copyWith(
          stage: PracticeStage.handNotDetected, handVisible: false));
      return;
    }

    if (DateTime.now().difference(_evalStart) < AppConstants.evaluationWindow) {
      return;
    }

    await _stopAnalysis();
    final sign = _state.currentSign!;
    final evaluation = await inferenceService.evaluate(
      frames: List.of(_window),
      signId: sign.id,
      classifierLabel: sign.keypointsLabel,
      tolerance: _tolerance,
    );
    final user = await HiveService.recordAttempt(
      signId: sign.id,
      correct: evaluation.isCorrect,
    );
    _tolerance = ToleranceProfile.forLevel(user.level);

    if (evaluation.isCorrect) {
      _emit(_state.copyWith(
        stage: PracticeStage.correct,
        evaluation: evaluation,
        completedIds: {..._state.completedIds, sign.id},
        sessionXp: _state.sessionXp + AppConstants.xpPerCorrectSign,
        combo: _state.combo + 1,
        user: user,
      ));
    } else {
      _emit(_state.copyWith(
          stage: PracticeStage.incorrect,
          evaluation: evaluation,
          combo: 0,
          user: user));
    }
  }

  /// Verifica iluminación antes de validar. Tres fotogramas malos seguidos
  /// pausan la práctica con un mensaje claro.
  Future<bool> _lightingOk(FrameAnalysis a) async {
    if (a.lighting == LightingStatus.ok) {
      _badLightFrames = 0;
      return true;
    }
    if (++_badLightFrames >= 3) {
      await _stopAnalysis();
      _emit(_state.copyWith(
          stage: PracticeStage.environmentIssue, lighting: a.lighting));
    }
    return false;
  }

  Future<void> _stopAnalysis() async {
    _attempt++;
    await cameraService.stopImageStream();
    await WakelockPlus.disable();
  }

  // ───────────────────────── Ciclo de vida ─────────────────────────

  /// App en segundo plano: liberar el sensor para otras apps.
  Future<void> onAppPaused() async {
    if (!_state.showsCamera) return;
    await _stopAnalysis();
    await cameraService.release();
    _emit(_state.copyWith(stage: PracticeStage.demonstration));
  }

  Future<void> stop() async {
    await _stopAnalysis();
  }

  @override
  void dispose() {
    _disposed = true;
    _attempt++;
    cameraService.stopImageStream();
    WakelockPlus.disable();
    super.dispose();
  }
}
