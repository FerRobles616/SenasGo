import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:senasgo/core/constants/app_constants.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/shared/widgets/app_feature_icon.dart';
import 'package:senasgo/shared/widgets/celebration_confetti.dart';
import 'package:senasgo/shared/widgets/jaguarete_mascot.dart';
import 'package:senasgo/shared/widgets/pushable_button.dart';

/// Celebración de bienvenida después del onboarding.
///
/// Es la versión local de la pantalla "Ya eres parte" de Duolingo: muestra el
/// estado real de la persona (sin inventar métricas) y entrega una recompensa
/// única de XP para empezar con impulso.
class WelcomeRewardView extends StatefulWidget {
  const WelcomeRewardView({super.key});

  @override
  State<WelcomeRewardView> createState() => _WelcomeRewardViewState();
}

class _WelcomeRewardViewState extends State<WelcomeRewardView> {
  bool _claiming = false;
  bool _celebrating = false;

  Future<void> _claim() async {
    if (_claiming) return;
    if (HiveService.welcomeRewardClaimed) {
      context.go('/');
      return;
    }
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    setState(() => _claiming = true);
    await HiveService.claimWelcomeReward();
    if (!mounted) return;
    if (reduceMotion) {
      context.go('/');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _celebrating = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final user = HiveService.currentUser;
    final accuracy = HiveService.progress.accuracy;
    final streak = HiveService.streak;
    final claimed = HiveService.welcomeRewardClaimed;
    final compact = MediaQuery.sizeOf(context).height < 720;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF04120F),
                  AppColors.primary,
                  Color(0xFF2DD4BF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                        24, compact ? 8 : 20, 24, compact ? 12 : 24),
                    child: Column(
                      children: [
                        Container(
                          width: compact ? 120 : 152,
                          height: compact ? 120 : 152,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: JaguareteMascot(
                              size: compact ? 96 : 122,
                              mood: MascotMood.cheering,
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 10 : 20),
                        Text(
                          '¡Ya sos parte\nde SeñasGo!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 29 : 36,
                            fontWeight: FontWeight.w900,
                            height: 1.03,
                            letterSpacing: -0.7,
                          ),
                        ),
                        SizedBox(height: compact ? 5 : 9),
                        Text(
                          'No queremos adelantarnos, pero ya diste el primer paso. '
                          'Tu camino LSPy empieza hoy.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: compact ? 13 : 14.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: compact ? 12 : 22),
                        Row(
                          children: [
                            Expanded(
                              child: _RewardStat(
                                icon: Icons.bolt_rounded,
                                asset: AppFeatureAssets.xp,
                                color: AppColors.gold,
                                value: '${user.xp}',
                                label: 'XP total',
                                compact: compact,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _RewardStat(
                                icon: Icons.track_changes_rounded,
                                asset: AppFeatureAssets.goal,
                                color: AppColors.success,
                                value: '${(accuracy * 100).round()}%',
                                label: 'precisión',
                                compact: compact,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _RewardStat(
                                icon: Icons.local_fire_department_rounded,
                                asset: AppFeatureAssets.streak,
                                color: AppColors.streak,
                                value: '$streak',
                                label: streak == 1 ? 'día' : 'días',
                                compact: compact,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 12 : 18),
                        Container(
                          padding: EdgeInsets.all(compact ? 12 : 15),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.navy.withValues(alpha: 0.16),
                                blurRadius: 22,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: compact ? 40 : 48,
                                height: compact ? 40 : 48,
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: AppFeatureIcon(
                                  asset: AppFeatureAssets.reward,
                                  fallbackIcon: Icons.redeem_rounded,
                                  color: AppColors.primary,
                                  size: compact ? 28 : 32,
                                ),
                              ),
                              SizedBox(width: compact ? 8 : 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      claimed
                                          ? 'Recompensa ya reclamada'
                                          : 'Recompensa de bienvenida',
                                      style: TextStyle(
                                        color: AppColors.ink,
                                        fontWeight: FontWeight.w900,
                                        fontSize: compact ? 13 : 14,
                                      ),
                                    ),
                                    Text(
                                      claimed
                                          ? 'Tu XP ya está guardado en tu cuenta.'
                                          : 'Sumá +${AppConstants.welcomeRewardXp} XP para arrancar.',
                                      style: TextStyle(
                                        color: AppColors.muted,
                                        fontWeight: FontWeight.w600,
                                        fontSize: compact ? 11 : 12,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '+${AppConstants.welcomeRewardXp} XP',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: compact ? 13 : 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: compact ? 12 : 20),
                        PushableButton(
                          onPressed: _claiming ? null : _claim,
                          color: Colors.white,
                          shadowColor: const Color(0xFFB9D6FF),
                          height: compact ? 52 : 58,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!claimed && !_claiming) ...[
                                AppFeatureIcon(
                                  asset: AppFeatureAssets.celebrate,
                                  fallbackIcon: Icons.celebration_rounded,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                claimed
                                    ? 'IR A MI CAMINO'
                                    : _claiming
                                        ? 'GUARDANDO…'
                                        : 'RECIBIR +${AppConstants.welcomeRewardXp} XP',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15.5,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),
                        TextButton(
                          onPressed: _claiming ? null : () => context.go('/'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Ahora no'),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Tu recompensa y tu progreso se guardan en tu cuenta: '
                          'no los perdés si cambiás de teléfono.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.68),
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CelebrationConfetti(
              active: _celebrating,
              particleCount: 30,
              duration: const Duration(milliseconds: 900),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardStat extends StatelessWidget {
  const _RewardStat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.asset,
    this.compact = false,
  });

  final IconData icon;
  final String? asset;
  final Color color;
  final String value;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          compact ? 6 : 9, compact ? 8 : 12, compact ? 6 : 9, compact ? 7 : 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          asset == null
              ? Icon(icon, color: color, size: compact ? 19 : 22)
              : AppFeatureIcon(
                  asset: asset!,
                  fallbackIcon: icon,
                  color: color,
                  size: compact ? 22 : 26,
                ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: compact ? 20 : 23,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontWeight: FontWeight.w700,
              fontSize: compact ? 10 : 10.5,
            ),
          ),
        ],
      ),
    );
  }
}
