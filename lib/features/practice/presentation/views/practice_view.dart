import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:senasgo/core/constants/app_constants.dart';
import 'package:senasgo/core/services/camera_service.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/core/services/inference_service.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/core/vision/frame_processor.dart';
import 'package:senasgo/features/practice/presentation/controllers/practice_controller.dart';
import 'package:senasgo/features/practice/presentation/widgets/camera_overlay.dart';
import 'package:senasgo/features/practice/presentation/widgets/feedback_panel.dart';
import 'package:senasgo/features/practice/presentation/widgets/guide_panel.dart';
import 'package:senasgo/features/support/presentation/support_actions.dart';
import 'package:senasgo/shared/widgets/exit_lesson_dialog.dart';
import 'package:senasgo/shared/widgets/lesson_progress_bar.dart';

/// Pantalla de práctica: Aprender -> Prepararse -> Practicar -> Feedback -> Corregir.
class PracticeView extends StatefulWidget {
  const PracticeView({super.key, this.lessonId, this.startSignId});

  final String? lessonId;

  /// Seña elegida en el camino de aprendizaje (null = la primera).
  final String? startSignId;

  @override
  State<PracticeView> createState() => _PracticeViewState();
}

class _PracticeViewState extends State<PracticeView>
    with WidgetsBindingObserver {
  late final PracticeController _controller =
      context.read<PracticeController>();

  /// La persona ya confirmó que quiere salir: PopScope deja de frenar.
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller
        .startLesson(widget.lessonId, startSignId: widget.startSignId));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // El plugin de cámara exige liberar el sensor al pasar a segundo plano.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller.onAppPaused();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Salir a mitad de lección pide confirmación; al terminar o sin cámara no.
  bool _needsExitConfirm(PracticeState s) =>
      !_leaving &&
      s.stage != PracticeStage.loading &&
      s.stage != PracticeStage.lessonSummary &&
      s.stage != PracticeStage.cameraUnavailable;

  Future<void> _confirmExit() async {
    final s = _controller.state;
    if (!_needsExitConfirm(s)) {
      _leave();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) =>
          ExitLessonDialog(remaining: s.totalSigns - s.completedCount),
    );
    if (leave == true && mounted) _leave();
  }

  void _leave() {
    setState(() => _leaving = true);
    _controller.stop();
    // Un cuadro después, cuando PopScope ya deja salir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.canPop() ? context.pop() : context.go('/library');
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PracticeController>().state;
    return PopScope(
      canPop: !_needsExitConfirm(state),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _controller.stop();
        } else {
          _confirmExit();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Consumer<PracticeController>(
            builder: (context, controller, _) {
              final s = controller.state;
              final copy = _StageCopy.of(s);
              final reduceMotion =
                  MediaQuery.maybeDisableAnimationsOf(context) ?? false;
              return Column(
                children: [
                  _Header(
                    state: s,
                    onBack: _confirmExit,
                    onSupport: () => SupportSheet.show(context,
                        contextLabel:
                            'Práctica · ${s.currentSign?.name ?? 'seña'}'),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      children: [
                        if (copy.eyebrow.isNotEmpty)
                          Text(copy.eyebrow,
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4)),
                        const SizedBox(height: 6),
                        Text(copy.title,
                            style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink)),
                        if (copy.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(copy.subtitle,
                              style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.muted,
                                  height: 1.35)),
                        ],
                        const SizedBox(height: 20),
                        AnimatedSwitcher(
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 260),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                      begin: const Offset(0, 0.04),
                                      end: Offset.zero)
                                  .animate(animation),
                              child: child,
                            ),
                          ),
                          layoutBuilder: (current, previous) => Stack(
                            alignment: Alignment.topCenter,
                            children: [
                              ...previous,
                              if (current != null) current,
                            ],
                          ),
                          child: KeyedSubtree(
                            key: ValueKey(_bodyKey(s)),
                            child: _body(controller),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _bottom(context, controller),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Los estados con cámara comparten clave: así la vista previa no se
  /// reconstruye (ni se duplica) al pasar de encuadre a captura.
  String _bodyKey(PracticeState s) => switch (s.stage) {
        PracticeStage.framing ||
        PracticeStage.capturing ||
        PracticeStage.evaluating ||
        PracticeStage.handNotDetected =>
          'camera-${s.index}',
        _ => '${s.stage.name}-${s.index}',
      };

  /// Acierto y error muestran el veredicto junto al botón para seguir.
  Widget _bottom(BuildContext context, PracticeController c) {
    final s = c.state;
    final actions = _actions(context, c);
    if (s.stage != PracticeStage.correct &&
        s.stage != PracticeStage.incorrect) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: actions,
      );
    }
    final ok = s.stage == PracticeStage.correct;
    return VerdictPanel(
      key: ValueKey('verdict-${s.stage.name}-${s.index}-${s.completedCount}'),
      success: ok,
      title: ok ? '¡Seña correcta!' : '¡Casi!',
      message: ok
          ? s.combo >= 2
              ? '${s.combo} señas seguidas · +${AppConstants.xpPerCorrectSign} XP'
              : '+${AppConstants.xpPerCorrectSign} XP · Una seña más en tu camino.'
          : 'Mirá arriba qué ajustar y probá otra vez.',
      child: actions,
    );
  }

  Widget _body(PracticeController c) {
    final s = c.state;
    final camera =
        CameraOverlay(state: s, controller: c.cameraService.controller);
    switch (s.stage) {
      case PracticeStage.loading:
        return const Padding(
          padding: EdgeInsets.only(top: 80),
          child: Center(child: CircularProgressIndicator()),
        );
      case PracticeStage.demonstration:
        return GuidePanel(sign: s.currentSign!);
      case PracticeStage.framing:
        return Column(children: [
          camera,
          const SizedBox(height: 18),
          const _Tip(
              icon: Icons.wb_sunny_outlined,
              title: 'Busca buena iluminación',
              text: 'Evita una luz intensa detrás de ti.'),
          const _Tip(
              icon: Icons.crop_free,
              title: 'Mantén la mano visible',
              text: 'Colócala por completo dentro del recuadro.'),
        ]);
      case PracticeStage.capturing:
      case PracticeStage.evaluating:
        return camera;
      case PracticeStage.handNotDetected:
        return Column(children: [
          camera,
          const SizedBox(height: 16),
          const _Notice(
              title: 'No pasa nada, vuelve a probar',
              text:
                  'Comprueba la iluminación y deja espacio alrededor de la mano.'),
        ]);
      case PracticeStage.environmentIssue:
        return _Notice(
          title: s.lighting == LightingStatus.backlit
              ? 'Hay una luz fuerte detrás de ti'
              : s.lighting == LightingStatus.tooDark
                  ? 'El ambiente está muy oscuro'
                  : 'Hay demasiada luz sobre la mano',
          text: s.lighting == LightingStatus.backlit
              ? 'Gírate para que la luz (ventana, lámpara) quede frente a ti y no a tu espalda.'
              : 'Busca un lugar con luz pareja sobre tu mano y tu rostro.',
        );
      case PracticeStage.incorrect:
        return IncorrectFeedback(state: s);
      case PracticeStage.correct:
        return CorrectFeedback(state: s);
      case PracticeStage.lessonSummary:
        return LessonSummary(state: s);
      case PracticeStage.cameraUnavailable:
        return const _Notice(
          title: 'Puedes seguir aprendiendo',
          text:
              'La teoría, la demostración del profesor y la biblioteca de señas '
              'funcionan sin cámara.',
        );
    }
  }

  Widget _actions(BuildContext context, PracticeController c) {
    final s = c.state;
    switch (s.stage) {
      case PracticeStage.loading:
        return const SizedBox.shrink();
      case PracticeStage.demonstration:
        return FilledButton.icon(
          onPressed: c.goToFraming,
          icon: const Icon(Icons.back_hand_outlined),
          label: const Text('PRACTICAR'),
        );
      case PracticeStage.framing:
        return FilledButton.icon(
          onPressed: s.lighting == LightingStatus.ok ? c.startCapture : null,
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Comenzar'),
        );
      case PracticeStage.capturing:
      case PracticeStage.evaluating:
        return _secondary(
            Icons.menu_book_outlined, 'Volver a la guía', c.viewGuide);
      case PracticeStage.handNotDetected:
      case PracticeStage.environmentIssue:
        return FilledButton.icon(
          onPressed: c.retryFraming,
          icon: const Icon(Icons.refresh),
          label: const Text('Intentar nuevamente'),
        );
      case PracticeStage.incorrect:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          FilledButton.icon(
            onPressed: HiveService.energy > 0 ? c.tryAgain : null,
            icon: const Icon(Icons.refresh),
            label: Text(HiveService.energy > 0
                ? 'INTENTAR DE NUEVO'
                : 'SIN ENERGÍA POR AHORA'),
          ),
          const SizedBox(height: 10),
          _secondary(Icons.play_arrow_outlined, 'VER GUÍA', c.viewGuide),
        ]);
      case PracticeStage.correct:
        return FilledButton.icon(
          onPressed: c.next,
          icon: const Icon(Icons.arrow_forward),
          label: Text(s.isLastPending ? 'VER MI PROGRESO' : 'SIGUIENTE SEÑA'),
        );
      case PracticeStage.lessonSummary:
        return FilledButton.icon(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          icon: const Icon(Icons.home_outlined),
          label: const Text('VOLVER AL INICIO'),
        );
      case PracticeStage.cameraUnavailable:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          FilledButton.icon(
            onPressed: () => context.go('/library'),
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Ir a teoría y biblioteca'),
          ),
          const SizedBox(height: 10),
          if (s.cameraIssue == CameraIssue.permissionPermanentlyDenied)
            _secondary(Icons.settings_outlined, 'Abrir ajustes de permisos',
                c.cameraService.openSettings)
          else if (s.cameraIssue != CameraIssue.noCamera)
            _secondary(Icons.refresh, 'Reintentar cámara', c.goToFraming),
          const SizedBox(height: 10),
          _secondary(
              Icons.support_agent_rounded,
              'Necesito ayuda',
              () => SupportSheet.show(context,
                  contextLabel:
                      'Cámara · ${s.currentSign?.name ?? 'práctica'}')),
        ]);
    }
  }

  Widget _secondary(IconData icon, String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primarySoft,
          foregroundColor: AppColors.primary,
        ),
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

