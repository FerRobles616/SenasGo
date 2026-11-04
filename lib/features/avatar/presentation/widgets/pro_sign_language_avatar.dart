import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:senasgo/core/services/device_performance.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/core/vision/hand_landmarks.dart';
import 'package:senasgo/features/avatar/domain/sign_animation_model.dart';
import 'package:senasgo/features/avatar/presentation/controllers/avatar_playback_controller.dart';
import 'package:senasgo/features/avatar/presentation/controllers/gesture_avatar_controller.dart';
import 'package:senasgo/features/avatar/presentation/rendering/procedural_avatar_painter.dart';
import 'package:senasgo/features/avatar/presentation/rendering/rive_sign_avatar.dart';
import 'package:senasgo/features/avatar/presentation/widgets/avatar_playback_controls.dart';

/// Avatar profesor que demuestra una seña con manos, rostro y cuerpo.
///
/// - Rive (State Machine) si existe `assets/rive/sign_avatar.riv` y el
///   equipo tiene memoria suficiente.
/// - Si no, avatar procedural pseudo-3D: liviano, sin assets y con rotación
///   real por arrastre para ver las manos desde otro ángulo.
class ProSignLanguageAvatar extends StatefulWidget {
  const ProSignLanguageAvatar({
    required this.animation,
    this.showControls = true,
    this.autoplay = true,
    this.height = 320,
    this.gestureController,
    super.key,
  });

  final SignAnimationModel animation;

  /// Órdenes externas (playSign, replay, velocidad); ver [GestureAvatar].
  final GestureAvatarController? gestureController;
  final bool showControls;
  final bool autoplay;
  final double height;

  @override
  State<ProSignLanguageAvatar> createState() => _ProSignLanguageAvatarState();
}

class _ProSignLanguageAvatarState extends State<ProSignLanguageAvatar>
    with TickerProviderStateMixin {
  late final AvatarPlaybackController _controller = AvatarPlaybackController(
    vsync: this,
    animation: widget.animation,
    autoplay: widget.autoplay,
    // Con poca RAM el avatar queda quieto en pausa (sin respiración).
    idleMotion: !DevicePerformance.isLowMemory,
  );
  late List<Vec3> _trail = _buildTrail(widget.animation);
  // El profesor usa siempre la túnica violeta de la marca; la tienda se
  // retiró y la ropa ya no es un desbloqueo.
  static const _palette = AvatarPalette(tunic: AvatarPalette.tunicBlue);
  bool _useRive = false;
  bool _rotatedOnce = false;

  @visibleForTesting
  AvatarPlaybackController get controllerForTest => _controller;

  @override
  void initState() {
    super.initState();
    _probeRive();
    widget.gestureController?.addListener(_onCommand);
  }

  /// Aplica las órdenes del [GestureAvatarController].
  void _onCommand() {
    final g = widget.gestureController!;
    switch (g.lastCommand) {
      case AvatarCommand.play:
        if (g.current.signId == _controller.animation.signId) {
          _controller.replay();
        } else {
          _controller.setAnimation(g.current);
          setState(() => _trail = _buildTrail(g.current));
        }
      case AvatarCommand.replay:
        _controller.replay();
      case AvatarCommand.stop:
        _controller.stop();
      case AvatarCommand.speed:
        _controller.setSpeed(g.speed);
      case null:
        break;
    }
  }

  Future<void> _probeRive() async {
    if (DevicePerformance.isLowMemory) return;
    try {
      await rootBundle.load(RiveAvatarContract.asset);
      if (mounted) setState(() => _useRive = true);
    } catch (_) {
      // Sin archivo Rive: se queda el avatar procedural.
    }
  }

  @override
  void didUpdateWidget(covariant ProSignLanguageAvatar old) {
    super.didUpdateWidget(old);
    if (old.gestureController != widget.gestureController) {
      old.gestureController?.removeListener(_onCommand);
      widget.gestureController?.addListener(_onCommand);
    }
    if (old.animation.signId != widget.animation.signId) {
      _controller.setAnimation(widget.animation, autoplay: widget.autoplay);
      _trail = _buildTrail(widget.animation);
    }
  }

  @override
  void dispose() {
    widget.gestureController?.removeListener(_onCommand);
    _controller.dispose();
    super.dispose();
  }

  /// Trayectoria de la mano dominante entre el primer y el último keyframe.
  static List<Vec3> _buildTrail(SignAnimationModel a) {
    final times = a.keyframeTimes;
    if (times.isEmpty) return const [];
    const samples = 42;
    return [
      for (var i = 0; i <= samples; i++)
        a
            .sample(times.first + (times.last - times.first) * i / samples)
            .dominant
            .wrist,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AvatarStage(
          controller: _controller,
          height: widget.height,
          rotatable: !_useRive,
          showRotateHint: !_useRive && !_rotatedOnce,
          onRotated: () {
            if (!_rotatedOnce) setState(() => _rotatedOnce = true);
          },
          child: _useRive
              ? RiveSignAvatar(controller: _controller)
              : CustomPaint(
                  painter: ProceduralAvatarPainter(
                    controller: _controller,
                    palette: _palette,
                    trail: _trail,
                  ),
                ),
        ),
        if (widget.showControls) ...[
          const SizedBox(height: 12),
          AvatarPlaybackControls(controller: _controller),
        ],
      ],
    );
  }
}

