import 'package:flutter/foundation.dart';
import 'package:senasgo/features/avatar/data/sign_animation_catalog.dart';
import 'package:senasgo/features/avatar/domain/sign_animation_model.dart';
import 'package:senasgo/features/avatar/presentation/controllers/avatar_playback_controller.dart';

/// Órdenes que el avatar recibe del resto de la app.
enum AvatarCommand { play, replay, stop, speed }

/// Controla el avatar desde cualquier pantalla, como un TextEditingController:
/// se crea afuera, se pasa a [GestureAvatar] y se le dan órdenes.
///
/// ```dart
/// final avatar = GestureAvatarController();
/// GestureAvatar(controller: avatar);
/// avatar.playSign('Hola');        // por palabra
/// avatar.playSign('saludo_chau'); // o por id
/// avatar.setSpeed(PlaybackSpeed.slow);
/// ```
///
/// Funciona igual con el avatar Rive y con el procedural: en Rive,
/// `playSign` se traduce a los inputs `signIndex` + `play` (ver
/// docs/rive_avatar_spec.md).
class GestureAvatarController extends ChangeNotifier {
  GestureAvatarController({String initialSign = 'saludo_hola'})
      : _current = SignAnimationCatalog.resolve(initialSign) ??
            SignAnimationCatalog.of(initialSign);

  SignAnimationModel _current;
  AvatarCommand? _lastCommand;
  PlaybackSpeed _speed = PlaybackSpeed.normal;

  /// Seña cargada actualmente.
  SignAnimationModel get current => _current;

  /// Última orden recibida (la lee [GestureAvatar]).
  AvatarCommand? get lastCommand => _lastCommand;

  PlaybackSpeed get speed => _speed;

  /// Reproduce la seña de la palabra o letra que se está aprendiendo.
  /// Acepta el id ("basico_gracias") o la palabra ("Gracias", "gracias").
  /// Devuelve false si esa seña todavía no tiene animación; en ese caso el
  /// avatar no cambia.
  bool playSign(String signName) {
    final animation = SignAnimationCatalog.resolve(signName);
    if (animation == null) {
      debugPrint('GestureAvatarController: sin animación para "$signName".');
      return false;
    }
    _current = animation;
    _send(AvatarCommand.play);
    return true;
  }

  /// Repite la seña actual desde el inicio, con fundido.
  void replay() => _send(AvatarCommand.replay);

  /// Vuelve al reposo (idle).
  void stop() => _send(AvatarCommand.stop);

  /// Cámara lenta (0.5x) o normal (1x).
  void setSpeed(PlaybackSpeed value) {
    if (value == _speed) return;
    _speed = value;
    _send(AvatarCommand.speed);
  }

  void _send(AvatarCommand command) {
    _lastCommand = command;
    notifyListeners();
  }
}
