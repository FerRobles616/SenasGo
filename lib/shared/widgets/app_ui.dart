import 'package:flutter/material.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/shared/widgets/app_feature_icon.dart';

/// Título de sección con subtítulo opcional y acción a la derecha.
class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle(
    this.title, {
    this.subtitle,
    this.trailing,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Tarjeta blanca redondeada con borde azul muy suave.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.onTap,
    this.borderRadius = 22,
    this.boxShadow,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Por defecto, la superficie del tema activo.
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  final double borderRadius;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? AppColors.surface;
    final borderColor = this.borderColor ?? AppColors.border;
    final radius = BorderRadius.circular(borderRadius);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(color: borderColor),
        boxShadow: boxShadow,
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: content,
      ),
    );
  }
}

/// Chip compacto con icono, usado para categorías y estados.
class AppPill extends StatelessWidget {
  const AppPill({
    required this.icon,
    required this.label,
    this.color,
    this.background,
    this.iconSize = 15,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final Color? background;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Icono cuadrado con fondo suave; da ritmo visual a las listas.
class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    required this.icon,
    this.asset,
    required this.color,
    this.size = 46,
    this.radius = 15,
    super.key,
  });

  final IconData icon;

  /// Si se indica, se muestra el icono ilustrado en lugar del de Material.
  final String? asset;

  final Color color;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: asset == null
            ? Icon(icon, color: color, size: size * 0.48)
            : AppFeatureIcon(
                asset: asset!,
                fallbackIcon: icon,
                color: color,
                size: size * 0.62,
              ),
      ),
    );
  }
}

/// Barra de progreso redondeada con valor animado.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    required this.value,
    this.color,
    this.background,
    this.height = 9,
    super.key,
  });

  final double value;
  final Color? color;
  final Color? background;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? AppColors.primary;
    final background = this.background ?? AppColors.primarySoft;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
        backgroundColor: background,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

/// Estado vacío amable, con una acción clara.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          AppIconBadge(icon: icon, color: AppColors.primary, size: 54),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Encabezado degradado azul que usan las pantallas nuevas.
class AppHeroHeader extends StatelessWidget {
  const AppHeroHeader({
    required this.child,
    this.colors,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 28,
    super.key,
  });

  final Widget child;

  /// Por defecto, el degradado azul → celeste del tema activo.
  final List<Color>? colors;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = this.colors ?? [AppColors.primary, AppColors.sky];
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.26),
            blurRadius: 24,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: child,
    );
  }
}
