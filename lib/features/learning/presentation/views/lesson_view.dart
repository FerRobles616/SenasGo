import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/avatar/presentation/widgets/guided_teacher.dart';
import 'package:senasgo/features/practice/domain/sign_reference.dart';
import 'package:senasgo/features/support/presentation/support_actions.dart';
import 'package:senasgo/shared/models/sign_model.dart';
import 'package:senasgo/shared/widgets/pushable_button.dart';

/// Fase "Aprender": el profesor 3D demuestra la seña y se explican los cinco
/// parámetros formativos antes de practicar con la cámara.
class LessonView extends StatefulWidget {
  const LessonView({required this.lessonId, this.initialSignId, super.key});

  final String lessonId;

  /// Seña elegida desde la biblioteca o el camino.
  final String? initialSignId;

  @override
  State<LessonView> createState() => _LessonViewState();
}

class _LessonViewState extends State<LessonView> {
  SignModel? _selected;
  late final Set<String> _learned = HiveService.learnedSignIds;

  @override
  void initState() {
    super.initState();
    final signs = HiveService.signsOf(widget.lessonId);
    if (widget.initialSignId != null) {
      for (final sign in signs) {
        if (sign.id == widget.initialSignId) {
          _selected = sign;
          break;
        }
      }
    }
    _selected ??= signs.isEmpty ? null : signs.first;
  }

  @override
  Widget build(BuildContext context) {
    final lesson = HiveService.lessonsBox.get(widget.lessonId);
    final signs = HiveService.signsOf(widget.lessonId);
    final shown = _selected ?? (signs.isEmpty ? null : signs.first);

    if (lesson == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lección')),
        body: const Center(child: Text('Lección no encontrada')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(lesson.title),
        actions: [
          IconButton(
            tooltip: 'Ayuda y comentarios',
            onPressed: () => SupportSheet.show(context,
                contextLabel: 'Lección ${lesson.title}'),
            icon: const Icon(Icons.support_agent_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            lesson.description,
            style:
                TextStyle(fontSize: 15.5, color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          if (shown != null)
            GuidedTeacher(
              signId: shown.id,
              height: MediaQuery.sizeOf(context).height < 700 ? 250 : 332,
              onExpand: () => context.push('/teacher/${shown.id}'),
            ),
          if (shown != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    shown.name.toUpperCase(),
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Demostración guiada por pasos.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const _Disclaimer(),
          ],
          const SizedBox(height: 22),
          if (signs.length > 1) ...[
            Text('Señas de esta lección',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: AppColors.ink)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final sign in signs)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _SignChip(
                        sign: sign,
                        selected: sign.id == shown?.id,
                        learned: _learned.contains(sign.id),
                        onTap: () => setState(() => _selected = sign),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
          ],
          if (shown != null) _ParametersCard(sign: shown),
          const SizedBox(height: 22),
          if (shown != null)
            PushableButton(
              onPressed: () => context
                  .push('/practice?lesson=${widget.lessonId}&sign=${shown.id}'),
              color: AppColors.primary,
              shadowColor: const Color(0xFF115E59),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt_rounded,
                      color: Colors.white, size: 21),
                  const SizedBox(width: 8),
                  Text(
                    'PRACTICAR ${shown.name.toUpperCase()}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 0.3),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/library'),
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Volver a la biblioteca'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => SupportSheet.show(context,
                contextLabel: 'Demostración de ${shown?.name ?? lesson.title}'),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 19),
            label: const Text('¿La seña no se entiende? Escribinos'),
          ),
        ],
      ),
    );
  }
}

class _SignChip extends StatelessWidget {
  const _SignChip({
    required this.sign,
    required this.selected,
    required this.learned,
    required this.onTap,
  });

  final SignModel sign;
  final bool selected;
  final bool learned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(
        learned ? Icons.check_rounded : Icons.sign_language_rounded,
        size: 17,
        color: selected
            ? AppColors.onPrimary
            : learned
                ? AppColors.success
                : AppColors.primary,
      ),
      label: Text(sign.name),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      side: BorderSide(color: AppColors.border),
      labelStyle: TextStyle(
        color: selected ? AppColors.onPrimary : AppColors.ink,
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    );
  }
}

class _ParametersCard extends StatelessWidget {
  const _ParametersCard({required this.sign});

  final SignModel sign;

  @override
  Widget build(BuildContext context) {
    final ref = SignReference.of(sign.id);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: AppColors.primary, size: 21),
              SizedBox(width: 8),
              Text('Los 5 parámetros de la seña',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16.5,
                      color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Sirven para observar con atención, no para memorizar porcentajes.',
            style: TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          _ParamRow(
            icon: Icons.back_hand_outlined,
            title: SignParameter.manualConfig.label,
            detail: _fingerSummary(sign.id),
          ),
          _ParamRow(
            icon: Icons.rotate_right_rounded,
            title: SignParameter.palmOrientation.label,
            detail: ref.palm?.hint ?? 'La palma acompaña el significado.',
          ),
          _ParamRow(
            icon: Icons.my_location_rounded,
            title: SignParameter.articulationPlace.label,
            detail:
                'Frente, mentón, pecho o espacio neutro: el lugar cambia la seña.',
          ),
          _ParamRow(
            icon: Icons.swap_horiz_rounded,
            title: SignParameter.movement.label,
            detail: ref.movement.hint.isEmpty
                ? 'Trayectoria y ritmo de la mano.'
                : ref.movement.hint,
          ),
          _ParamRow(
            icon: Icons.sentiment_satisfied_alt_rounded,
            title: SignParameter.facialExpression.label,
            detail: ref.usesFace
                ? 'Esta seña se acompaña con el rostro.'
                : 'El rostro acompaña la intención.',
            last: true,
          ),
        ],
      ),
    );
  }

  static String _fingerSummary(String signId) => switch (signId) {
        'saludo_hola' || 'saludo_chau' => 'Mano abierta, dedos extendidos.',
        'saludo_saludos' => 'Mano plana con los dedos juntos.',
        'numero_uno' => 'Índice extendido; el resto doblado.',
        'numero_dos' => 'Índice y medio en V; el resto doblado.',
        'numero_tres' => 'Índice, medio y anular extendidos.',
        'basico_si' => 'Puño cerrado.',
        'basico_no' => 'Índice y medio que se abren y cierran.',
        'basico_gracias' ||
        'basico_por_favor' =>
          'Mano plana con los dedos juntos.',
        _ => 'Forma de la mano y de los dedos.',
      };
}

class _ParamRow extends StatelessWidget {
  const _ParamRow({
    required this.icon,
    required this.title,
    required this.detail,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppColors.ink)),
                Text(detail,
                    style: TextStyle(
                        color: AppColors.muted, fontSize: 12, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16, color: AppColors.warningInk),
          SizedBox(width: 7),
          Expanded(
            child: Text(
              'Demostración ilustrativa, pendiente de validación por una '
              'persona experta en LSPy.',
              style: TextStyle(
                  color: AppColors.warningInk, fontSize: 11.5, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
