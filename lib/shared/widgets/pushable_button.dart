import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Botón "físico" estilo Duolingo: una cara de color sobre un borde inferior
/// más oscuro. Al presionarlo la cara baja y el borde desaparece, como una
/// tecla real.
class PushableButton extends StatefulWidget {
  const PushableButton({
    required this.child,
    required this.color,
    required this.shadowColor,
    required this.onPressed,
    this.height = 56,
    this.width,
    this.depth = 5,
    this.borderRadius = 16,
    this.circle = false,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final Color color;
  final Color shadowColor;
  final VoidCallback? onPressed;
  final double height;
  final double? width;

  /// Altura del borde inferior (profundidad 3D).
  final double depth;
  final double borderRadius;
  final bool circle;
  final String? semanticLabel;

  @override
  State<PushableButton> createState() => _PushableButtonState();
}

class _PushableButtonState extends State<PushableButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool value) {
    if (_enabled && _pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final shape = widget.circle
        ? const BoxDecoration(shape: BoxShape.circle)
        : BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius));
    final offset = _pressed ? widget.depth : 0.0;

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) {
          _setPressed(false);
          if (_enabled) {
            HapticFeedback.lightImpact();
            widget.onPressed!();
          }
        },
        child: SizedBox(
          width: widget.width,
          height: widget.height + widget.depth,
          child: Stack(
            children: [
              // Borde inferior (sombra sólida)
              Positioned(
                left: 0,
                right: 0,
                top: widget.depth,
                bottom: 0,
                child: DecoratedBox(
                  decoration: shape.copyWith(color: widget.shadowColor),
                ),
              ),
              // Cara del botón
              AnimatedPositioned(
                duration: const Duration(milliseconds: 70),
                curve: Curves.easeOut,
                left: 0,
                right: 0,
                top: offset,
                height: widget.height,
                child: DecoratedBox(
                  decoration: shape.copyWith(color: widget.color),
                  child: Center(child: widget.child),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
