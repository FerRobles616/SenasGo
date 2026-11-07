import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:senasgo/core/constants/app_constants.dart';
import 'package:flutter/services.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/practice/domain/sign_evaluation.dart';
import 'package:senasgo/features/practice/domain/sign_reference.dart';
import 'package:senasgo/features/practice/presentation/controllers/practice_controller.dart';
import 'package:senasgo/features/support/presentation/support_actions.dart';

/// Ícono grande de resultado (✓ / ✕) de los estados 9 y 10. Entra con un
/// rebote; el acierto suelta una ráfaga de partículas y el error se sacude.
class ResultIcon extends StatefulWidget {
  const ResultIcon({required this.success, super.key});

  final bool success;

  @override
  State<ResultIcon> createState() => _ResultIconState();
}

class _ResultIconState extends State<ResultIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));

  late final Animation<double> _pop = Tween<double>(begin: 0.4, end: 1).animate(
      CurvedAnimation(
          parent: _anim,
          curve: const Interval(0, 0.6, curve: Curves.elasticOut)));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respeta "reducir animaciones": aparece ya en su lugar.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _anim.value = 1;
    } else if (_anim.isDismissed) {
      _anim.forward();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final success = widget.success;
    final color = success ? AppColors.success : AppColors.error;
    final soft = success ? AppColors.successSoft : AppColors.errorSoft;
    final icon = Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
          color: soft.withValues(alpha: 0.6), shape: BoxShape.circle),
      child: Center(
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
          child:
              Icon(success ? Icons.check : Icons.close, size: 64, color: color),
        ),
      ),
    );
    return Center(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) {
          final t = _anim.value;
          // Sacudida corta de "no" que se apaga a la mitad de la animación.
          final shake = success || t >= 0.5
              ? 0.0
              : math.sin(t * math.pi * 12) * 10 * (1 - t / 0.5);
          return SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (success)
                  Positioned.fill(
                    child: CustomPaint(painter: _BurstPainter(progress: t)),
                  ),
                Transform.translate(
                  offset: Offset(shake, 0),
                  child: Transform.scale(scale: _pop.value, child: child),
                ),
              ],
            ),
          );
        },
        child: icon,
      ),
    );
  }
}

/// Partículas de colores que salen del ícono de acierto y se desvanecen.
class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress});

  final double progress;

  static final _colors = [
    AppColors.success,
    AppColors.gold,
    AppColors.sky,
    AppColors.teal,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeOutCubic
        .transform(((progress - 0.08) / 0.75).clamp(0.0, 1.0));
    if (t <= 0 || t >= 1) return;
    final center = size.center(Offset.zero);
    const count = 14;
    for (var i = 0; i < count; i++) {
      // Ángulo y alcance varían un poco para que no se vea como un reloj.
      final angle = i * 2 * math.pi / count + (i.isEven ? 0.12 : -0.08);
      final reach = 78 + 58 * t + (i % 3) * 8;
      final offset =
          center + Offset(math.cos(angle) * reach, math.sin(angle) * reach);
      final paint = Paint()
        ..color = _colors[i % _colors.length].withValues(alpha: 1 - t);
      canvas.drawCircle(offset, 7 - 4 * t, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Panel inferior del veredicto: sube desde abajo con el resultado junto al
/// botón para seguir, y vibra distinto si es acierto o error.
class VerdictPanel extends StatefulWidget {
  const VerdictPanel({
    required this.success,
    required this.title,
    required this.message,
    required this.child,
    super.key,
  });

  final bool success;
  final String title;
  final String message;

  /// Botones de acción del estado.
  final Widget child;

  @override
  State<VerdictPanel> createState() => _VerdictPanelState();
}

class _VerdictPanelState extends State<VerdictPanel> {
  @override
  void initState() {
    super.initState();
    if (widget.success) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final success = widget.success;
    final color = success ? AppColors.success : AppColors.error;
    final soft = success ? AppColors.successSoft : AppColors.errorSoft;
    // Texto legible sobre el fondo suave en los dos temas.
    final ink = success ? AppColors.successInk : AppColors.errorInk;
    final theme = Theme.of(context);

    final panel = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: soft,
        border: Border(
            top: BorderSide(color: color.withValues(alpha: 0.35), width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(success ? Icons.check_rounded : Icons.close_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.title,
                        style: TextStyle(
                            color: ink,
                            fontSize: 21,
                            fontWeight: FontWeight.w900)),
                    if (widget.message.isNotEmpty)
                      Text(widget.message,
                          style: TextStyle(
                              color: AppColors.ink, fontSize: 14, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // El botón principal toma el color del veredicto.
          Theme(
            data: theme.copyWith(
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  // En oscuro el verde y el rojo son claros: texto oscuro.
                  foregroundColor:
                      AppColors.isDark ? AppColors.navy : Colors.white,
                ).merge(theme.filledButtonTheme.style),
              ),
            ),
            child: widget.child,
          ),
        ],
      ),
    );

    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) return panel;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) =>
          FractionalTranslation(translation: Offset(0, t), child: child),
      child: panel,
    );
  }
}

