import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/support/presentation/support_actions.dart';
import 'package:senasgo/shared/widgets/app_feature_icon.dart';
import 'package:senasgo/shared/widgets/app_ui.dart';
import 'package:senasgo/shared/widgets/jaguarete_mascot.dart';
import 'package:senasgo/shared/widgets/pushable_button.dart';

/// Guía para tener SeñasGo a un toque desde el lanzador del teléfono.
///
/// No prometemos un widget nativo que la app todavía no incluye. El acceso
/// directo sí funciona en Android y es una alternativa honesta y offline.
class HomeShortcutView extends StatelessWidget {
  const HomeShortcutView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acceso rápido'),
        actions: [
          IconButton(
            tooltip: 'Ayuda y comentarios',
            onPressed: () =>
                SupportSheet.show(context, contextLabel: 'Acceso rápido'),
            icon: AppFeatureIcon(
              asset: AppFeatureAssets.help,
              fallbackIcon: Icons.support_agent_rounded,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          AppHeroHeader(
            colors: [Color(0xFF0B3B2E), AppColors.primary, Color(0xFF115E59)],
            child: Row(
              children: [
                const JaguareteMascot(size: 74, mood: MascotMood.thinking),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tené SeñasGo a mano',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Un acceso directo en tu pantalla de inicio te recuerda '
                        'practicar sin buscar la app.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
              children: [
                const _PhoneMock(),
                const SizedBox(height: 14),
                Text(
                  'Mantené presionado el ícono de SeñasGo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'En la mayoría de los teléfonos Android aparece la opción '
                  '"Añadir a pantalla de inicio" o "Acceso rápido".',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const AppSectionTitle(
            'Paso a paso',
            subtitle: 'Depende un poco del modelo de tu teléfono.',
          ),
          const SizedBox(height: 10),
          const _ShortcutStep(
            number: '1',
            icon: Icons.touch_app_rounded,
            title: 'Mantené presionado',
            text:
                'Buscá SeñasGo en tu pantalla de inicio y mantené el dedo sobre el ícono.',
          ),
          const SizedBox(height: 8),
          const _ShortcutStep(
            number: '2',
            icon: Icons.add_to_home_screen_rounded,
            asset: AppFeatureAssets.access,
            title: 'Elegí el acceso directo',
            text:
                'Tocá "Añadir a pantalla de inicio" o "Acceso rápido" en el menú.',
          ),
          const SizedBox(height: 8),
          const _ShortcutStep(
            number: '3',
            icon: Icons.offline_bolt_rounded,
            title: 'Practicá sin buscar',
            text: 'El acceso abre SeñasGo directo. Las lecciones siguen '
                'funcionando aunque no tengas internet.',
          ),
          const SizedBox(height: 20),
          AppCard(
            padding: const EdgeInsets.all(15),
            color: AppColors.primarySoft,
            borderColor: AppColors.primarySoft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppFeatureIcon(
                  asset: AppFeatureAssets.info,
                  fallbackIcon: Icons.info_outline_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'SeñasGo no incluye todavía un widget nativo. Este acceso '
                    'directo usa el lanzador de tu teléfono y no necesita '
                    'conexión ni permisos especiales.',
                    style: TextStyle(
                      color: AppColors.primaryDeep.withValues(alpha: 0.92),
                      fontSize: 12.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PushableButton(
            onPressed: () => context.pop(),
            color: AppColors.primary,
            shadowColor: AppColors.primaryDark,
            child: const Text(
              'ENTENDIDO',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 5),
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Ir a mi camino'),
          ),
        ],
      ),
    );
  }
}

class _ShortcutStep extends StatelessWidget {
  const _ShortcutStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.text,
    this.asset,
  });

  final String number;
  final IconData icon;
  final String? asset;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              AppIconBadge(
                icon: icon,
                asset: asset,
                color: AppColors.primary,
                size: 44,
                radius: 14,
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      number,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneMock extends StatelessWidget {
  const _PhoneMock();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 214,
      height: 280,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF071A16),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF334155), width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: GridView.count(
              crossAxisCount: 4,
              mainAxisSpacing: 9,
              crossAxisSpacing: 9,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < 8; i++)
                  _MockApp(
                    selected: i == 5,
                    color: [
                      Color(0xFF64748B),
                      Color(0xFF475569),
                      Color(0xFF334155),
                      Color(0xFF0D9488),
                      Color(0xFF14B8A6),
                      AppColors.primary,
                      Color(0xFF14B8A6),
                      Color(0xFFF59E0B),
                    ][i],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MockApp extends StatelessWidget {
  const _MockApp({required this.selected, required this.color});

  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected ? color : color.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(11),
        border: selected ? Border.all(color: Colors.white, width: 2) : null,
        boxShadow: selected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: selected
          ? const Icon(Icons.sign_language_rounded,
              color: Colors.white, size: 19)
          : null,
    );
  }
}
