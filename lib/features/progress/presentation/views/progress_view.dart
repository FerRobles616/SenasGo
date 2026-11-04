import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:senasgo/core/constants/app_constants.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/home/domain/learning_path.dart';
import 'package:senasgo/features/support/presentation/support_actions.dart';
import 'package:senasgo/shared/models/practice_attempt.dart';
import 'package:senasgo/shared/models/progress_model.dart';
import 'package:senasgo/shared/models/user_model.dart';
import 'package:senasgo/shared/widgets/app_bottom_nav.dart';
import 'package:senasgo/shared/widgets/pushable_button.dart';

/// Pantalla de progreso: nivel, racha, precisión y avance por lección.
/// Reemplaza a la tienda con información útil para la persona que aprende.
class ProgressView extends StatefulWidget {
  const ProgressView({super.key});

  @override
  State<ProgressView> createState() => _ProgressViewState();
}

class _ProgressViewState extends State<ProgressView> {
  late UserModel _user = HiveService.currentUser;
  late ProgressModel _progress = HiveService.progress;
  late LearningPath _path = LearningPath.fromStorage();
  late List<PracticeAttempt> _attempts = HiveService.recentAttempts;

  void _reload() {
    setState(() {
      _user = HiveService.currentUser;
      _progress = HiveService.progress;
      _path = LearningPath.fromStorage();
      _attempts = HiveService.recentAttempts;
    });
  }