/// Textos de cada estado, tomados de las pantallas de la documentación v3_04.
class _StageCopy {
  const _StageCopy(this.eyebrow, this.title, this.subtitle);

  final String eyebrow;
  final String title;
  final String subtitle;

  static _StageCopy of(PracticeState s) {
    final name = s.currentSign?.name.toUpperCase() ?? '';
    final sim = s.mode == EngineMode.conceptual;
    final evalLabel = sim ? 'EVALUACIÓN SIMULADA' : 'EVALUACIÓN';
    final resultLabel = sim ? 'RESULTADO SIMULADO' : 'RESULTADO';
    switch (s.stage) {
      case PracticeStage.loading:
        return const _StageCopy('', 'Preparando...', '');
      case PracticeStage.demonstration:
        return _StageCopy('APRENDER · SEÑA ${s.index + 1} DE ${s.totalSigns}',
            name, 'Observa la representación antes de practicar.');
      case PracticeStage.framing:
        return _StageCopy('PRACTICAR · $name', 'Preparando práctica...',
            'Coloca tu mano dentro del área indicada');
      case PracticeStage.capturing:
        return _StageCopy('PRACTICAR · $name', 'Detectando...',
            'Mantén la mano dentro del recuadro y procura que se vea completa.');
      case PracticeStage.handNotDetected:
        return _StageCopy('MANO NO DETECTADA · $name', 'Ajustemos el encuadre',
            'No pudimos detectar correctamente la mano. Centra tu mano dentro del área indicada');
      case PracticeStage.environmentIssue:
        return _StageCopy('ILUMINACIÓN · $name', 'Revisemos la luz',
            'Necesitamos ver bien tu mano para evaluar la seña.');
      case PracticeStage.evaluating:
        return _StageCopy('$evalLabel · $name', 'Evaluando ejecución...',
            'Un momento. Estamos analizando tu postura manual.');
      case PracticeStage.incorrect:
        return _StageCopy(
            '$resultLabel · $name',
            'Necesita mejorar',
            s.evaluation?.feedbackTitle ??
                'Revisa la guía e inténtalo nuevamente');
      case PracticeStage.correct:
        return _StageCopy('$resultLabel · $name', '¡Muy bien!',
            'Seña reconocida correctamente');
      case PracticeStage.lessonSummary:
        return const _StageCopy('CIERRE DE LECCIÓN', '¡Lección completada!',
            'Cada seña te acerca a comunicarte en LSPy.');
      case PracticeStage.cameraUnavailable:
        return _StageCopy('CÁMARA NO DISPONIBLE', _cameraTitle(s.cameraIssue),
            _cameraText(s.cameraIssue));
    }
  }

