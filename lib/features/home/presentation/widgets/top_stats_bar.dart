import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/home/domain/learning_path.dart';
import 'package:senasgo/shared/widgets/app_feature_icon.dart';
import 'package:senasgo/shared/widgets/jaguarete_mascot.dart';

/// Barra superior fija con perfil, racha y XP.
///
/// Las estadísticas se explican al tocarlas y la racha lleva al calendario.
/// El avatar abre el perfil; así la app tiene un lugar para la identidad de
/// quien aprende sin sumar otra pestaña a la navegación principal.
class TopStatsBar extends StatelessWidget {
  const TopStatsBar({required this.stats, super.key});

  final PlayerStats stats;

  @override
  Widget build(BuildContext context) {
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
            asset: AppFeatureAssets.streak,
            color:
                stats.practicedToday ? AppColors.streak : AppColors.lockedInk,
            iconOpacity: stats.practicedToday ? 1 : 0.55,
            value: '${stats.streak}',
            label: 'Racha',
            help: stats.practicedToday
                ? '¡Racha de ${stats.streak} ${stats.streak == 1 ? 'día' : 'días'}! Ya practicaste hoy.'
                : 'Practicá una seña hoy para mantener tu racha.',
            onTap: () => context.push('/streak'),
          ),
          _Stat(
            icon: Icons.bolt_rounded,
            asset: AppFeatureAssets.xp,
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

class _Stat extends StatefulWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.help,
    this.asset,
    this.iconOpacity = 1,
    this.onTap,
  });

  final IconData icon;
  final String? asset;
  final Color color;
  final double iconOpacity;
  final String value;
  final String label;
  final String help;
  final VoidCallback? onTap;

  @override
  State<_Stat> createState() => _StatState();
}

class _StatState extends State<_Stat> with SingleTickerProviderStateMixin {
  late final AnimationController _bump = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(begin: 1, end: 1.18)
          .chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.18, end: 1)
          .chain(CurveTween(curve: Curves.elasticOut)),
      weight: 65,
    ),
  ]).animate(_bump);

  @override
  void didUpdateWidget(covariant _Stat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      _bump.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bump.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Tooltip(
      message: widget.help,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 3),
      child: Semantics(
        label: '${widget.label}: ${widget.value}. ${widget.help}',
        excludeSemantics: true,
        button: widget.onTap != null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: widget.iconOpacity,
                child: widget.asset == null
                    ? Icon(widget.icon, color: widget.color, size: 24)
                    : AppFeatureIcon(
                        asset: widget.asset!,
                        fallbackIcon: widget.icon,
                        color: widget.color,
                        size: 26,
                      ),
              ),
              const SizedBox(width: 2),
              Text(
                widget.value,
                style: TextStyle(
                  color: widget.color,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final animated = AnimatedBuilder(
      animation: _bump,
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        child: child,
      ),
      child: content,
    );
    if (widget.onTap == null) return animated;
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(12),
      child: animated,
    );
  }
}