  Future<void> _practice() async {
    final current = _path.current;
    if (current == null) {
      await context.push('/library');
      if (mounted) _reload();
      return;
    }
    await context
        .push('/practice?lesson=${current.lessonId}&sign=${current.sign.id}');
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final level = _user.level;
    final nextXp = HiveService.xpToNextLevel(_user.xp);
    final base = HiveService.xpForLevel(level);
    final nextBase = nextXp == null ? _user.xp : _user.xp + nextXp;
    final levelFraction = nextXp == null
        ? 1.0
        : ((_user.xp - base) / (nextBase - base)).clamp(0.0, 1.0);
    final learned = _progress.completedSignIds.length;
    final totalSigns = HiveService.signsOfAll.length;
    final accuracy = _progress.accuracy;

    return Scaffold(
      appBar: AppBar(
        // Pestaña raíz: sin flecha aunque Aprender la abra con push.
        automaticallyImplyLeading: false,
        title: const Text('Mi progreso'),
        actions: [
          IconButton(
            tooltip: 'Ayuda y comentarios',
            onPressed: () => SupportSheet.show(context,
                contextLabel: 'Pantalla de progreso'),
            icon: const Icon(Icons.support_agent_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _LevelCard(
            level: level,
            xp: _user.xp,
            fraction: levelFraction,
            nextXp: nextXp,
          ),
          const SizedBox(height: 16),
          _StatsGrid(
            streak: HiveService.streak,
            hearts: HiveService.hearts,
            learned: learned,
            totalSigns: totalSigns,
            accuracy: accuracy,
          ),
          const SizedBox(height: 22),
          const _SectionTitle('Actividad reciente'),
          const SizedBox(height: 8),
          _WeekBars(attempts: _attempts),
          const SizedBox(height: 22),
          const _SectionTitle('Avance por lección'),
          const SizedBox(height: 8),
          for (final unit in _path.units) ...[
            _LessonProgress(
              title: unit.lesson.title,
              done: unit.completedCount,
              total: unit.nodes.length,
              palette: UnitPalette.of(unit.index),
              onTap: () => context.push('/lesson/${unit.lesson.id}'),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
          const _SectionTitle('Últimos intentos'),
          const SizedBox(height: 8),
          if (_attempts.isEmpty)
            const _EmptyAttempts()
          else
            for (final attempt in _attempts.take(6)) ...[
              _AttemptRow(attempt: attempt),
              const SizedBox(height: 7),
            ],
          const SizedBox(height: 20),
          PushableButton(
            onPressed: _practice,
            color: AppColors.primary,
            shadowColor: const Color(0xFF1D4ED8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    _path.current == null
                        ? Icons.menu_book_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  _path.current == null
                      ? 'EXPLORAR LA BIBLIOTECA'
                      : 'PRACTICAR ${_path.current!.sign.name.toUpperCase()}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.3),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.xp,
    required this.fraction,
    required this.nextXp,
  });

  final int level;
  final int xp;
  final double fraction;
  final int? nextXp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.24),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45), width: 2),
                ),
                child: Center(
                  child: Text('$level',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nivel $level',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900)),
                    Text(
                      nextXp == null
                          ? '¡Llegaste al nivel máximo!'
                          : 'Te faltan $nextXp XP para el nivel ${level + 1}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.bolt_rounded,
                  color: Color(0xFFFFD86B), size: 30),
              Text('$xp XP',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 11,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFFFE6A6)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            nextXp == null
                ? 'Seguí repasando para no perder lo aprendido.'
                : 'Cada seña correcta suma +${AppConstants.xpPerCorrectSign} XP.',
            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.streak,
    required this.hearts,
    required this.learned,
    required this.totalSigns,
    required this.accuracy,
  });

  final int streak;
  final int hearts;
  final int learned;
  final int totalSigns;
  final double accuracy;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = (box.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _StatCard(
              width: width,
              icon: Icons.local_fire_department_rounded,
              color: AppColors.streak,
              value: '$streak',
              label: streak == 1 ? 'día de racha' : 'días de racha',
            ),
            _StatCard(
              width: width,
              icon: Icons.favorite_rounded,
              color: AppColors.heart,
              value: '$hearts/${AppConstants.maxHearts}',
              label: 'vidas',
            ),
            _StatCard(
              width: width,
              icon: Icons.sign_language_rounded,
              color: AppColors.primary,
              value: '$learned',
              label: 'aprendidas',
              hint: 'de $totalSigns',
            ),
            _StatCard(
              width: width,
              icon: Icons.track_changes_rounded,
              color: AppColors.success,
              value: '${(accuracy * 100).round()}%',
              label: 'precisión',
              hint: '${HiveService.progress.correctAttempts} aciertos',
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.width,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.hint,
  });

  final double width;
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    // En 320 px las tarjetas de dos columnas quedan muy angostas: achicar
    // icono y padding evita que "días de racha" y los aciertos se corten.
    final compact = width < 150;
    return Container(
      width: width,
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 34 : 40,
            height: compact ? 34 : 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: compact ? 18 : 21),
          ),
          SizedBox(width: compact ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(value,
                        style: TextStyle(
                            fontSize: compact ? 18 : 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink)),
                    if (hint != null && !compact) ...[
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(hint!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppColors.muted, fontSize: 10.5)),
                      ),
                    ],
                  ],
                ),
                Text(label,
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.muted,
                        fontSize: compact ? 10.5 : 11.5,
                        height: compact ? 1.1 : null,
                        fontWeight: FontWeight.w600)),
                if (hint != null && compact)
                  Text(hint!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.muted, fontSize: 9.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.attempts});

  final List<PracticeAttempt> attempts;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = [
      for (var i = 6; i >= 0; i--)
        DateTime(now.year, now.month, now.day).subtract(Duration(days: i)),
    ];
    final counts = [
      for (final day in days)
        attempts
            .where((a) =>
                a.at.year == day.year &&
                a.at.month == day.month &&
                a.at.day == day.day)
            .length,
    ];
    final maxCount = counts.fold<int>(1, (m, c) => c > m ? c : m);
    const labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          SizedBox(
            // Número + barra máxima (56) + día: con 92 px se desbordaba.
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < days.length; i++)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (counts[i] > 0)
                          Text('${counts[i]}',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary)),
                        const SizedBox(height: 3),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          height: 8 + (counts[i] / maxCount) * 48,
                          margin: const EdgeInsets.symmetric(horizontal: 7),
                          decoration: BoxDecoration(
                            color: counts[i] == 0
                                ? AppColors.primarySoft
                                : AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(labels[days[i].weekday - 1],
                            style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            attempts.isEmpty
                ? 'Todavía no hay intentos. ¡Empezá con una seña!'
                : 'Intentos de los últimos 7 días',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _LessonProgress extends StatelessWidget {
  const _LessonProgress({
    required this.title,
    required this.done,
    required this.total,
    required this.palette,
    required this.onTap,
  });

  final String title;
  final int done;
  final int total;
  final UnitPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : done / total;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: palette.face.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.menu_book_rounded,
                    color: palette.face, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink)),
                        ),
                        Text('$done/$total',
                            style: TextStyle(
                                color: palette.face,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5)),
                      ],
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 7,
                        backgroundColor: AppColors.primarySoft,
                        valueColor: AlwaysStoppedAnimation(palette.face),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttemptRow extends StatelessWidget {
  const _AttemptRow({required this.attempt});

  final PracticeAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final sign = HiveService.signById(attempt.signId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            attempt.correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: attempt.correct ? AppColors.success : AppColors.error,
            size: 22,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              sign?.name ?? attempt.signId,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  fontSize: 13.5),
            ),
          ),
          Text(_relative(attempt.at),
              style: TextStyle(color: AppColors.muted, fontSize: 11.5)),
        ],
      ),
    );
  }

  static String _relative(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'ayer';
    return 'hace ${diff.inDays} días';
  }
}

class _EmptyAttempts extends StatelessWidget {
  const _EmptyAttempts();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_empty_rounded, color: AppColors.muted),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cuando practiques, acá vas a ver tus últimos intentos.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: TextStyle(
            fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.ink));
  }
}
