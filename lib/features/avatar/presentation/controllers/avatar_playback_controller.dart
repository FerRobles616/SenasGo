import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:senasgo/features/avatar/domain/sign_animation_model.dart';

/// Velocidades disponibles para el estudiante.
enum PlaybackSpeed {
  slow(0.5, 'Lento 0.5x'),
  normal(1, 'Normal 1x');

  const PlaybackSpeed(this.factor, this.label);

  final double factor;
  final String label;
}

/// Controla la reproducción de una seña: play/pausa, cámara lenta, repetir,
/// arrastrar la línea de tiempo y la cámara (rotación del avatar).
///
/// Es el único dueño del tiempo: cualquier renderer (procedural o Rive) solo
/// lee [frame] y [progress], así los controles funcionan igual en ambos.
class AvatarPlaybackController extends ChangeNotifier {
  AvatarPlaybackController({
    required TickerProvider vsync,
    required SignAnimationModel animation,
    bool autoplay = true,
    bool idleMotion = true,
  }) : _animation = animation {
    _timeline = AnimationController(vsync: vsync, duration: animation.duration)
      ..addListener(notifyListeners)
      ..addStatusListener((_) => notifyListeners());
    // Fundido de entrada al repetir o cambiar de seña: nunca hay saltos.
    _blend = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 320),
      value: 1,
    )..addListener(notifyListeners);
    _camera = AnimationController(
        vsync: vsync, duration: const Duration(milliseconds: 550))
      ..addListener(_onCameraTick);
    // Respiración y parpadeo: el avatar se siente vivo aunque esté en pausa.
    _idle =
        AnimationController(vsync: vsync, duration: const Duration(seconds: 4));
    if (idleMotion) _idle.repeat();
    _idle.addListener(notifyListeners);

    if (autoplay) {
      // Pequeña pausa para que el estudiante vea la pose inicial.
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (!_disposed && !isPlaying && progress == 0) play();
      });
    }
  }

  late final AnimationController _timeline;
  late final AnimationController _blend;
  late final AnimationController _camera;
  late final AnimationController _idle;

  SignAnimationModel _animation;
  PlaybackSpeed _speed = PlaybackSpeed.normal;
  AvatarFrame _blendFrom = AvatarFrame.rest;
  double _yaw = 0, _pitch = 0, _yawFrom = 0, _pitchFrom = 0;
  bool _disposed = false;
  int _playId = 0;

  SignAnimationModel get animation => _animation;
  PlaybackSpeed get speed => _speed;
  bool get isPlaying => _timeline.isAnimating;
  bool get isCompleted => _timeline.status == AnimationStatus.completed;
  double get progress => _timeline.value;

  /// Sube cada vez que una seña arranca desde el inicio. Los renderers que
  /// manejan su propio tiempo (Rive con Trigger) lo usan para disparar `play`.
  int get playId => _playId;

  /// Rotación de cámara en radianes (arrastre horizontal / vertical).
  double get yaw => _yaw;
  double get pitch => _pitch;
  bool get isCameraRotated => _yaw.abs() > 0.02 || _pitch.abs() > 0.02;

  /// Fase del ciclo de reposo (0-1), para respiración y parpadeo.
  double get idlePhase => _idle.value;

  /// Pose actual, con fundido suave desde la pose anterior si corresponde.
  AvatarFrame get frame {
    final target = _animation.sample(progress);
    if (_blend.value >= 1) return target;
    return AvatarFrame.lerp(
        _blendFrom, target, Curves.easeOutCubic.transform(_blend.value));
  }

  Duration get _scaledDuration => _animation.duration * (1 / _speed.factor);

  void play() {
    if (isCompleted || progress >= 1) {
      replay();
      return;
    }
    if (progress == 0) _playId++;
    _timeline.duration = _scaledDuration;
    _timeline.forward();
  }

  void pause() => _timeline.stop();

  void togglePlay() => isPlaying ? pause() : play();

  /// Repite desde el inicio con un fundido desde la pose actual.
  void replay() {
    _playId++;
    _blendFrom = frame;
    _timeline
      ..stop()
      ..value = 0
      ..duration = _scaledDuration;
    _blend.forward(from: 0);
    _timeline.forward();
  }

  /// Cambia la velocidad sin reiniciar: la seña sigue desde donde estaba.
  void setSpeed(PlaybackSpeed value) {
    if (value == _speed) return;
    _speed = value;
    _timeline.duration = _scaledDuration;
    if (isPlaying) _timeline.forward();
    notifyListeners();
  }

  /// Vuelve al reposo con un fundido y queda en pausa.
  void stop() {
    _blendFrom = frame;
    _timeline
      ..stop()
      ..value = 0;
    _blend.forward(from: 0);
    notifyListeners();
  }

  /// Arrastrar la barra de progreso (pausa la reproducción).
  void seek(double value) {
    _timeline.stop();
    _timeline.value = value.clamp(0.0, 1.0);
  }

  /// Cambia de seña con fundido; útil al pasar a la siguiente.
  void setAnimation(SignAnimationModel value, {bool autoplay = true}) {
    if (identical(value, _animation)) return;
    _blendFrom = frame;
    _animation = value;
    _timeline
      ..stop()
      ..value = 0;
    _blend.forward(from: 0);
    if (autoplay) play();
    notifyListeners();
  }

  /// Rotación por arrastre: horizontal gira el cuerpo, vertical inclina.
  void rotateBy(double dx, double dy) {
    _camera.stop();
    _yaw = (_yaw + dx * 0.012).clamp(-1.35, 1.35);
    _pitch = (_pitch - dy * 0.006).clamp(-0.35, 0.35);
    notifyListeners();
  }

  /// Vuelve la cámara al frente con una animación elástica suave.
  void resetCamera() {
    _yawFrom = _yaw;
    _pitchFrom = _pitch;
    _camera.forward(from: 0);
  }

  void _onCameraTick() {
    final t = Curves.easeOutBack.transform(_camera.value);
    _yaw = _yawFrom * (1 - t);
    _pitch = _pitchFrom * (1 - t);
    if (_camera.isCompleted) _yaw = _pitch = 0;
    notifyListeners();
  }

  /// Respiración: desplazamiento vertical sutil del torso.
  double get breath => math.sin(idlePhase * 2 * math.pi) * 0.004;

  /// Parpadeo breve una vez por ciclo (0 = abierto, 1 = cerrado).
  double get blink {
    final p = (idlePhase - 0.62) / 0.05;
    return p < 0 || p > 1 ? 0 : math.sin(p * math.pi);
  }

  @override
  void dispose() {
    _disposed = true;
    _timeline.dispose();
    _blend.dispose();
    _camera.dispose();
    _idle.dispose();
    super.dispose();
  }
}
