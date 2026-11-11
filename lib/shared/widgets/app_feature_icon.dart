import 'package:flutter/material.dart';

/// Rutas de los iconos ilustrados de progreso.
///
/// Son piezas de arte propias, con fondo transparente y sin sombras. Se usan
/// en las superficies de racha, XP, cofre, calendario y progreso/plan.
abstract final class AppFeatureAssets {
  static const streak = 'assets/icons/features/feature_streak.png';
  static const xp = 'assets/icons/features/feature_xp.png';
  static const reward = 'assets/icons/features/feature_reward.png';
  static const calendar = 'assets/icons/features/feature_calendar.png';
  static const progress = 'assets/icons/features/feature_progress.png';

  static const community = 'assets/icons/features/feature_community.png';
  static const access = 'assets/icons/features/feature_access.png';
  static const info = 'assets/icons/features/feature_info.png';
  static const practice = 'assets/icons/features/feature_practice.png';
  static const review = 'assets/icons/features/feature_review.png';
  static const goal = 'assets/icons/features/feature_goal.png';
  static const swap = 'assets/icons/features/feature_switch.png';
  static const feedback = 'assets/icons/features/feature_feedback.png';
  static const correct = 'assets/icons/features/feature_correct.png';
  static const celebrate = 'assets/icons/features/feature_celebrate.png';
  static const reminder = 'assets/icons/features/feature_reminder.png';

  /// El icono de ayuda ya existe en la barra inferior; se reutiliza tal cual.
  static const help = 'assets/icons/nav/nav_help.png';
}

/// Icono ilustrado con respaldo a un [IconData] de Material.
///
/// El PNG se muestra a color completo y sin tinte. El respaldo se usa si el
/// asset no está disponible (por ejemplo, en una instalación incompleta o en
/// una prueba). El widget es decorativo: la semántica la aporta el contenedor.
class AppFeatureIcon extends StatelessWidget {
  const AppFeatureIcon({
    required this.asset,
    required this.fallbackIcon,
    required this.color,
    this.size = 24,
    super.key,
  });

  /// Ruta del PNG transparente dentro de `assets/icons/features/`.
  final String asset;

  /// Icono de Material que se usa si el asset no se puede cargar.
  final IconData fallbackIcon;

  /// Color del respaldo de Material.
  final Color color;

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stackTrace) => Icon(
        fallbackIcon,
        color: color,
        size: size,
      ),
    );
  }
}
