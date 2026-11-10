import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/support/domain/support_ticket.dart';

/// Hoja rápida para pedir ayuda sin perder el contexto de la lección.
class SupportSheet extends StatelessWidget {
  const SupportSheet({this.contextLabel, super.key});

  final String? contextLabel;

  static Future<void> show(BuildContext context, {String? contextLabel}) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SupportSheet(contextLabel: contextLabel),
    );
  }

  void _open(BuildContext sheetContext, SupportCategory category) {
    final router = GoRouter.of(sheetContext);
    Navigator.of(sheetContext).pop();
    router.push(
      '/support?category=${category.name}'
      '${contextLabel == null ? '' : '&context=${Uri.encodeComponent(contextLabel!)}'}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.locked,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('¿Cómo podemos ayudarte?',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink)),
            const SizedBox(height: 6),
            Text(
              'Tu mensaje le llega directo al equipo de soporte.',
              style: TextStyle(color: AppColors.muted, fontSize: 14.5),
            ),
            const SizedBox(height: 16),
            _Option(
              icon: Icons.bug_report_outlined,
              title: 'Reportar un problema',
              subtitle: 'La cámara, el 3D o una pantalla no funciona.',
              onTap: () => _open(context, SupportCategory.bug),
            ),
            _Option(
              icon: Icons.lightbulb_outline_rounded,
              title: 'Sugerir una mejora',
              subtitle: 'Contanos qué haría más fácil aprender.',
              onTap: () => _open(context, SupportCategory.idea),
            ),
            _Option(
              icon: Icons.sign_language_outlined,
              title: 'Revisar una seña o texto',
              subtitle: 'Una demostración o explicación para corregir.',
              onTap: () => _open(context, SupportCategory.content),
            ),
            _Option(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Dejar un comentario',
              subtitle: 'Tu experiencia usando SeñasGo.',
              onTap: () => _open(context, SupportCategory.comment),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.push('/help');
              },
              icon: const Icon(Icons.help_outline_rounded),
              label: const Text('Ver preguntas frecuentes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                              color: AppColors.ink)),
                      Text(subtitle,
                          style: TextStyle(
                              color: AppColors.muted, fontSize: 12.5)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
