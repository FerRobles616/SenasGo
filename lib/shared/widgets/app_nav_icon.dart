import 'package:flutter/material.dart';

/// Icono ilustrado de una pestaña principal.
///
/// Los cinco iconos de la barra inferior son piezas de arte propias. Este
/// widget centraliza su tamaño, la transición de selección y el respaldo a un
/// [IconData] si el asset no está disponible (por ejemplo, en una instalación
/// incompleta o durante una prueba).
class AppNavIcon extends StatelessWidget {
  const AppNavIcon({
    required this.asset,
    required this.fallbackIcon,
    required this.selected,
    required this.color,
    this.size = 28,
    super.key,
  });

  /// Ruta del PNG transparente dentro de `assets/icons/nav/`.
  final String asset;

  /// Icono de Material que se usa si el asset no se puede cargar.
  final IconData fallbackIcon;

  /// La pestaña actual se ve a color completo; las demás, atenuadas.
  final bool selected;

  /// Color de acento de la pestaña. Solo lo usa el respaldo de Material.
  final Color color;

  final double size;

  static const _duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duration = reduceMotion ? Duration.zero : _duration;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final opacity = selected ? 1.0 : (isDark ? 0.72 : 0.62);

    return AnimatedOpacity(
      opacity: opacity,
      duration: duration,
      curve: Curves.easeOutCubic,
      child: AnimatedScale(
        scale: selected ? 1.06 : 1,
        duration: duration,
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            asset,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            excludeFromSemantics: true,
            errorBuilder: (context, error, stackTrace) => Icon(
              fallbackIcon,
              size: size,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
