import 'package:flutter/material.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/home/domain/learning_path.dart';
import 'package:senasgo/shared/widgets/pushable_button.dart';

/// Nodo circular del camino. La seña actual rebota y queda resaltada; el
/// botón EMPEZAR vive en la tarjeta de la unidad para no duplicar acciones.
class LessonNode extends StatefulWidget {
  const LessonNode(
      {required this.node,
      required this.palette,
      required this.onTap,
      this.link,
      super.key});

  static const double size = 78;

  /// Alto reservado para el nodo y su etiqueta; la seña actual suma el halo.
  static double slotHeightFor({required bool current}) => current ? 142 : 130;

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
              const SizedBox(height: 6),
              _anchor(Transform.translate(
                offset: Offset(0, dy),
                child: _isCurrent
                    ? _Halo(color: widget.palette.face, child: button)
                    : button,
              )),
              const SizedBox(height: 6),
              // Pequeña placa que separa el nombre del sendero sin cortarlo
              // de forma brusca.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                ),
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
            ],
          );
        },
      ),
    );
  }

  /// El enganche rodea al botón por fuera del rebote: el popover queda pegado
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
