import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/shared/widgets/app_nav_icon.dart';

/// Navegación principal: Aprender · Biblioteca · Retos · Progreso · Ayuda.
///
/// La tienda se retiró: todo lo que la app ofrece (lecciones, práctica,
/// retos, progreso y soporte) está pensado para la persona que aprende LSPy.
///
/// Cada sección tiene su color y su icono ilustrado. La pestaña actual se
/// distingue por el icono a color, un halo suave y una escala breve; las demás
/// quedan atenuadas para que la barra no compita con el contenido.
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
    final items = <_NavDestination>[
      _NavDestination(
        asset: 'assets/icons/nav/nav_learn.png',
        fallbackIcon: Icons.home_rounded,
        label: 'Aprender',
        color: AppColors.streak,
      ),
      _NavDestination(
        asset: 'assets/icons/nav/nav_library.png',
        fallbackIcon: Icons.menu_book_rounded,
        label: 'Biblioteca',
        color: AppColors.teal,
      ),
      _NavDestination(
        asset: 'assets/icons/nav/nav_challenges.png',
        fallbackIcon: Icons.emoji_events_rounded,
        label: 'Retos',
        color: AppColors.gold,
      ),
      _NavDestination(
        asset: 'assets/icons/nav/nav_progress.png',
        fallbackIcon: Icons.insights_rounded,
        label: 'Progreso',
        color: AppColors.success,
      ),
      _NavDestination(
        asset: 'assets/icons/nav/nav_help.png',
        fallbackIcon: Icons.support_agent_rounded,
        label: 'Ayuda',
        color: AppColors.heart,
      ),
    ];
    // Hero: todas las pestañas comparten esta barra; durante la transición
    // queda quieta en su lugar en vez de desvanecerse con la pantalla.
    return Hero(
      tag: AppBottomNav.heroTag,
      child: Material(
        type: MaterialType.transparency,
        child: _bar(items, context),
      ),
    );
  }

  static const heroTag = 'app-bottom-nav';

  Widget _bar(List<_NavDestination> items, BuildContext context) {
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
                    destination: items[i],
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

class _NavDestination {
  const _NavDestination({
    required this.asset,
    required this.fallbackIcon,
    required this.label,
    required this.color,
  });

  final String asset;
  final IconData fallbackIcon;
  final String label;
  final Color color;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 200);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final compact = MediaQuery.sizeOf(context).width < 350;
    final accent = destination.color;
    final haloAlpha = selected ? (isDark ? 0.20 : 0.12) : 0.0;
    final labelStyle = DefaultTextStyle.of(context).style.copyWith(
          fontSize: compact ? 10.6 : 11.5,
          height: 1.05,
          fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
          color: selected ? AppColors.ink : AppColors.muted,
        );

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 38,
        splashColor: accent.withValues(alpha: 0.14),
        highlightColor: accent.withValues(alpha: 0.08),
        hoverColor: accent.withValues(alpha: 0.06),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: duration,
              curve: Curves.easeOutCubic,
              width: 56,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: haloAlpha),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? accent.withValues(alpha: isDark ? 0.38 : 0.26)
                      : Colors.transparent,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(
                      alpha: selected ? (isDark ? 0.22 : 0.10) : 0.0,
                    ),
                    blurRadius: selected ? 16 : 0,
                    spreadRadius: selected ? 1 : 0,
                  ),
                ],
              ),
              child: Center(
                child: AppNavIcon(
                  asset: destination.asset,
                  fallbackIcon: destination.fallbackIcon,
                  selected: selected,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: duration,
              curve: Curves.easeOutCubic,
              style: labelStyle,
              child: Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
