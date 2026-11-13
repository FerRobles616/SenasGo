import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Ráfaga decorativa de XP, dibujada con Lottie y reproducida una sola vez.
///
/// Es puramente decorativa: no recibe toques, no aporta semántica y se apaga
/// por completo en el último fotograma. Si el sistema pide reducir
/// animaciones, no se monta el reproductor y queda el icono estático.
class LottieXpBurst extends StatelessWidget {
  const LottieXpBurst({this.size = 64, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return SizedBox.square(dimension: size);
    }
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Lottie.asset(
          'assets/animations/xp_burst.json',
          width: size,
          height: size,
          fit: BoxFit.contain,
          repeat: false,
          animate: true,
          errorBuilder: (context, error, stackTrace) =>
              const SizedBox.shrink(),
        ),
      ),
    );
  }
}