/// "¡3 seguidas!": aparece desde dos aciertos seguidos y salta al subir.
class ComboChip extends StatelessWidget {
  const ComboChip({required this.combo, super.key});

  final int combo;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 280);
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      child: AnimatedSwitcher(
        duration: duration,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale:
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            child: child,
          ),
        ),
        child: combo < 2
            ? const SizedBox.shrink(key: ValueKey(0))
            : Padding(
                key: ValueKey(combo),
                padding: const EdgeInsets.only(left: 10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.streak.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department_rounded,
                          size: 16, color: AppColors.streak),
                      const SizedBox(width: 4),
                      Text('¡$combo seguidas!',
                          style: const TextStyle(
                              color: Color(0xFFC2410C),
                              fontWeight: FontWeight.w900,
                              fontSize: 13)),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// Estado 9: qué mejorar, en lenguaje cualitativo (sin porcentajes).
class IncorrectFeedback extends StatelessWidget {
  const IncorrectFeedback({required this.state, super.key});

  final PracticeState state;

  @override
  Widget build(BuildContext context) {
    final evaluation = state.evaluation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ResultIcon(success: false),
        const SizedBox(height: 24),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(state.currentSign?.name.toUpperCase() ?? '',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(evaluation?.feedbackHint ?? '',
                  style: TextStyle(color: AppColors.muted, height: 1.4)),
              const SizedBox(height: 14),
              Text(
                'Sin XP nuevos · Tu avance se mantiene en '
                '${state.completedCount} / ${state.totalSigns}.',
                style: TextStyle(color: AppColors.error, fontSize: 13.5),
              ),
            ],
          ),
        ),
        if (evaluation != null) ...[
          const SizedBox(height: 12),
          ParameterChecklist(evaluation: evaluation),
        ],
        const SizedBox(height: 8),
        _SupportLink(
          label: '¿El resultado no coincide con tu seña? Avisanos',
          contextLabel:
              'Resultado incorrecto · ${state.currentSign?.name ?? ''}',
        ),
      ],
    );
  }
}

/// Lista cualitativa de los 5 parámetros: bien / a mejorar / no evaluado.
class ParameterChecklist extends StatelessWidget {
  const ParameterChecklist({required this.evaluation, super.key});

