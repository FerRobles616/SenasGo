import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:senasgo/core/theme/app_theme.dart';

/// Navegación principal: Aprender · Biblioteca · Retos · Progreso · Ayuda.
///
/// La tienda se retiró: todo lo que la app ofrece (lecciones, práctica,
/// retos, progreso y soporte) está pensado para la persona que aprende LSPy.
///
/// Cada sección tiene su color (siempre visible, también sin seleccionar) y
/// la actual se marca con una baldosa redondeada de ese color.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.currentIndex,
    this.onSelected,
    super.key,
  });

  final int currentIndex;

  /// Permite refrescar la pantalla al volver (por ejemplo, el camino).
  final ValueChanged<int>? onSelected;

  static const _routes = ['/', '/library', '/challenges', '/progress', '/help'];

  void _go(BuildContext context, int i) {
    if (i == currentIndex) return;
    if (onSelected != null) {
      onSelected!(i);
    } else {
      context.go(_routes[i]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_rounded, 'Aprender', AppColors.primary),
      (Icons.menu_book_rounded, 'Biblioteca', AppColors.teal),
      (Icons.emoji_events_rounded, 'Retos', AppColors.gold),
      (Icons.insights_rounded, 'Progreso', AppColors.indigo),
      (Icons.support_agent_rounded, 'Ayuda', AppColors.heart),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1.2)),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: AppColors.isDark ? 0.3 : 0.07),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: items[i].$1,
                    label: items[i].$2,
                    color: items[i].$3,
                    selected: i == currentIndex,
                    onTap: () => _go(context, i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 220);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: duration,
              curve: Curves.easeOutCubic,
              width: 54,
              height: 38,
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: AppColors.isDark ? 0.18 : 0.13)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? color : Colors.transparent,
                  width: 2,
                ),
              ),
              child: AnimatedScale(
                duration: duration,
                curve: Curves.easeOutBack,
                scale: selected ? 1.1 : 1,
                child: Icon(
                  icon,
                  size: 25,
                  color: selected ? color : color.withValues(alpha: 0.7),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                color: selected ? color : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
