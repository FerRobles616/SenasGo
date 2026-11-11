import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/support/presentation/support_actions.dart';
import 'package:senasgo/shared/models/sign_model.dart';
import 'package:senasgo/shared/widgets/app_feature_icon.dart';
import 'package:senasgo/shared/widgets/app_ui.dart';
import 'package:senasgo/shared/widgets/jaguarete_mascot.dart';
import 'package:senasgo/shared/widgets/pushable_button.dart';

/// Detalle de una lección: qué se aprende, cuánto falta y cómo se enseña.
///
/// Es la pantalla intermedia entre el camino y la clase 3D. Evita que tocar
/// una unidad lance de golpe una práctica sin contexto.
class LessonGuideView extends StatelessWidget {
  const LessonGuideView({required this.lessonId, super.key});

  final String lessonId;

  @override
  Widget build(BuildContext context) {
    final lesson = HiveService.lessonsBox.get(lessonId);
    if (lesson == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lección')),
        body: const Center(child: Text('No encontramos esta lección.')),
      );
    }
    final index = HiveService.lessons.indexWhere((l) => l.id == lesson.id);
    final palette = UnitPalette.of(index < 0 ? 0 : index);
    final signs = HiveService.signsOf(lesson.id);
    final learned = HiveService.learnedSignIds;
    final done = signs.where((s) => learned.contains(s.id)).length;
    final total = signs.length;
    final fraction = total == 0 ? 0.0 : done / total;

    return Scaffold(
      appBar: AppBar(
        title: Text(lesson.title),
        actions: [
          IconButton(
            tooltip: 'Ayuda y comentarios',
            onPressed: () => SupportSheet.show(context,
                contextLabel: 'Guía · ${lesson.title}'),
            icon: const Icon(Icons.support_agent_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          AppHeroHeader(
            colors: [palette.face, palette.shade],
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UNIDAD ${index < 0 ? 1 : index + 1} · LECCIÓN',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        lesson.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                          height: 1.08,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        lesson.description,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: fraction,
                        strokeWidth: 7,
                        backgroundColor: Colors.white.withValues(alpha: 0.22),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                      Center(
                        child: Text(
                          '$done/$total',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                const JaguareteMascot(size: 58, mood: MascotMood.happy),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'El Jaguareté te acompaña',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        total == 0
                            ? 'Esta lección todavía no tiene señas cargadas.'
                            : 'Vas a ver ${total == 1 ? 'una seña' : '$total señas'} paso a paso, con la forma, el lugar y el movimiento.',
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
          ),
          const SizedBox(height: 20),
          const AppSectionTitle(
            'En esta lección',
            subtitle: 'Tocá una seña para ver su demostración guiada.',
          ),
          const SizedBox(height: 10),
          if (signs.isEmpty)
            const AppEmptyState(
              icon: Icons.sign_language_outlined,
              title: 'Sin señas por ahora',
              message: 'Volvé a la biblioteca para explorar el vocabulario.',
            )
          else
            for (final sign in signs) ...[
              _SignGuideCard(
                sign: sign,
                learned: learned.contains(sign.id),
                onTap: () => context.push(
                  '/lesson/${lesson.id}?sign=${sign.id}',
                ),
              ),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 20),
          const AppSectionTitle(
            'Cómo se enseña',
            subtitle: 'Primero mirás, después practicás.',
          ),
          const SizedBox(height: 10),
          _HowStep(
            number: '1',
            icon: Icons.back_hand_outlined,
            asset: AppFeatureAssets.practice,
            title: 'Forma',
            text: 'La posición de los dedos y la orientación de la palma.',
            color: AppColors.primary,
          ),
          const SizedBox(height: 8),
          _HowStep(
            number: '2',
            icon: Icons.my_location_rounded,
            title: 'Lugar',
            text: 'Dónde queda la mano respecto al cuerpo y la cara.',
            color: AppColors.teal,
          ),
          const SizedBox(height: 8),
          _HowStep(
            number: '3',
            icon: Icons.swap_horiz_rounded,
            asset: AppFeatureAssets.swap,
            title: 'Movimiento',
            text: 'El recorrido de la seña, con una pausa para observarla.',
            color: AppColors.sky,
          ),
          const SizedBox(height: 20),
          PushableButton(
            onPressed:
                total == 0 ? null : () => context.push('/lesson/${lesson.id}'),
            color: total == 0 ? AppColors.locked : palette.face,
            shadowColor: total == 0 ? AppColors.lockedShade : palette.shade,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  total == 0
                      ? Icons.hourglass_empty_rounded
                      : Icons.play_arrow_rounded,
                  color: total == 0 ? AppColors.lockedInk : Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  total == 0 ? 'SIN CONTENIDO' : 'EMPEZAR LECCIÓN',
                  style: TextStyle(
                    color: total == 0 ? AppColors.lockedInk : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Las demostraciones 3D son ilustrativas y están pendientes de '
            'validación por una persona experta en LSPy.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignGuideCard extends StatelessWidget {
  const _SignGuideCard({
    required this.sign,
    required this.learned,
    required this.onTap,
  });

  final SignModel sign;
  final bool learned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      child: Row(
        children: [
          AppIconBadge(
            icon: learned
                ? Icons.check_circle_rounded
                : Icons.sign_language_rounded,
            color: learned ? AppColors.success : AppColors.primary,
            size: 44,
            radius: 14,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      sign.name,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(width: 7),
                    AppPill(
                      icon: _categoryIcon(sign.category),
                      label: _categoryLabel(sign.category),
                      color: AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  sign.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.play_circle_outline_rounded,
              color: AppColors.primary, size: 24),
        ],
      ),
    );
  }

  static String _categoryLabel(SignCategory category) => switch (category) {
        SignCategory.greetings => 'Saludo',
        SignCategory.numbers => 'Número',
        SignCategory.basics => 'Básico',
        SignCategory.family => 'Familia',
        SignCategory.emotions => 'Emoción',
      };

  static IconData _categoryIcon(SignCategory category) => switch (category) {
        SignCategory.greetings => Icons.waving_hand_rounded,
        SignCategory.numbers => Icons.pin_rounded,
        SignCategory.basics => Icons.chat_bubble_outline_rounded,
        SignCategory.family => Icons.family_restroom_rounded,
        SignCategory.emotions => Icons.favorite_border_rounded,
      };
}

class _HowStep extends StatelessWidget {
  const _HowStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.text,
    required this.color,
    this.asset,
  });

  final String number;
  final IconData icon;
  final String? asset;
  final String title;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              AppIconBadge(
                icon: icon,
                asset: asset,
                color: color,
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
                    color: color,
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
                Text(
                  text,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.3,
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
