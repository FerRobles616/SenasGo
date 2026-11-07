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
            onPrevious: _index > 0 ? () => _selectStep(_index - 1) : null,
            onNext: _index < _steps.length - 1
                ? () => _selectStep(_index + 1)
                : null,
            onReplay: _replay,
            onToggleFull: _toggleFull,
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
    required this.onPrevious,
    required this.onNext,
    required this.onReplay,
    required this.onToggleFull,
  });

  final List<TeacherStep> steps;
  final int index;
  final bool full;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onReplay;
  final VoidCallback onToggleFull;

  static final ButtonStyle _navStyle = ButtonStyle(
    minimumSize: WidgetStateProperty.all(const Size(0, 42)),
    padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
    textStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
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
    final isLast = safe >= steps.length - 1;
    final title = full
        ? 'Seña completa'
        : 'Paso ${safe + 1} de ${steps.length} · ${step.title}';
    final instruction = full
        ? 'Mirá la seña completa y después volvé a los pasos.'
        : step.instruction;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outlineStrong),
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
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                    color: AppColors.ink,
                  ),
                ),
              ),
              IconButton(
                tooltip: full ? 'Repetir seña completa' : 'Repetir paso',
                onPressed: onReplay,
                icon: const Icon(Icons.replay_rounded, size: 20),
                color: AppColors.primary,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
              ),
            ],
          ),
          if (!full) _StepDots(index: safe, total: steps.length),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Container(
              key: ValueKey(full ? 'full' : 'step-$safe'),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(full ? Icons.play_circle_outline_rounded : step.icon,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      instruction,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (full)
            FilledButton.tonalIcon(
              onPressed: onToggleFull,
              icon: const Icon(Icons.format_list_numbered_rounded, size: 18),
              label: const Text('Volver a los pasos'),
              style: _navStyle,
            )
          else ...[
            Row(
              children: [
                if (onPrevious != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onPrevious,
                      style: _navStyle,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_back_rounded, size: 16),
                          SizedBox(width: 4),
                          Text('Anterior'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: isLast
                      ? FilledButton.icon(
                          onPressed: onToggleFull,
                          icon: const Icon(Icons.play_circle_outline_rounded,
                              size: 18),
                          label: const Text('Ver seña completa'),
                          style: _navStyle,
                        )
                      : FilledButton.icon(
                          onPressed: onNext,
                          icon:
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                          label: const Text('Siguiente'),
                          style: _navStyle,
                        ),
                ),
              ],
            ),
            if (!isLast) ...[
              const SizedBox(height: 2),
              Center(
                child: TextButton.icon(
                  onPressed: onToggleFull,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  icon: const Icon(Icons.play_circle_outline_rounded, size: 17),
                  label: const Text('Ver la seña completa'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Paso ${index + 1} de $total',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < total; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 5, bottom: 6),
              width: i == index ? 20 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i <= index ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
        ],
      ),
    );
  }
}
