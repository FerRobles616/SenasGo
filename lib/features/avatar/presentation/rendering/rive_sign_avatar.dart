import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import 'package:senasgo/features/avatar/presentation/controllers/avatar_playback_controller.dart';

/// Contrato del archivo Rive del avatar profesional.
///
/// Especificación completa para diseño: `docs/rive_avatar_spec.md`.
/// La app es dueña del tiempo: escala el reloj del runtime (0.5x, pausa) y
/// envía las expresiones en cada fotograma, así los controles funcionan igual
/// que con el avatar procedural.
class RiveAvatarContract {
  const RiveAvatarContract._();

  static const String asset = 'assets/rive/sign_avatar.riv';
  static const String stateMachine = 'SignLanguage';

  /// Number: qué seña ejecutar (SignAnimationModel.riveSignIndex).
  /// El runtime de Rive no admite inputs de texto: la palabra se traduce acá.
  static const String signIndex = 'signIndex';

  /// Trigger: reproducir / repetir la seña de [signIndex].
  static const String play = 'play';

  /// Number 0-100: posición en la línea de tiempo (variante con Blend 1D).
  static const String progress = 'progress';

  // Capas no manuales (Number 0-100), mezcladas sobre la seña.
  static const String browRaise = 'browRaise';
  static const String browFurrow = 'browFurrow';
  static const String smile = 'smile';
  static const String mouthOpen = 'mouthOpen';
  static const String headNod = 'headNod'; // -100..100
  static const String headShake = 'headShake'; // -100..100

  static const List<String> numberInputs = [
    signIndex,
    progress,
    browRaise,
    browFurrow,
    smile,
    mouthOpen,
    headNod,
    headShake,
  ];
}

/// Renderer Rive: se usa automáticamente cuando existe [RiveAvatarContract.asset]
/// y el equipo tiene memoria suficiente.
class RiveSignAvatar extends StatefulWidget {
  const RiveSignAvatar({required this.controller, super.key});

  final AvatarPlaybackController controller;

  @override
  State<RiveSignAvatar> createState() => _RiveSignAvatarState();
}

class _RiveSignAvatarState extends State<RiveSignAvatar> {
  final Map<String, SMINumber> _numbers = {};
  SMITrigger? _play;
  int _lastPlayId = -1;

  void _onInit(Artboard artboard) {
    final sm = _ScaledStateMachineController.fromArtboard(
      artboard,
      RiveAvatarContract.stateMachine,
      // Cámara lenta y pausa: el reloj de Rive sigue al de la app.
      speed: () =>
          widget.controller.isPlaying ? widget.controller.speed.factor : 0,
    );
    if (sm == null) {
      debugPrint(
          'Rive: falta la State Machine "${RiveAvatarContract.stateMachine}".');
      return;
    }
    artboard.addController(sm);
    for (final name in RiveAvatarContract.numberInputs) {
      final input = sm.getNumberInput(name);
      if (input != null) _numbers[name] = input;
    }
    _play = sm.getTriggerInput(RiveAvatarContract.play);
    widget.controller.addListener(_push);
    _push();
  }

  /// Envía el estado de la app a la State Machine en cada fotograma.
  void _push() {
    final c = widget.controller;
    final f = c.frame;
    void set(String name, num value) =>
        _numbers[name]?.value = value.toDouble();

    set(RiveAvatarContract.signIndex, c.animation.riveSignIndex ?? 0);
    set(RiveAvatarContract.progress, c.progress * 100);
    set(RiveAvatarContract.browRaise, f.face.browRaise * 100);
    set(RiveAvatarContract.browFurrow, f.face.browFurrow * 100);
    set(RiveAvatarContract.smile, f.face.smile.clamp(0, 1) * 100);
    set(RiveAvatarContract.mouthOpen, f.face.mouthOpen * 100);
    set(RiveAvatarContract.headNod, (f.body.headPitch / 15).clamp(-1, 1) * 100);
    set(RiveAvatarContract.headShake, (f.body.headYaw / 15).clamp(-1, 1) * 100);

    // Cada reproducción nueva (play, repetir, otra seña) dispara el Trigger
    // una sola vez, después de fijar signIndex.
    if (c.playId != _lastPlayId) {
      _lastPlayId = c.playId;
      if (c.playId > 0) _play?.fire();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_push);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RiveAnimation.asset(
      RiveAvatarContract.asset,
      fit: BoxFit.contain,
      onInit: _onInit,
    );
  }
}

/// StateMachineController con el tiempo escalado: 0.5x avanza a la mitad y
/// 0 congela la seña (pausa), sin inputs extra en el archivo Rive.
class _ScaledStateMachineController extends StateMachineController {
  _ScaledStateMachineController(super.stateMachine, {required this.speed});

  final double Function() speed;

  static _ScaledStateMachineController? fromArtboard(
    Artboard artboard,
    String name, {
    required double Function() speed,
  }) {
    for (final animation in artboard.animations) {
      if (animation is StateMachine && animation.name == name) {
        final controller =
            _ScaledStateMachineController(animation, speed: speed);
        if (artboard is RuntimeArtboard) {
          artboard.addNestedEventListener(controller);
        }
        return controller;
      }
    }
    return null;
  }

  // El tipo del contexto es interno del paquete rive (no exportado); ampliar el
  // parámetro a Object es una sobrescritura válida en Dart.
  @override
  void apply(Object core, double elapsedSeconds) =>
      super.apply(core as dynamic, elapsedSeconds * speed());
}
