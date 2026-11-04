import 'package:flutter/material.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/shared/widgets/jaguarete_mascot.dart';

/// "¡Esperá!": confirma antes de dejar una lección o un repaso a mitad de
/// camino. Devuelve `true` si la persona elige salir igual.
class ExitLessonDialog extends StatelessWidget {
  const ExitLessonDialog({
    required this.remaining,
    this.singular = 'seña',
    this.plural = 'señas',
    this.goal = 'esta lección',
    super.key,
  });

  final int remaining;
  final String singular;
  final String plural;

  /// Qué se termina: "esta lección", "el repaso"...
  final String goal;

  @override
  Widget build(BuildContext context) {
    final message = remaining <= 0
        ? 'Estás a un toque de terminar $goal.'
        : remaining == 1
            ? 'Te falta 1 $singular para terminar $goal.'
            : 'Te faltan $remaining $plural para terminar $goal.';
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: JaguareteMascot(size: 96, mood: MascotMood.thinking),
            ),
            const SizedBox(height: 14),
            Text('¡Esperá!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15.5, color: AppColors.muted, height: 1.35)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('SEGUIR PRACTICANDO'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Salir igual'),
            ),
          ],
        ),
      ),
    );
  }
}
