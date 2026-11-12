import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:senasgo/core/theme/app_theme.dart';

/// Confeti decorativo, nativo y de una sola reproducción.
///
/// No usa paquetes externos ni bloquea la interacción. Respeta la preferencia
/// del sistema de reducir animaciones: en ese caso no dibuja partículas.
class CelebrationConfetti extends StatefulWidget {
  const CelebrationConfetti({
    this.active = true,
    this.particleCount = 24,
    this.duration = const Duration(milliseconds: 1500),
    this.colors,
    this.seed = 7,
    super.key,
  }) : assert(particleCount > 0);

  /// Cuando cambia de `false` a `true`, inicia una celebración nueva.
  final bool active;

  final int particleCount;
  final Duration duration;

  /// Colores de las partículas. Si es `null`, usa la paleta de la app.
  final List<Color>? colors;

  /// Semilla para que la celebración sea reproducible en tests y capturas.
  final int seed;

  @override
  State<CelebrationConfetti> createState() => _CelebrationConfettiState();
}

class _CelebrationConfettiState extends State<CelebrationConfetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late List<_ConfettiParticle> _particles = _buildParticles();
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.active && !_reduceMotion) {
          _controller.forward(from: 0);
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion == _reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _controller.stop();
      _controller.value = 0;
    } else if (widget.active &&
        !_controller.isAnimating &&
        _controller.isDismissed) {
      _controller.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(covariant CelebrationConfetti oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed != widget.seed ||
        oldWidget.particleCount != widget.particleCount) {
      _particles = _buildParticles();
    }
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.active && !oldWidget.active) {
      if (!_reduceMotion) _controller.forward(from: 0);
    } else if (!widget.active && oldWidget.active) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  List<_ConfettiParticle> _buildParticles() {
    final random = math.Random(widget.seed);
    return List.generate(widget.particleCount, (_) {
      return _ConfettiParticle(
        startX: 0.04 + random.nextDouble() * 0.92,
        delay: random.nextDouble() * 0.18,
        drift: (random.nextDouble() - 0.5) * 0.2,
        size: 4 + random.nextDouble() * 6,
        rotation: random.nextDouble() * math.pi * 2,
        spin: (random.nextDouble() - 0.5) * math.pi * 4,
        phase: random.nextDouble() * math.pi * 2,
        colorIndex: random.nextInt(5),
        circle: random.nextBool(),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active || _reduceMotion) return const SizedBox.shrink();
    final colors = widget.colors ??
        [
          AppColors.gold,
          AppColors.sky,
          AppColors.teal,
          AppColors.streak,
          AppColors.success,
        ];
    if (colors.isEmpty) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: SizedBox.expand(
            child: CustomPaint(
              painter: _ConfettiPainter(
                animation: _controller,
                particles: _particles,
                colors: colors,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfettiParticle {
  const _ConfettiParticle({
    required this.startX,
    required this.delay,
    required this.drift,
    required this.size,
    required this.rotation,
    required this.spin,
    required this.phase,
    required this.colorIndex,
    required this.circle,
  });

  final double startX;
  final double delay;
  final double drift;
  final double size;
  final double rotation;
  final double spin;
  final double phase;
  final int colorIndex;
  final bool circle;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.animation,
    required this.particles,
    required this.colors,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<_ConfettiParticle> particles;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    if (t >= 1) return;
    canvas.clipRect(Offset.zero & size);
    for (final particle in particles) {
      final local =
          ((t - particle.delay) / (1 - particle.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final fall = Curves.easeInCubic.transform(local);
      final x = size.width *
          (particle.startX +
              particle.drift * local +
              math.sin(local * math.pi * 2 + particle.phase) * 0.03);
      final y = size.height * (-0.08 + fall * 1.22);
      final opacity =
          local < 0.78 ? 1.0 : (1 - (local - 0.78) / 0.22).clamp(0.0, 1.0);
      final color = colors[particle.colorIndex % colors.length]
          .withValues(alpha: opacity);
      final paint = Paint()..color = color;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(particle.rotation + particle.spin * local);
      if (particle.circle) {
        canvas.drawCircle(Offset.zero, particle.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: particle.size,
              height: particle.size * 0.58,
            ),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => false;
}
