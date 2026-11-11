import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/support/presentation/support_actions.dart';
import 'package:senasgo/shared/widgets/app_feature_icon.dart';
import 'package:senasgo/shared/widgets/app_ui.dart';
import 'package:senasgo/shared/widgets/jaguarete_mascot.dart';
import 'package:senasgo/shared/widgets/pushable_button.dart';

/// Liga local de práctica.
///
/// En Duolingo la liga compite con otras personas. SeñasGo es offline y no
/// tiene cuentas, así que la liga es un mapa de metas semanales: no inventamos
/// rivales ni exponemos datos de nadie.
class LeagueView extends StatelessWidget {
  const LeagueView({super.key});

  static const _tiers = [
    _LeagueTier(
        'Bronce', 0, Color(0xFFB45309), Icons.workspace_premium_rounded),
    _LeagueTier('Plata', 30, Color(0xFF64748B), Icons.military_tech_rounded),
    _LeagueTier('Oro', 70, Color(0xFFD97706), Icons.emoji_events_rounded),
    _LeagueTier('Zafiro', 120, Color(0xFF0F766E), Icons.diamond_rounded),
    _LeagueTier('Diamante', 200, Color(0xFF0E7490), Icons.auto_awesome_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final weeklyXp = HiveService.weeklyXp;
    final currentIndex = _tierIndex(weeklyXp);
    final current = _tiers[currentIndex];
    final next =
        currentIndex < _tiers.length - 1 ? _tiers[currentIndex + 1] : null;
    final progress = next == null
        ? 1.0
        : ((weeklyXp - current.minXp) / (next.minXp - current.minXp))
            .clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi liga'),
        actions: [
          IconButton(
            tooltip: 'Ayuda y comentarios',
            onPressed: () =>
                SupportSheet.show(context, contextLabel: 'Liga de práctica'),
            icon: AppFeatureIcon(
              asset: AppFeatureAssets.help,
              fallbackIcon: Icons.support_agent_rounded,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          AppHeroHeader(
            colors: const [
              Color(0xFF071A16),
              Color(0xFF0B3B2E),
              Color(0xFF0F766E)
            ],
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Icon(
                        current.icon,
                        color: AppColors.gold,
                        size: 35,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LIGA ${current.name.toUpperCase()}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.76),
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$weeklyXp XP',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 32,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            next == null
                                ? '¡Estás en la liga más alta!'
                                : 'Te faltan ${next.minXp - weeklyXp} XP para ${next.name}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.86),
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const JaguareteMascot(size: 58, mood: MascotMood.happy),
                  ],
                ),
                const SizedBox(height: 16),
                AppProgressBar(
                  value: progress,
                  color: AppColors.gold,
                  background: Colors.white.withValues(alpha: 0.2),
                  height: 9,
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Text(
                      'Semana actual',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      next == null
                          ? 'Nivel máximo'
                          : '${next.minXp} XP para ${next.name}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const AppSectionTitle(
            'Metas de la semana',
            subtitle: 'Tu liga avanza con el XP que ganás practicando.',
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < _tiers.length; i++) ...[
            _TierRow(
              tier: _tiers[i],
              current: i == currentIndex,
              reached: weeklyXp >= _tiers[i].minXp,
              nextThreshold: i < _tiers.length - 1 ? _tiers[i + 1].minXp : null,
            ),
            if (i < _tiers.length - 1) const SizedBox(height: 8),
          ],
          const SizedBox(height: 20),
          AppCard(
            padding: const EdgeInsets.all(16),
            color: AppColors.primarySoft,
            borderColor: AppColors.primarySoft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Una liga sin presión',
                        style: TextStyle(
                          color: AppColors.primaryDeep,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Esta liga se calcula solo con tu XP de la semana: no '
                        'compite con otras personas ni muestra tus datos a '
                        'nadie.',
                        style: TextStyle(
                          color: AppColors.primaryDeep.withValues(alpha: 0.9),
                          fontSize: 12.5,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PushableButton(
            onPressed: () => context.go('/'),
            color: AppColors.primary,
            shadowColor: AppColors.primaryDark,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'PRACTICAR Y SUBIR DE LIGA',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'La liga se renueva cada lunes. El XP histórico de tu perfil no se pierde.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  static int _tierIndex(int xp) {
    var index = 0;
    for (var i = 0; i < _tiers.length; i++) {
      if (xp >= _tiers[i].minXp) index = i;
    }
    return index;
  }
}

class _LeagueTier {
  const _LeagueTier(this.name, this.minXp, this.color, this.icon);

  final String name;
  final int minXp;
  final Color color;
  final IconData icon;
}

class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.tier,
    required this.current,
    required this.reached,
    required this.nextThreshold,
  });

  final _LeagueTier tier;
  final bool current;
  final bool reached;
  final int? nextThreshold;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      color: current ? AppColors.primarySoft : AppColors.surface,
      borderColor: current ? AppColors.primary : AppColors.border,
      child: Row(
        children: [
          AppIconBadge(
            icon: reached ? Icons.check_rounded : tier.icon,
            color: reached ? tier.color : AppColors.muted,
            size: 42,
            radius: 13,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      tier.name,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                      ),
                    ),
                    if (current) ...[
                      const SizedBox(width: 7),
                      AppPill(
                        icon: Icons.near_me_rounded,
                        label: 'TU LIGA',
                        color: AppColors.primary,
                      ),
                    ],
                  ],
                ),
                Text(
                  reached ? 'Meta alcanzada' : '${tier.minXp} XP para entrar',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          if (nextThreshold != null)
            Text(
              '${tier.minXp}-${nextThreshold! - 1} XP',
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
                fontSize: 10.5,
              ),
            ),
        ],
      ),
    );
  }
}