/// Escenario redondeado: gestos de cámara, fase actual y rasgos no manuales.
class _AvatarStage extends StatelessWidget {
  const _AvatarStage({
    required this.controller,
    required this.height,
    required this.rotatable,
    required this.showRotateHint,
    required this.onRotated,
    required this.child,
  });

  final AvatarPlaybackController controller;
  final double height;
  final bool rotatable;
  final bool showRotateHint;
  final VoidCallback onRotated;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.95,
          colors: [Colors.white, AppColors.primarySoft, AppColors.border],
          stops: [0, 0.6, 1],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        onPanUpdate: rotatable
            ? (d) {
                controller.rotateBy(d.delta.dx, d.delta.dy);
                onRotated();
              }
            : null,
        onDoubleTap: rotatable ? controller.resetCamera : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: child),
            Positioned(
              top: 14,
              left: 14,
              right: 14,
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!controller.animation.validatedByLspyExpert)
                      const _Pill(text: 'POR VALIDAR'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topRight,
                        child: _PhasePill(text: controller.frame.phase),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 14,
              bottom: 14,
              right: 60,
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) =>
                    _NonManualTracks(controller: controller),
              ),
            ),
            if (rotatable)
              Positioned(
                right: 12,
                bottom: 12,
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => AnimatedScale(
                    scale: controller.isCameraRotated ? 1 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    child: IconButton.filledTonal(
                      onPressed: controller.resetCamera,
                      tooltip: 'Volver al frente',
                      icon: const Icon(Icons.center_focus_strong_rounded),
                    ),
                  ),
                ),
              ),
            if (showRotateHint)
              const Positioned(
                right: 14,
                bottom: 16,
                child: _Pill(text: '↔ Arrastra para girar'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Indicadores de los componentes no manuales activos (rostro y cuerpo).
class _NonManualTracks extends StatelessWidget {
  const _NonManualTracks({required this.controller});

  final AvatarPlaybackController controller;

  @override
  Widget build(BuildContext context) {
    final f = controller.frame;
    final faceActive = f.face.label != 'neutral';
    final bodyActive = f.body.label.isNotEmpty;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _TrackChip(
            icon: Icons.sentiment_satisfied_alt_rounded,
            text: 'Rostro: ${f.face.label}',
            active: faceActive),
        _TrackChip(
            icon: Icons.accessibility_new_rounded,
            text: 'Cuerpo: ${f.body.label}',
            active: bodyActive),
      ],
    );
  }
}

class _TrackChip extends StatelessWidget {
  const _TrackChip(
      {required this.icon, required this.text, required this.active});

  final IconData icon;
  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: active ? 1 : 0,
      duration: const Duration(milliseconds: 250),
      child: AnimatedSlide(
        offset: active ? Offset.zero : const Offset(0, 0.4),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 8)
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AppColors.primary),
              const SizedBox(width: 5),
              Text(text,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhasePill extends StatelessWidget {
  const _PhasePill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      // Las dos etiquetas se apilan a la derecha durante el cambio, sin
      // pisar al resto de la fila.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topRight,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position:
              Tween(begin: const Offset(0, -0.4), end: Offset.zero).animate(a),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(text),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text,
          style: TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3)),
    );
  }
}
