import 'package:flutter/material.dart';
import 'package:senasgo/core/constants/app_constants.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/support/presentation/support_actions.dart';
import 'package:senasgo/shared/widgets/app_bottom_nav.dart';
import 'package:senasgo/shared/widgets/app_feature_icon.dart';
import 'package:senasgo/shared/widgets/app_ui.dart';
import 'package:senasgo/shared/widgets/celebration_confetti.dart';

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
  bool _showClaimed = false;
  int _celebration = 0;

  List<_Challenge> _buildChallenges() {
    final claimed = HiveService.claimedChallenges;
    return [
      _Challenge(
        id: 'daily_xp',
        title: 'Ganá 20 XP hoy',
        subtitle:
            'Cada seña correcta suma ${AppConstants.xpPerCorrectSign} XP.',
        icon: Icons.bolt_rounded,
        asset: AppFeatureAssets.xp,
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
        asset: AppFeatureAssets.progress,
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
        asset: AppFeatureAssets.calendar,
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
        asset: AppFeatureAssets.streak,
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
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    setState(() {
      _claiming = false;
      if (!reduceMotion) _celebration++;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(
          children: [
            AppFeatureIcon(
              asset: AppFeatureAssets.xp,
              fallbackIcon: Icons.bolt_rounded,
              color: AppColors.gold,
              size: 20,
            ),
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
    final active = challenges.where((c) => !c.claimed).toList();
    final claimedChallenges = challenges.where((c) => c.claimed).toList();
    final completed = challenges.where((c) => c.canClaim).length;
    final claimed = claimedChallenges.length;

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
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              AppHeroHeader(
                colors: const [Color(0xFF0B3B2E), Color(0xFF0F766E)],
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
                      child: const Center(
                        child: AppFeatureIcon(
                          asset: AppFeatureAssets.reward,
                          fallbackIcon: Icons.emoji_events_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
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
              const SizedBox(height: 18),
              AppSectionTitle(
                'Tus retos',
                subtitle: completed > 0
                    ? 'Tenés $completed ${completed == 1 ? 'recompensa lista' : 'recompensas listas'} para reclamar.'
                    : 'Se renuevan con tu actividad.',
              ),
              const SizedBox(height: 10),
              if (active.isEmpty)
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Ya reclamaste todos los retos disponibles. Volvé cuando '
                    'avances en tu práctica.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                for (final challenge in active) ...[
                  _ChallengeCard(
                    challenge: challenge,
                    claiming: _claiming,
                    onClaim: () => _claim(challenge),
                  ),
                  const SizedBox(height: 10),
                ],
              if (claimedChallenges.isNotEmpty) ...[
                const SizedBox(height: 2),
                if (!_showClaimed)
                  TextButton.icon(
                    onPressed: () => setState(() => _showClaimed = true),
                    icon: const Icon(Icons.expand_more_rounded),
                    label: Text('Ver completados ($claimed)'),
                  )
                else ...[
                  const SizedBox(height: 6),
                  AppSectionTitle(
                    'Completados',
                    subtitle: 'Ya no necesitan acción.',
                  ),
                  const SizedBox(height: 8),
                  for (final challenge in claimedChallenges) ...[
                    _ChallengeCard(
                      challenge: challenge,
                      claiming: _claiming,
                      onClaim: () {},
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextButton.icon(
                    onPressed: () => setState(() => _showClaimed = false),
                    icon: const Icon(Icons.expand_less_rounded),
                    label: const Text('Ocultar completados'),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              Text(
                'Los retos son locales y no compiten con otras personas.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
          Positioned.fill(
            child: CelebrationConfetti(
              key: ValueKey(_celebration),
              active: _celebration > 0,
              particleCount: 22,
              duration: const Duration(milliseconds: 1200),
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
    required this.asset,
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
  final String asset;
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
              AppIconBadge(
                icon: challenge.icon,
                asset: challenge.asset,
                color: challenge.color,
              ),
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
          if (challenge.canClaim) ...[
            const SizedBox(height: 11),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: claiming ? null : onClaim,
                icon: const Icon(Icons.redeem_rounded, size: 18),
                label: Text('RECLAMAR +${challenge.reward} XP'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  backgroundColor: challenge.color,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ] else if (challenge.claimed) ...[
            const SizedBox(height: 9),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppFeatureIcon(
                  asset: AppFeatureAssets.correct,
                  fallbackIcon: Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Text(
                  'Recompensa reclamada',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
