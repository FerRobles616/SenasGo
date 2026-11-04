import 'package:flutter/material.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/avatar/domain/teacher_step.dart';
import 'package:senasgo/features/avatar/presentation/widgets/jaguar_teacher.dart';

/// Demostración guiada del profesor 3D.
///
/// La seña se parte en pasos cortos (forma, lugar y movimiento). Cada paso
/// reproduce un clip que termina sosteniendo la pose, elige el encuadre más
/// útil y se acompaña con una instrucción breve. La cámara queda bloqueada:
/// el estudiante no tiene que pelear con el modelo para entender la seña.
class GuidedTeacher extends StatefulWidget {
  const GuidedTeacher({
    required this.signId,
    this.height = 340,
    this.onExpand,
    super.key,
  });

  final String signId;
  final double height;
  final VoidCallback? onExpand;

  @override
  State<GuidedTeacher> createState() => _GuidedTeacherState();
}

class _GuidedTeacherState extends State<GuidedTeacher> {
  late List<TeacherStep> _steps = TeacherLessonCatalog.stepsFor(widget.signId);
  int _index = 0;
  int _replayToken = 0;
  bool _full = false;

  @override
  void didUpdateWidget(covariant GuidedTeacher old) {
    super.didUpdateWidget(old);
    if (old.signId != widget.signId) {
      _steps = TeacherLessonCatalog.stepsFor(widget.signId);
      _index = 0;
      _full = false;
      _replayToken++;
    }
  }

  TeacherStep? get _step {
    if (_steps.isEmpty) return null;
    final safe = _index < 0
        ? 0
        : _index >= _steps.length
            ? _steps.length - 1
            : _index;
    return _steps[safe];
  }

  void _selectStep(int index) {
    setState(() {
      _index = index;
      _full = false;
      _replayToken++;
    });
  }

  void _replay() => setState(() => _replayToken++);

  void _toggleFull() {
    setState(() {
      _full = !_full;
      _replayToken++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = _step;
    final clip = _full || step == null ? widget.signId : step.clip;
    final view = _full || step == null ? TeacherView.body : step.view;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JaguarTeacher(
          signId: widget.signId,
          clip: clip,
          initialView: view,
          replayToken: _replayToken,
          height: widget.height,
          showControls: false,
          onExpand: widget.onExpand,
        ),
        if (step != null) ...[
          const SizedBox(height: 10),
          _StepPanel(
            steps: _steps,
            index: _index,
            full: _full,
            onStep: _selectStep,
            onPrevious: _index > 0 ? () => _selectStep(_index - 1) : null,
            onNext: _index < _steps.length - 1
                ? () => _selectStep(_index + 1)
                : null,
            onReplay: _replay,
            onToggleFull: _toggleFull,
            onExpand: widget.onExpand,
          ),
        ],
      ],
    );
  }
}

class _StepPanel extends StatelessWidget {
  const _StepPanel({
    required this.steps,
    required this.index,
    required this.full,
    required this.onStep,
    required this.onPrevious,
    required this.onNext,
    required this.onReplay,
    required this.onToggleFull,
    required this.onExpand,
  });

  final List<TeacherStep> steps;
  final int index;
  final bool full;
  final ValueChanged<int> onStep;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onReplay;
  final VoidCallback onToggleFull;
  final VoidCallback? onExpand;

  static final ButtonStyle _navStyle = ButtonStyle(
    minimumSize: WidgetStateProperty.all(const Size(0, 40)),
    padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 5, vertical: 7)),
    textStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
    shape: WidgetStateProperty.all(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final safe = index < 0
        ? 0
        : index >= steps.length
            ? steps.length - 1
            : index;
    final step = steps[safe];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.school_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Paso a paso',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Text(
                full ? 'Completa' : '${index + 1} de ${steps.length}',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              if (onExpand != null) ...[
                const SizedBox(width: 2),
                IconButton(
                  tooltip: 'Ver en pantalla completa',
                  onPressed: onExpand,
                  icon: const Icon(Icons.fullscreen_rounded, size: 20),
                  color: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(width: 7),
                Expanded(
                  child: _StepChip(
                    step: steps[i],
                    selected: !full && i == index,
                    onTap: () => onStep(i),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Container(
              key: ValueKey(full ? 'full' : 'step-$index'),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(full ? Icons.play_circle_outline_rounded : step.icon,
                      color: AppColors.primary, size: 21),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      full
                          ? 'Mirá la seña completa y después volvé a los pasos '
                              'para repasar lo que no te haya quedado claro.'
                          : step.instruction,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onPrevious,
                  style: _navStyle,
                  child: const Text('Anterior',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: onReplay,
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Repetir'),
                  style: _navStyle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onNext,
                  style: _navStyle,
                  child: const Text('Siguiente',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          TextButton.icon(
            onPressed: onToggleFull,
            icon: Icon(
              full
                  ? Icons.format_list_numbered_rounded
                  : Icons.play_circle_outline_rounded,
              size: 19,
            ),
            label: Text(full ? 'Volver a los pasos' : 'Ver la seña completa'),
          ),
        ],
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.step,
    required this.selected,
    required this.onTap,
  });

  final TeacherStep step;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.ink;
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                step.icon,
                size: 16,
                color: selected ? Colors.white : AppColors.primary,
              ),
              const SizedBox(height: 3),
              Text(
                step.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
