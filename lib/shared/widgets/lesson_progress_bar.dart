import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:senasgo/core/theme/app_theme.dart';

/// Barra de progreso gruesa de una lección o repaso, con un brillo arriba;
/// avanza con una transición cada vez que se completa un paso.
class LessonProgressBar extends StatelessWidget {
  const LessonProgressBar({
    required this.done,
    required this.total,
    this.unitLabel = 'señas',
    super.key,
  });

  final int done;
  final int total;

  /// Para el lector de pantalla: "2 de 3 señas completadas".
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      label: '$done de $total $unitLabel completadas',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: fraction),
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => Container(
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            // Un mínimo visible para que el primer avance se note.
            widthFactor: value == 0 ? 0 : math.max(value, 0.06),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.fromLTRB(8, 3, 8, 0),
              alignment: Alignment.topCenter,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
