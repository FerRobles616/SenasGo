import 'package:flutter/material.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/home/domain/learning_path.dart';
import 'package:senasgo/shared/widgets/pushable_button.dart';

/// Nodo circular del camino. La seña actual rebota y muestra "EMPEZAR";
/// las bloqueadas van en gris con candado (no solo el color indica el estado).
class LessonNode extends StatefulWidget {
  const LessonNode(
      {required this.node,
      required this.palette,
      required this.onTap,
      this.link,
      super.key});

  static const double size = 78;

  /// Alto reservado: la seña actual suma el globo "EMPEZAR" y el halo.
  static double slotHeightFor({required bool current}) => current ? 184 : 130;

  final PathNode node;
  final UnitPalette palette;
  final VoidCallback onTap;

  /// Enganche del globo que se abre bajo el nodo (ver el camino).
  final LayerLink? link;

  @override
  State<LessonNode> createState() => _LessonNodeState();
}

class _LessonNodeState extends State<LessonNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));

  bool get _isCurrent => widget.node.status == NodeStatus.current;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant LessonNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_isCurrent && !reduceMotion) {
      if (!_bounce.isAnimating) _bounce.repeat(reverse: true);
    } else {
      _bounce.stop();
      _bounce.value = 0;
    }
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final locked = node.status == NodeStatus.locked;
    final face = locked ? AppColors.locked : widget.palette.face;
    final shade = locked ? AppColors.lockedShade : widget.palette.shade;

    final icon = switch (node.status) {
      NodeStatus.completed => Icons.check_rounded,
      NodeStatus.current => Icons.sign_language_rounded,
      NodeStatus.locked => Icons.lock_rounded,
    };
    final state = switch (node.status) {
      NodeStatus.completed => 'completada',
      NodeStatus.current => 'siguiente, toca para empezar',
      NodeStatus.locked => 'bloqueada',
    };

    final button = PushableButton(
      onPressed: widget.onTap,
      circle: true,
      color: face,
      shadowColor: shade,
      width: LessonNode.size,
      height: LessonNode.size - 6,
      depth: 6,
      semanticLabel: 'Seña ${node.sign.name}, $state',
      child: Icon(icon,
          size: 38, color: locked ? AppColors.lockedInk : Colors.white),
    );

    return SizedBox(
      width: 140,
      height: LessonNode.slotHeightFor(current: _isCurrent),
      child: AnimatedBuilder(
        animation: _bounce,
        builder: (context, child) {
          final dy = -8 * Curves.easeInOut.transform(_bounce.value);
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_isCurrent)
                Transform.translate(
                  offset: Offset(0, dy),
                  child: _StartBubble(color: widget.palette.face),
                ),
              const SizedBox(height: 6),
              _anchor(Transform.translate(
                offset: Offset(0, dy),
                child: _isCurrent
                    ? _Halo(color: widget.palette.face, child: button)
                    : button,
              )),
              const SizedBox(height: 6),
              // Fondo del camino: la línea pasa por detrás del nombre.
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  child: Text(
                    node.sign.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: locked ? AppColors.lockedInk : AppColors.ink,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// El enganche rodea al botón por fuera del rebote: el globo queda pegado
  /// al nodo pero no salta con la animación del nodo actual.
  Widget _anchor(Widget child) => widget.link == null
      ? child
      : CompositedTransformTarget(link: widget.link!, child: child);
}

/// Anillo suave alrededor del nodo actual.
class _Halo extends StatelessWidget {
  const _Halo({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.35), width: 5),
      ),
      child: child,
    );
  }
}

/// Globo "EMPEZAR" sobre la seña actual.
class _StartBubble extends StatelessWidget {
  const _StartBubble({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.16),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text('EMPEZAR',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0.5)),
        ),
        CustomPaint(size: const Size(14, 7), painter: _TailPainter()),
      ],
    );
  }
}

class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0);
    canvas.drawPath(path, Paint()..color = AppColors.surface);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
