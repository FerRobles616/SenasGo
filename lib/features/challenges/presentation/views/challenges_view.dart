import 'package:flutter/material.dart';
import 'package:senasgo/core/constants/app_constants.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/support/presentation/support_actions.dart';
import 'package:senasgo/shared/widgets/app_bottom_nav.dart';
import 'package:senasgo/shared/widgets/app_ui.dart';

/// Retos locales: pequeñas metas diarias y semanales que dan XP extra.
///
/// No hay ranking de otras personas ni eventos en línea: todo se calcula con
/// la actividad guardada en este teléfono.
class ChallengesView extends StatefulWidget {
  const ChallengesView({super.key});

  @override
  State<ChallengesView> createState() => _ChallengesViewState();
}

class _ChallengesViewState extends State<ChallengesView> {
  bool _claiming = false;

  List<_Challenge> _buildChallenges() {
    final claimed = HiveService.claimedChallenges;
    return [
      _Challenge(
        id: 'daily_xp',
        title: 'Ganá 20 XP hoy',
        subtitle:
            'Cada seña correcta suma ${AppConstants.xpPerCorrectSign} XP.',
        icon: Icons.bolt_rounded,
        color: AppColors.primary,
        progress: HiveService.dailyXp,
        target: 20,
        reward: AppConstants.xpPerChallenge,
        claimed: claimed.contains('daily_xp'),
      ),
      _Challenge(
        id: 'weekly_signs',
        title: 'Practicá 3 señas distintas',
        subtitle: 'Durante esta semana.',
        icon: Icons.sign_language_rounded,
        color: AppColors.teal,
        progress: HiveService.weeklyDistinctSigns,
        target: 3,
        reward: AppConstants.xpPerChallenge,
        claimed: claimed.contains('weekly_signs'),
      ),
      _Challenge(
        id: 'weekend_practice',
        title: 'Entrená el fin de semana',
        subtitle: 'Sumá 2 prácticas entre sábado y domingo.',
        icon: Icons.weekend_rounded,
        color: AppColors.sky,
        progress: HiveService.weekendPracticeCount,
        target: 2,
        reward: AppConstants.xpPerChallenge,
        claimed: claimed.contains('weekend_practice'),
      ),
      _Challenge(
        id: 'streak_3',
        title: 'Mantené una racha de 3 días',
        subtitle: 'La constancia vale más que la prisa.',
        icon: Icons.local_fire_department_rounded,
        color: AppColors.streak,
        progress: HiveService.streak,
        target: 3,
        reward: AppConstants.xpPerChallenge + 10,
        claimed: claimed.contains('streak_3'),
      ),
    ];
  }

  Future<void> _claim(_Challenge challenge) async {
    if (_claiming || !challenge.canClaim) return;
    setState(() => _claiming = true);
    await HiveService.claimChallenge(challenge.id, challenge.reward);
    if (!mounted) return;
    setState(() => _claiming = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(
          children: [
            Icon(Icons.bolt_rounded, color: AppColors.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '¡Reto completado! Ganaste +${challenge.reward} XP.',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final challenges = _buildChallenges();
    final completed = challenges.where((c) => c.canClaim).length;
    final claimed = challenges.where((c) => c.claimed).length;

    return Scaffold(
      appBar: AppBar(
        // Pestaña raíz: sin flecha aunque Aprender la abra con push.
        automaticallyImplyLeading: false,
        title: const Text('Retos'),
        actions: [
          IconButton(
            tooltip: 'Ayuda y comentarios',
            onPressed: () =>
                SupportSheet.show(context, contextLabel: 'Pantalla de retos'),
            icon: const Icon(Icons.support_agent_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          AppHeroHeader(
            colors: const [Color(0xFF1D4ED8), Color(0xFF38BDF8)],
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(Icons.emoji_events_rounded,
                      color: Colors.white, size: 34),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Retos de la semana',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$claimed de ${challenges.length} recompensas reclamadas',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.86),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            color: AppColors.primarySoft,
            borderColor: AppColors.primarySoft,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    color: AppColors.primary, size: 21),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    completed == 0
                        ? 'Completá un reto para reclamar XP extra. Todo se calcula sin conexión.'
                        : 'Tenés $completed ${completed == 1 ? 'recompensa lista' : 'recompensas listas'} para reclamar.',
                    style: TextStyle(
                      color: AppColors.primaryDeep,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const AppSectionTitle(
            'Tus retos',
            subtitle: 'Se renuevan con tu actividad diaria y semanal.',
          ),
          const SizedBox(height: 10),
          for (final challenge in challenges) ...[
            _ChallengeCard(
              challenge: challenge,
              claiming: _claiming,
              onClaim: () => _claim(challenge),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppColors.muted, size: 20),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Los retos y la liga son locales: no hay cuentas, servidores '
                    'ni competencia con otras personas. Tu progreso no sale de '
                    'este teléfono.',
                    style: TextStyle(
                      color: AppColors.muted.withValues(alpha: 0.95),
                      fontSize: 12.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }
}

class _Challenge {
  const _Challenge({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.progress,
    required this.target,
    required this.reward,
    required this.claimed,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int progress;
  final int target;
  final int reward;
  final bool claimed;

  bool get complete => progress >= target;
  bool get canClaim => complete && !claimed;

  double get fraction => target == 0 ? 1 : (progress / target).clamp(0, 1);
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.challenge,
    required this.claiming,
    required this.onClaim,
  });

  final _Challenge challenge;
  final bool claiming;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final done = challenge.complete;
    final statusColor = challenge.claimed
        ? AppColors.success
        : done
            ? challenge.color
            : AppColors.muted;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIconBadge(icon: challenge.icon, color: challenge.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            challenge.title,
                            style: TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 15.5,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        AppPill(
                          icon: Icons.bolt_rounded,
                          label: '+${challenge.reward} XP',
                          color: AppColors.primary,
                          background: AppColors.primarySoft,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      challenge.subtitle,
                      style: TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppProgressBar(
                  value: challenge.fraction,
                  color:
                      challenge.claimed ? AppColors.success : challenge.color,
                  background: challenge.color.withValues(alpha: 0.12),
                  height: 8,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                '${challenge.progress.clamp(0, challenge.target)}/${challenge.target}',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            child: challenge.claimed
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('RECLAMADO'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.success,
                      side: BorderSide(color: AppColors.successSoft),
                      backgroundColor: AppColors.successSoft,
                      minimumSize: const Size.fromHeight(42),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: done && !claiming ? onClaim : null,
                    icon: Icon(
                      done ? Icons.redeem_rounded : Icons.lock_clock_rounded,
                      size: 18,
                    ),
                    label: Text(done ? 'RECLAMAR RECOMPENSA' : 'EN PROGRESO'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                      backgroundColor:
                          done ? challenge.color : AppColors.surfaceAlt,
                      foregroundColor: done ? Colors.white : AppColors.muted,
                      disabledBackgroundColor: AppColors.surfaceAlt,
                      disabledForegroundColor: AppColors.muted,
                      textStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
