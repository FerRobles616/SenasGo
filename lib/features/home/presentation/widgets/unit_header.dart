import 'package:flutter/material.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/home/domain/learning_path.dart';
import 'package:senasgo/shared/widgets/pushable_button.dart';

/// Cabecera de cada unidad: etapa, título, progreso y acceso a la guía.
///
/// La franja de progreso es la misma que usa la persona para saber cuánto le
/// falta antes de llegar al cofre de la unidad.
class UnitHeader extends StatelessWidget {
  const UnitHeader({required this.unit, required this.onGuide, super.key});

  final PathUnit unit;
  final VoidCallback onGuide;

  @override
  Widget build(BuildContext context) {
    final palette = unit.isLocked
        ? UnitPalette(AppColors.lockedShade,
            AppColors.isDark ? AppColors.navy : const Color(0xFFA8A8A8))
        : UnitPalette.of(unit.index);
    final total = unit.nodes.length;
    final done = unit.completedCount;
    final fraction = total == 0 ? 0.0 : done / total;

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
                PushableButton(
                  onPressed: onGuide,
                  color: Colors.white.withValues(alpha: 0.18),
                  shadowColor: palette.shade,
                  width: 62,
                  height: 58,
                  depth: 4,
                  borderRadius: 17,
                  semanticLabel: 'Ver la guía de ${unit.lesson.title}',
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book_rounded,
                          color: Colors.white, size: 23),
                      Text(
                        'GUÍA',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 10.5,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
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
            ),
          ],
        ),
      ),
    );
  }
}
