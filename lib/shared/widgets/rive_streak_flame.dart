import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import 'package:senasgo/shared/widgets/rive_environment.dart';

/// Llama de racha dibujada en Rive, con un respaldo mientras carga o si el
/// archivo no se puede leer en este dispositivo.
///
/// El `.riv` se empaqueta con la app: la animación funciona sin conexión. La
/// máquina de estados se llama "State Machine 1" y tiene un disparador
/// `celebrate` que se activa al tocar la llama.
class RiveStreakFlame extends StatefulWidget {
  const RiveStreakFlame({
    required this.size,
    required this.fallback,
    super.key,
  });

  final double size;
  final Widget fallback;

  @override
  State<RiveStreakFlame> createState() => _RiveStreakFlameState();
}

class _RiveStreakFlameState extends State<RiveStreakFlame> {
  static final Future<RiveFile> _file =
      RiveFile.asset('assets/rive/streak_flame.riv');

  StateMachineController? _controller;

  void _onInit(Artboard artboard) {
    for (final controller in artboard.animationControllers) {
      if (controller is StateMachineController) {
        _controller = controller;
        return;
      }
    }
  }

  void _celebrate() => _controller?.triggerInput('celebrate');

  @override
  Widget build(BuildContext context) {
    if (isFlutterTest) return widget.fallback;
    return FutureBuilder<RiveFile>(
      future: _file,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (snapshot.hasError || file == null) return widget.fallback;
        return ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _celebrate,
            child: SizedBox.square(
              dimension: widget.size,
              child: RiveAnimation.direct(
                file,
                stateMachines: const ['State Machine 1'],
                fit: BoxFit.contain,
                alignment: Alignment.center,
                behavior: RiveHitTestBehavior.transparent,
                onInit: _onInit,
              ),
            ),
          ),
        );
      },
    );
  }
}
