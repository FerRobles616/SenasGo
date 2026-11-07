import 'package:flutter/material.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/home/domain/learning_path.dart';
import 'package:senasgo/shared/widgets/jaguarete_mascot.dart';
import 'package:senasgo/shared/widgets/pushable_button.dart';

/// Cabecera de cada unidad.
///
/// La unidad actual se convierte en una tarjeta protagonista: muestra la
/// próxima seña, el progreso, la guía y una sola acción principal. Las demás
/// unidades conservan una cabecera compacta para no competir con el camino.
class UnitHeader extends StatelessWidget {
  const UnitHeader({
    required this.unit,
    required this.onGuide,
    this.currentSign,
    this.onStart,
    super.key,
  });

  final PathUnit unit;
  final VoidCallback onGuide;

  /// Si esta es la unidad actual, la seña que toca practicar.
  final PathNode? currentSign;

  /// Acción principal de la seña actual.
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final palette = unit.isLocked
        ? UnitPalette(AppColors.lockedShade,
            AppColors.isDark ? AppColors.navy : const Color(0xFFA8A8A8))
        : UnitPalette.of(unit.index);
    final total = unit.nodes.length;
    final done = unit.completedCount;
    final fraction = total == 0 ? 0.0 : done / total;

    if (currentSign != null && onStart != null) {
      return _CurrentLessonHeader(
        unit: unit,
        sign: currentSign!,
        palette: palette,
        fraction: fraction,
        done: done,
        total: total,
        onStart: onStart!,
        onGuide: onGuide,
      );
    }

    return Semantics(
      container: true,
      label:
          'Unidad ${unit.index + 1}: ${unit.lesson.title}. $done de $total señas completadas.',
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
        decoration: BoxDecoration(
          color: palette.face,
          borderRadius: BorderRadius.circular(22),
          border: Border(bottom: BorderSide(color: palette.shade, width: 5)),
          boxShadow: [
            BoxShadow(
              color: palette.face.withValues(alpha: 0.22),
              blurRadius: 20,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ETAPA ${unit.index + 1} · SECCIÓN ${unit.index + 1}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w900,
                          fontSize: 11.5,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        unit.lesson.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        unit.lesson.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _GuideButton(onGuide: onGuide, palette: palette),
              ],
            ),
            const SizedBox(height: 14),
            _ProgressLine(fraction: fraction, done: done, total: total),
          ],
        ),
      ),
    );
  }
}

class _CurrentLessonHeader extends StatelessWidget {
  const _CurrentLessonHeader({
    required this.unit,
    required this.sign,
    required this.palette,
    required this.fraction,
    required this.done,
    required this.total,
    required this.onStart,
    required this.onGuide,
  });

  final PathUnit unit;
  final PathNode sign;
  final UnitPalette palette;
  final double fraction;
  final int done;
  final int total;
  final VoidCallback onStart;
  final VoidCallback onGuide;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Próxima seña: ${sign.sign.name}. Unidad ${unit.lesson.title}. '
          '$done de $total señas completadas.',
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
        decoration: BoxDecoration(
          color: palette.face,
          borderRadius: BorderRadius.circular(22),
          border: Border(bottom: BorderSide(color: palette.shade, width: 5)),
          boxShadow: [
            BoxShadow(
              color: palette.face.withValues(alpha: 0.22),
              blurRadius: 20,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TU PRÓXIMA SEÑA',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w900,
                          fontSize: 10.5,
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sign.sign.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 27,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${unit.lesson.title} · $done/$total',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  label: 'Jaguareté dice: ¡Vamos con ${sign.sign.name}!',
                  excludeSemantics: true,
                  child: JaguareteMascot(
                    size: 54,
                    mood: MascotMood.cheering,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ProgressLine(fraction: fraction, done: done, total: total),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: PushableButton(
                    onPressed: onStart,
                    color: Colors.white,
                    shadowColor: palette.shade,
                    height: 48,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'EMPEZAR',
                          style: TextStyle(
                            color: palette.shade,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Icon(Icons.arrow_forward_rounded,
                            color: palette.shade, size: 19),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _GuideButton(onGuide: onGuide, palette: palette, compact: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideButton extends StatelessWidget {
  const _GuideButton({
    required this.onGuide,
    required this.palette,
    this.compact = false,
  });

  final VoidCallback onGuide;
  final UnitPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return PushableButton(
      onPressed: onGuide,
      color: Colors.white.withValues(alpha: 0.18),
      shadowColor: palette.shade,
      width: compact ? 54 : 62,
      height: compact ? 48 : 58,
      depth: 4,
      borderRadius: 17,
      semanticLabel: 'Ver la guía de la lección',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_rounded,
              color: Colors.white, size: compact ? 20 : 23),
          Text(
            'GUÍA',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: compact ? 9.5 : 10.5,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({
    required this.fraction,
    required this.done,
    required this.total,
  });

  final double fraction;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction),
              duration: MediaQuery.maybeDisableAnimationsOf(context) ?? false
                  ? Duration.zero
                  : const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$done/$total',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
