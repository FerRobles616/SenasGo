import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/avatar/presentation/widgets/guided_teacher.dart';
import 'package:senasgo/features/practice/domain/sign_reference.dart';
import 'package:senasgo/features/support/presentation/support_actions.dart';
import 'package:senasgo/shared/models/sign_model.dart';

/// Estado 2 (Demostración): el profesor 3D muestra la seña y se repasan los
/// cinco parámetros formativos antes de practicar.
class GuidePanel extends StatelessWidget {
  const GuidePanel({required this.sign, super.key});

  final SignModel sign;

  @override
  Widget build(BuildContext context) {
    final ref = SignReference.of(sign.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GuidedTeacher(
          signId: sign.id,
          height: MediaQuery.sizeOf(context).height < 700 ? 250 : 320,
          onExpand: () => context.push('/teacher/${sign.id}'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.info_outline_rounded,
                size: 15, color: AppColors.warningInk),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Demostración ilustrativa · pendiente de validación LSPy',
                style: TextStyle(
                    color: AppColors.warningInk.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(sign.description,
            style:
                TextStyle(fontSize: 15.5, color: AppColors.ink, height: 1.4)),
        const SizedBox(height: 18),
        Text('Antes de practicar',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink)),
        const SizedBox(height: 6),
        Text(
          'Adoptá una postura cómoda y mantené la mano visible dentro del '
          'encuadre, con buena iluminación. No hace falta apurar el movimiento.',
          style: TextStyle(color: AppColors.muted, height: 1.4),
        ),
        const SizedBox(height: 14),
        _ParamTile(
          icon: Icons.back_hand_outlined,
          parameter: SignParameter.manualConfig,
          detail: 'Forma de la mano y de los dedos.',
        ),
        _ParamTile(
          icon: Icons.rotate_right,
          parameter: SignParameter.palmOrientation,
          detail: ref.palm?.hint ?? 'Hacia dónde mira la palma.',
        ),
        _ParamTile(
          icon: Icons.my_location,
          parameter: SignParameter.articulationPlace,
          detail: 'Dónde se ejecuta la seña respecto al cuerpo.',
        ),
        _ParamTile(
          icon: Icons.swap_horiz,
          parameter: SignParameter.movement,
          detail: ref.movement.hint.isEmpty
              ? 'Trayectoria y ritmo.'
              : ref.movement.hint,
        ),
        _ParamTile(
          icon: Icons.sentiment_satisfied_alt,
          parameter: SignParameter.facialExpression,
          detail: ref.usesFace
              ? 'Esta seña se acompaña con el rostro.'
              : 'Acompañamiento del rostro.',
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => SupportSheet.show(context,
              contextLabel: 'Demostración de ${sign.name}'),
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
          label: const Text('¿La demostración no se entiende? Avisanos'),
        ),
      ],
    );
  }
}

class _ParamTile extends StatelessWidget {
  const _ParamTile(
      {required this.icon, required this.parameter, required this.detail});

  final IconData icon;
  final SignParameter parameter;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(parameter.label,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: AppColors.ink)),
                Text(detail,
                    style: TextStyle(color: AppColors.muted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
