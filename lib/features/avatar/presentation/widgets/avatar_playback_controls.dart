import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/avatar/presentation/controllers/avatar_playback_controller.dart';

/// Controles de aprendizaje: línea de tiempo con fases, repetir,
/// play/pausa y cámara lenta (0.5x).
class AvatarPlaybackControls extends StatelessWidget {
  const AvatarPlaybackControls({required this.controller, super.key});

  final AvatarPlaybackController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Timeline(controller: controller),
            const SizedBox(height: 10),
            Row(
              children: [
                _RoundIconButton(
                  icon: Icons.replay_rounded,
                  tooltip: 'Repetir seña',
                  onTap: controller.replay,
                ),
                const SizedBox(width: 12),
                _PlayButton(controller: controller),
                const Spacer(),
                _SpeedToggle(controller: controller),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra de progreso arrastrable con marcas en cada keyframe (fases).
class _Timeline extends StatelessWidget {
  const _Timeline({required this.controller});

  final AvatarPlaybackController controller;

  @override
  Widget build(BuildContext context) {
    final marks = controller.animation.keyframeTimes;
    return LayoutBuilder(
      builder: (context, box) {
        void seekAt(double dx) => controller.seek(dx / box.maxWidth);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => seekAt(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => seekAt(d.localPosition.dx),
          child: SizedBox(
            height: 28,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: controller.progress.clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2DD4BF), AppColors.primary],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                for (final m in marks)
                  Positioned(
                    left: (box.maxWidth * m - 2).clamp(0.0, box.maxWidth - 4),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: controller.progress >= m
                            ? Colors.white
                            : AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                Positioned(
                  left: (box.maxWidth * controller.progress - 9)
                      .clamp(0.0, box.maxWidth - 18),
                  child: AnimatedScale(
                    scale: controller.isPlaying ? 1 : 1.15,
                    duration: const Duration(milliseconds: 180),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 3),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.controller});

  final AvatarPlaybackController controller;

  @override
  Widget build(BuildContext context) {
    final playing = controller.isPlaying;
    return _Pressable(
      onTap: controller.togglePlay,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2DD4BF), AppColors.primary],
          ),
          borderRadius: BorderRadius.circular(playing ? 20 : 29),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, a) =>
              ScaleTransition(scale: a, child: child),
          child: Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            key: ValueKey(playing),
            color: Colors.white,
            size: 32,
            semanticLabel: playing ? 'Pausar' : 'Reproducir',
          ),
        ),
      ),
    );
  }
}

/// Selector 0.5x / 1x con indicador que se desliza.
class _SpeedToggle extends StatelessWidget {
  const _SpeedToggle({required this.controller});

  final AvatarPlaybackController controller;

  @override
  Widget build(BuildContext context) {
    final slow = controller.speed == PlaybackSpeed.slow;
    return Semantics(
      label: 'Velocidad: ${controller.speed.label}',
      button: true,
      child: _Pressable(
        onTap: () => controller
            .setSpeed(slow ? PlaybackSpeed.normal : PlaybackSpeed.slow),
        child: Container(
          width: 132,
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                alignment: slow ? Alignment.centerLeft : Alignment.centerRight,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: Container(
                  width: 62,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.18),
                          blurRadius: 6),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  _speedLabel(Icons.slow_motion_video_rounded, '0.5x', slow),
                  _speedLabel(null, '1x', !slow),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _speedLabel(IconData? icon, String text, bool active) {
    final color = active ? AppColors.primary : AppColors.muted;
    // FittedBox: con texto agrandado (accesibilidad) se achica en vez de desbordar.
    return Expanded(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 3),
            ],
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: color,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                fontSize: 14,
              ),
              child: Text(text),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton(
      {required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: _Pressable(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: AppColors.primary, semanticLabel: tooltip),
        ),
      ),
    );
  }
}

/// Micro-interacción: se encoge al presionar y vibra suave al soltar.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  void _set(bool value) => setState(() => _down = value);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) {
        _set(false);
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.9 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