  static String _cameraTitle(CameraIssue issue) => switch (issue) {
        CameraIssue.busy => 'La cámara está ocupada',
        CameraIssue.noCamera => 'No encontramos una cámara',
        _ => 'Sin permiso de cámara',
      };

  static String _cameraText(CameraIssue issue) => switch (issue) {
        CameraIssue.busy =>
          'Otra aplicación está usando la cámara. Ciérrala y vuelve a intentarlo.',
        CameraIssue.noCamera =>
          'Este dispositivo no tiene una cámara disponible.',
        CameraIssue.permissionPermanentlyDenied =>
          'Activa el permiso de cámara en los ajustes del teléfono para practicar.',
        _ =>
          'Para practicar necesitamos ver tu mano. Las imágenes no se guardan ni se envían.',
      };
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.state, required this.onBack, required this.onSupport});

  final PracticeState state;
  final VoidCallback onBack;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    final energy = HiveService.energy;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Salir de la lección',
                onPressed: onBack,
                icon:
                    Icon(Icons.close_rounded, size: 28, color: AppColors.muted),
              ),
              Expanded(
                child: LessonProgressBar(
                    done: state.completedCount, total: state.totalSigns),
              ),
              const SizedBox(width: 12),
              Semantics(
                label: '$energy de energía',
                excludeSemantics: true,
                child: Row(
                  children: [
                    Icon(Icons.battery_charging_full_rounded,
                        color: AppColors.teal, size: 24),
                    const SizedBox(width: 3),
                    Text('$energy',
                        style: TextStyle(
                            color: AppColors.teal,
                            fontWeight: FontWeight.w900,
                            fontSize: 17)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Ayuda y comentarios',
                onPressed: onSupport,
                icon: Icon(Icons.support_agent_rounded, color: AppColors.muted),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: ComboChip(combo: state.combo),
          ),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                Text(text, style: TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: AppColors.warningSoft,
          borderRadius: BorderRadius.circular(22)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.warningInk),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.warningInk,
                        fontSize: 16)),
                const SizedBox(height: 4),
                Text(text,
                    style:
                        TextStyle(color: AppColors.warningInk, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
