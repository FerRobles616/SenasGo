import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:senasgo/core/constants/app_constants.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/home/domain/learning_path.dart';
import 'package:senasgo/features/support/presentation/support_actions.dart';
import 'package:senasgo/shared/widgets/app_bottom_nav.dart';
import 'package:senasgo/shared/widgets/app_ui.dart';
import 'package:senasgo/shared/widgets/jaguarete_mascot.dart';
import 'package:senasgo/shared/widgets/pushable_button.dart';

/// Calendario de racha y protectores.
///
/// La racha no es una obligación: es una forma amable de recordar que unos
/// minutos por día alcanzan. Si un día se escapa, los protectores evitan
/// empezar de cero.
class StreakView extends StatefulWidget {
  const StreakView({super.key});

  @override
  State<StreakView> createState() => _StreakViewState();
}

class _StreakViewState extends State<StreakView> {
  late int _streak = HiveService.streak;
  late int _best = HiveService.bestStreak;
  late int _freezes = HiveService.streakFreezes;
  late List<DateTime> _days = HiveService.practiceDays;

  Future<void> _practice() async {
    final path = LearningPath.fromStorage();
    final current = path.current;
    if (current == null) {
      await context.push('/library');
    } else {
      await context.push(
        '/practice?lesson=${current.lessonId}&sign=${current.sign.id}',
      );
    }
    if (!mounted) return;
    setState(() {
      _streak = HiveService.streak;
      _best = HiveService.bestStreak;
      _freezes = HiveService.streakFreezes;
      _days = HiveService.practiceDays;
    });
  }

  @override
  Widget build(BuildContext context) {
    final todayDone = HiveService.practicedToday;
    final compact = MediaQuery.sizeOf(context).width < 360;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi racha'),
        actions: [
          IconButton(
            tooltip: 'Ayuda y comentarios',
            onPressed: () =>
                SupportSheet.show(context, contextLabel: 'Pantalla de racha'),
            icon: const Icon(Icons.support_agent_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          AppHeroHeader(
            colors: const [Color(0xFFC2410C), Color(0xFFD97706)],
            child: Row(
              children: [
                Container(
                  width: compact ? 66 : 82,
                  height: compact ? 66 : 82,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.17),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.32),
                      width: 2,
                    ),
                  ),
                  child: Icon(Icons.local_fire_department_rounded,
                      color: Colors.white, size: compact ? 40 : 50),
                ),
                SizedBox(width: compact ? 10 : 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_streak',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: compact ? 40 : 48,
                          height: 0.9,
                        ),
                      ),
                      Text(
                        'días de racha',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: compact ? 15 : 17,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        todayDone
                            ? '¡Hoy ya practicaste!'
                            : 'Practicá una seña hoy para mantenerla.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                          fontSize: compact ? 11.5 : 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                JaguareteMascot(
                  size: compact ? 48 : 62,
                  mood: MascotMood.cheering,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.emoji_events_rounded,
                  color: AppColors.gold,
                  value: '$_best',
                  label: 'mejor racha',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  icon: Icons.shield_rounded,
                  color: AppColors.primary,
                  value: '$_freezes',
                  label: 'protectores',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const AppSectionTitle(
            'Esta semana',
            subtitle: 'Los días en que practicaste al menos una seña.',
          ),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
            child: _WeekStrip(days: _days),
          ),
          const SizedBox(height: 20),
          const AppSectionTitle(
            'Calendario',
            subtitle: 'Tu constancia, mes a mes.',
          ),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            child: _MonthCalendar(days: _days),
          ),
          const SizedBox(height: 20),
          AppCard(
            padding: const EdgeInsets.all(16),
            color: AppColors.primarySoft,
            borderColor: AppColors.primarySoft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_rounded, color: AppColors.primary, size: 26),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _freezes > 0
                            ? 'Tenés $_freezes protectores de racha'
                            : 'Tus protectores están en cero',
                        style: TextStyle(
                          color: AppColors.primaryDeep,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Si un día no podés practicar, un protector evita que '
                        'la racha vuelva a cero. Se usan solos al día siguiente.',
                        style: TextStyle(
                          color: AppColors.primaryDeep,
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
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AppIconBadge(
                  icon: Icons.timer_outlined,
                  color: AppColors.teal,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tu meta diaria',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                        ),
                      ),
                      Text(
                        '${HiveService.dailyGoalMinutes} minutos por día',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/profile'),
                  child: const Text('Cambiar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PushableButton(
            onPressed: _practice,
            color: AppColors.primary,
            shadowColor: AppColors.primaryDark,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_arrow_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  todayDone ? 'SEGUIR PRACTICANDO' : 'PRACTICAR AHORA',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Meta: ${AppConstants.defaultDailyGoalMinutes} min recomendados · '
            'tu progreso se guarda solo en este teléfono.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      child: Row(
        children: [
          AppIconBadge(icon: icon, color: color, size: 38, radius: 12),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 21,
                    height: 1,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.days});

  final List<DateTime> days;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final week = [
      for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i)),
    ];
    const labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final practiced = days.map(_dayKey).toSet();
    return Row(
      children: [
        for (final day in week)
          Expanded(
            child: Column(
              children: [
                Text(
                  labels[day.weekday - 1],
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: practiced.contains(_dayKey(day))
                        ? AppColors.streak
                        : AppColors.surfaceAlt,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _sameDay(day, today)
                          ? AppColors.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    practiced.contains(_dayKey(day))
                        ? Icons.local_fire_department_rounded
                        : Icons.remove_rounded,
                    color: practiced.contains(_dayKey(day))
                        ? Colors.white
                        : AppColors.lockedInk,
                    size: 17,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({required this.days});

  final List<DateTime> days;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final leading = first.weekday - 1;
    final practiced = days.map(_dayKey).toSet();
    const labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    return Column(
      children: [
        Text(
          _monthName(now.month),
          style: TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final label in labels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w800,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: leading + daysInMonth,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            if (index < leading) return const SizedBox.shrink();
            final day = DateTime(now.year, now.month, index - leading + 1);
            final active = practiced.contains(_dayKey(day));
            final isToday = _sameDay(day, now);
            return Container(
              decoration: BoxDecoration(
                color: active ? AppColors.streak.withValues(alpha: 0.14) : null,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isToday ? AppColors.primary : Colors.transparent,
                  width: 1.6,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      color: active ? AppColors.streak : AppColors.muted,
                      fontWeight:
                          active || isToday ? FontWeight.w900 : FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                  if (active)
                    Positioned(
                      bottom: 3,
                      child: Icon(Icons.local_fire_department_rounded,
                          color: AppColors.streak, size: 9),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.streak,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'Día con práctica',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 1.5),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'Hoy',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _dayKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _monthName(int month) => const [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ][month - 1];
