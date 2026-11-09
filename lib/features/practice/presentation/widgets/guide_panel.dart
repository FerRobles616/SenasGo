import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/avatar/presentation/widgets/guided_teacher.dart';
import 'package:senasgo/features/practice/domain/sign_reference.dart';
import 'package:senasgo/features/support/presentation/support_actions.dart';
import 'package:senasgo/shared/models/sign_model.dart';

/// Estado 2 (Demostración): el profesor 3D muestra la seña.
///
/// La pantalla prioriza la demostración y deja los cinco parámetros en una
/// hoja de detalle. Así el estudiante ve primero la seña y no una pared de
/// texto antes de practicar.
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
        const SizedBox(height: 14),
        Text(sign.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, color: AppColors.ink, height: 1.35)),
        const SizedBox(height: 8),
        Text(
          'Buena luz, mano visible y sin apuro.',
          style:
              TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.35),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _MiniParam(
                icon: Icons.back_hand_outlined,
                label: 'Forma',
                onTap: () => _showAllParameters(context, ref),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniParam(
                icon: Icons.my_location_rounded,
                label: 'Lugar',
                onTap: () => _showAllParameters(context, ref),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniParam(
                icon: Icons.swap_horiz_rounded,
                label: 'Movimiento',
                onTap: () => _showAllParameters(context, ref),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Center(
          child: TextButton.icon(
            onPressed: () => _showAllParameters(context, ref),
            icon: const Icon(Icons.tune_rounded, size: 17),
            label: const Text('Ver los 5 parámetros'),
          ),
        ),
        TextButton.icon(
          onPressed: () => SupportSheet.show(context,
              contextLabel: 'Demostración de ${sign.name}'),
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
          label: const Text('¿La demostración no se entiende? Avisanos'),
        ),
      ],
    );
  }

  void _showAllParameters(BuildContext context, SignReference ref) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          child: Column(
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
              const SizedBox(height: 16),
              Text('Los 5 parámetros',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink)),
              const SizedBox(height: 4),
              Text(
                'La app observa estos aspectos. No hace falta memorizarlos '
                'todos antes de practicar.',
                style: TextStyle(
                    color: AppColors.muted, fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 10),
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
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Entendido'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniParam extends StatelessWidget {
  const _MiniParam({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.primary, size: 19),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.primaryDeep,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppColors.primary, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(parameter.label,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        fontSize: 13.5)),
                Text(detail,
                    style: TextStyle(
                        color: AppColors.muted, fontSize: 12.5, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