  final SignEvaluation evaluation;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          for (final p in SignParameter.values)
            _row(p, evaluation.parameters[p]),
        ],
      ),
    );
  }

  Widget _row(SignParameter p, ParameterResult? r) {
    final (icon, color, text) = switch (r?.status) {
      ParameterStatus.passed => (
          Icons.check_circle_outline,
          AppColors.success,
          'Bien'
        ),
      ParameterStatus.failed => (
          Icons.cancel_outlined,
          AppColors.error,
          'A mejorar'
        ),
      _ => (Icons.remove_circle_outline, AppColors.muted, 'No evaluado'),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(p.label)),
          Text(text,
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Estado 10: +10 XP y progreso de la sesión.
class CorrectFeedback extends StatelessWidget {
  const CorrectFeedback({required this.state, super.key});

  final PracticeState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ResultIcon(success: true),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            color: AppColors.successSoft,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bolt, color: AppColors.success, size: 34),
              SizedBox(width: 10),
              Text('+${AppConstants.xpPerCorrectSign} XP',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
              SizedBox(width: 12),
              Text('¡Una seña más!',
                  style: TextStyle(color: AppColors.success)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SessionCard(state: state),
        const SizedBox(height: 8),
        _SupportLink(
          label: '¿La evaluación no coincide? Contanos',
          contextLabel: 'Resultado correcto · ${state.currentSign?.name ?? ''}',
        ),
      ],
    );
  }
}

/// Estado 11: cierre de lección con XP e insignia.
class LessonSummary extends StatelessWidget {
  const LessonSummary({required this.state, super.key});

  final PracticeState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Icon(Icons.emoji_events_outlined,
                  color: AppColors.primary, size: 34),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('¡Cada seña te acerca!',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 17)),
                    Text('Insignia lograda: Primera Práctica',
                        style: TextStyle(color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SessionCard(state: state),
        const SizedBox(height: 16),
        for (final s in state.signs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Card(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name.toUpperCase(),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(
                          state.completedIds.contains(s.id)
                              ? 'Completada · +${AppConstants.xpPerCorrectSign} XP'
                              : 'Pendiente',
                          style: TextStyle(
                            color: state.completedIds.contains(s.id)
                                ? AppColors.success
                                : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    state.completedIds.contains(s.id)
                        ? Icons.check_circle_outline
                        : Icons.radio_button_unchecked,
                    color: state.completedIds.contains(s.id)
                        ? AppColors.success
                        : AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        _SupportLink(
          label: '¿Querés comentar esta lección? Escribinos',
          contextLabel: 'Cierre de lección',
        ),
      ],
    );
  }
}

class _SupportLink extends StatelessWidget {
  const _SupportLink({required this.label, required this.contextLabel});

  final String label;
  final String contextLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: () => SupportSheet.show(context, contextLabel: contextLabel),
        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
        label: Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5)),
      ),
    );
  }
}

/// Tarjeta violeta "Tu sesión": XP de la sesión y señas completadas.
class SessionCard extends StatelessWidget {
  const SessionCard({required this.state, super.key});

  final PracticeState state;

  @override
  Widget build(BuildContext context) {
    final pending =
        state.signs.where((s) => !state.completedIds.contains(s.id)).toList();
    final footer = pending.isEmpty
        ? '¡Completaste todas las señas de la lección!'
        : pending.length == 1
            ? '¡Solo te falta ${pending.first.name.toUpperCase()}!'
            : 'Te faltan ${pending.length} señas.';
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('Tu sesión',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              Spacer(),
              Text('Sesión local',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text('${state.sessionXp} XP',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('${state.completedCount} / ${state.totalSigns} señas',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          SegmentedProgress(
            done: state.completedCount,
            total: state.totalSigns,
            doneColor: const Color(0xFFFFE6DC),
            pendingColor: Colors.white24,
          ),
          const SizedBox(height: 14),
          Text(footer, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class SegmentedProgress extends StatelessWidget {
  const SegmentedProgress({
    required this.done,
    required this.total,
    this.doneColor,
    this.pendingColor,
    super.key,
  });

  final int done;
  final int total;
  final Color? doneColor;

  /// Por defecto, el borde del tema (tramo todavía sin completar).
  final Color? pendingColor;

  @override
  Widget build(BuildContext context) {
    final doneColor = this.doneColor ?? AppColors.primary;
    final pendingColor = this.pendingColor ?? AppColors.border;
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            // Cada tramo se llena con una transición al completar la seña.
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              height: 8,
              decoration: BoxDecoration(
                color: i < done ? doneColor : pendingColor,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
