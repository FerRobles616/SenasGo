import 'package:flutter/material.dart';
import 'package:senasgo/features/avatar/presentation/controllers/gesture_avatar_controller.dart';
import 'package:senasgo/features/avatar/presentation/widgets/pro_sign_language_avatar.dart';

/// Avatar profesor manejado desde afuera con un [GestureAvatarController].
///
/// Usa el archivo Rive (`assets/rive/sign_avatar.riv`) si existe y si el
/// equipo tiene memoria suficiente; si no, el avatar procedural. Para quien
/// lo usa no cambia nada: siempre se llama a `controller.playSign(...)`.
class GestureAvatar extends StatelessWidget {
  const GestureAvatar({
    required this.controller,
    this.showControls = true,
    this.height = 320,
    super.key,
  });

  final GestureAvatarController controller;
  final bool showControls;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ProSignLanguageAvatar(
      // La seña inicial; las siguientes llegan por el controller.
      animation: controller.current,
      gestureController: controller,
      showControls: showControls,
      autoplay: false,
      height: height,
    );
  }
}
