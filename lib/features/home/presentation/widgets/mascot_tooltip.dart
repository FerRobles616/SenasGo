import 'package:flutter/material.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/shared/widgets/jaguarete_mascot.dart';

/// El jaguareté con un globo de texto motivador. Tocarlo cambia el mensaje.
class MascotTooltip extends StatefulWidget {
  const MascotTooltip(
      {required this.messages, this.mood = MascotMood.happy, super.key});

  final List<String> messages;
  final MascotMood mood;

  @override
  State<MascotTooltip> createState() => _MascotTooltipState();
}

class _MascotTooltipState extends State<MascotTooltip> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final message = widget.messages[_index % widget.messages.length];
    return Semantics(
      label: 'Jaguareté dice: $message',
      button: widget.messages.length > 1,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => setState(() => _index++),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.85, end: 1),
          duration: const Duration(milliseconds: 450),
          curve: Curves.elasticOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              JaguareteMascot(size: 76, mood: widget.mood),
              const SizedBox(width: 6),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _SpeechBubble(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Text(
                        message,
                        key: ValueKey(message),
                        style: TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BubblePainter(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 14, 12),
        child: child,
      ),
    );
  }
}

/// Globo con borde y "colita" hacia la mascota (izquierda).
class _BubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tail = 10.0;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(tail, 0, size.width - tail, size.height),
      const Radius.circular(16),
    );
    final path = Path()
      ..addRRect(body)
      ..moveTo(tail, size.height - 26)
      ..lineTo(0, size.height - 14)
      ..lineTo(tail, size.height - 12)
      ..close();
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
