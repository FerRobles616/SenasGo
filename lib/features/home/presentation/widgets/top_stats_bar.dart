import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/home/domain/learning_path.dart';
import 'package:senasgo/shared/widgets/jaguarete_mascot.dart';

/// Barra superior fija con perfil, racha, energía y XP.
///
/// Las estadísticas se explican al tocarlas y la racha lleva al calendario.
/// El avatar abre el perfil; así la app tiene un lugar para la identidad de
/// quien aprende sin sumar otra pestaña a la navegación principal.
class TopStatsBar extends StatelessWidget {
  const TopStatsBar({required this.stats, super.key});

  final PlayerStats stats;

  @override
  Widget build(BuildContext context) {
    final nextEnergy = stats.nextEnergyIn;
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      toolbarHeight: 66,
      titleSpacing: 14,
      shape: Border(
        bottom: BorderSide(color: AppColors.border, width: 1.2),
      ),
      title: Row(
        children: [
          _ProfileAvatar(
            onTap: () => context.push('/profile'),
          ),
          const SizedBox(width: 8),
          const _LanguageBadge(),
          const Spacer(),
          _Stat(
            icon: Icons.local_fire_department_rounded,
            color:
                stats.practicedToday ? AppColors.streak : AppColors.lockedInk,
            value: '${stats.streak}',
            label: 'Racha',
            help: stats.practicedToday
                ? '¡Racha de ${stats.streak} ${stats.streak == 1 ? 'día' : 'días'}! Ya practicaste hoy.'
                : 'Practicá una seña hoy para mantener tu racha.',
            onTap: () => context.push('/streak'),
          ),
          _Stat(
            icon: Icons.battery_charging_full_rounded,
            color: stats.energy > 0 ? AppColors.teal : AppColors.lockedInk,
            value: '${stats.energy}',
            label: 'Energía',
            help: nextEnergy == null
                ? 'Tenés toda tu energía. Se gasta con cada intento incorrecto.'
                : 'Recuperás 1 energía en ${nextEnergy.inMinutes + 1} min.',
            onTap: () => context.push('/progress'),
          ),
          _Stat(
            icon: Icons.bolt_rounded,
            color: AppColors.primary,
            value: '${stats.xp}',
            label: 'XP',
            help:
                'Ganás +10 XP por cada seña correcta. Los XP suben tu nivel y desbloquean tu progreso.',
            onTap: () => context.push('/progress'),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Abrir mi perfil',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 42,
          height: 42,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.14),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipOval(
            child: ColoredBox(
              color: AppColors.primarySoft,
              child: FittedBox(
                fit: BoxFit.cover,
                child: JaguareteMascot(size: 58),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageBadge extends StatelessWidget {
  const _LanguageBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sign_language_rounded, color: AppColors.primary, size: 18),
          SizedBox(width: 4),
          Text(
            'LSPy',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.help,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String help;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Tooltip(
      message: help,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 3),
      child: Semantics(
        label: '$label: $value. $help',
        excludeSemantics: true,
        button: onTap != null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 2),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: content,
    );
  }
}
