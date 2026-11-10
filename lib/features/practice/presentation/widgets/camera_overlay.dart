import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:senasgo/core/services/inference_service.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/core/vision/frame_processor.dart';
import 'package:senasgo/core/vision/hand_landmarks.dart';
import 'package:senasgo/core/vision/vision_frame.dart';
import 'package:senasgo/features/practice/presentation/controllers/practice_controller.dart';

/// Tarjeta de cámara con la guía de encuadre (estados 3, 4, 6 y 7).
///
/// La seña se evalúa respecto del cuerpo (cara, mentón, pecho), así que la
/// guía pide encuadre de medio cuerpo: cabeza y hombros dentro de la imagen.
/// Con el detector real se dibujan en vivo los puntos de la mano.
class CameraOverlay extends StatelessWidget {
  const CameraOverlay({required this.state, this.controller, super.key});

  final PracticeState state;
  final CameraController? controller;

  static const _ok = Color(0xFFA8E6CF);
  static const _warn = Color(0xFFF5C9A8);
  static const _idle = Color(0xFFBFD9FF);

  bool get _edge => state.mode == EngineMode.edgeAi;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final live = state.showsCamera && c != null && c.value.isInitialized;
    final frame = state.frame;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: ColoredBox(
          color: AppColors.cameraCard,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (live)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    // previewSize viene en horizontal: se invierte para vertical.
                    width: c.value.previewSize?.height ?? 480,
                    height: c.value.previewSize?.width ?? 640,
                    child: CameraPreview(c),
                  ),
                ),
              // Silueta de medio cuerpo: dónde ubicar cabeza y hombros.
              IgnorePointer(
                child: CustomPaint(
                  painter: _BodyGuidePainter(
                    color: _guideColor,
                    filled: !live || !state.bodyVisible,
                  ),
                ),
              ),
              if (state.showsCamera && _edge && frame != null)
                IgnorePointer(
                  child: CustomPaint(painter: _HandPainter(frame)),
                ),
              // Velos oscuros: el texto blanco se lee aunque la imagen sea clara.
              const _Scrim(top: true),
              const _Scrim(top: false),
              _topBar(),
              Positioned(left: 12, right: 12, bottom: 16, child: _status()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Positioned(
      top: 14,
      left: 16,
      right: 14,
      child: Row(
        children: [
          const Icon(Icons.photo_camera_outlined,
              color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Text('Cámara frontal',
              style: TextStyle(color: Colors.white, fontSize: 14)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _edge ? 'EDGE AI' : 'SIMULADA',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _status() {
    final checks = _edge &&
        state.lighting == LightingStatus.ok &&
        (state.stage == PracticeStage.framing ||
            state.stage == PracticeStage.capturing);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (checks) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Check(label: 'Cara y hombros', ok: state.bodyVisible),
              const SizedBox(width: 8),
              _Check(label: 'Mano', ok: state.handVisible),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.circle, size: 8, color: _guideColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(_statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        if (!_edge) ...[
          const SizedBox(height: 4),
          const Text('Contorno ilustrativo · Pendiente de validación LSPy',
              style: TextStyle(color: Colors.white60, fontSize: 11.5)),
        ],
      ],
    );
  }

  Color get _guideColor {
    if (state.stage == PracticeStage.handNotDetected ||
        state.lighting != LightingStatus.ok) {
      return _warn;
    }
    if (state.stage == PracticeStage.evaluating) return _ok;
    if (_edge) {
      if (state.bodyVisible && state.handVisible) return _ok;
      return _idle;
    }
    return state.handVisible ? _ok : _idle;
  }

  String get _statusText {
    switch (state.lighting) {
      case LightingStatus.tooDark:
        return 'Ambiente muy oscuro';
      case LightingStatus.backlit:
        return 'Contraluz: hay una luz fuerte detrás de ti';
      case LightingStatus.overexposed:
        return 'Demasiada luz sobre la mano';
      case LightingStatus.ok:
        break;
    }
    switch (state.stage) {
      case PracticeStage.framing:
      case PracticeStage.capturing:
        if (!_edge) {
          return state.stage == PracticeStage.capturing
              ? 'Detectando...'
              : 'Vista de encuadre';
        }
        if (!state.bodyVisible) {
          return 'Aleja el teléfono: que se vean tu cara y tus hombros';
        }
        if (!state.handVisible) return 'Levanta la mano para empezar';
        return state.stage == PracticeStage.capturing
            ? 'Detectando...'
            : 'Todo listo: toca Comenzar';
      case PracticeStage.evaluating:
        return 'Haz la seña ahora';
      case PracticeStage.handNotDetected:
        return 'Sin detección';
      default:
        return '';
    }
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (ok ? CameraOverlay._ok : Colors.white)
            .withValues(alpha: ok ? 0.25 : 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 15, color: ok ? CameraOverlay._ok : Colors.white70),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Contorno de cabeza y hombros en la parte superior de la imagen.
class _BodyGuidePainter extends CustomPainter {
  const _BodyGuidePainter({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color.withValues(alpha: filled ? 0.9 : 0.45);
    final head = Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.30), width: w * 0.28, height: h * 0.25);
    final shoulders = Path()
      ..moveTo(w * 0.08, h * 0.80)
      ..quadraticBezierTo(w * 0.10, h * 0.50, w * 0.36, h * 0.49)
      ..lineTo(w * 0.64, h * 0.49)
      ..quadraticBezierTo(w * 0.90, h * 0.50, w * 0.92, h * 0.80);
    if (filled) {
      final fill = Paint()..color = color.withValues(alpha: 0.08);
      canvas.drawOval(head, fill);
    }
    canvas.drawOval(head, stroke);
    canvas.drawPath(shoulders, stroke);
  }

  @override
  bool shouldRepaint(_BodyGuidePainter old) =>
      old.color != color || old.filled != filled;
}

/// Puntos y huesos de las manos detectadas, sobre la vista previa.
class _HandPainter extends CustomPainter {
  const _HandPainter(this.frame);

  final VisionFrame frame;

  static const _bones = [
    [0, 1, 2, 3, 4],
    [0, 5, 6, 7, 8],
    [5, 9, 10, 11, 12],
    [9, 13, 14, 15, 16],
    [13, 17, 18, 19, 20],
    [0, 17],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // La vista previa se muestra con BoxFit.cover: se aplica la misma escala.
    final a = frame.aspect;
    double drawW, drawH;
    if (size.width / size.height > a) {
      drawW = size.width;
      drawH = size.width / a;
    } else {
      drawH = size.height;
      drawW = size.height * a;
    }
    final dx = (size.width - drawW) / 2, dy = (size.height - drawH) / 2;
    Offset at(Vec3 p) => Offset(dx + p.x * drawW, dy + p.y * drawH);

    final active = frame.activeHand;
    for (final hand in frame.hands) {
      final main = identical(hand, active);
      final line = Paint()
        ..strokeWidth = main ? 3 : 2
        ..strokeCap = StrokeCap.round
        ..color = (main ? CameraOverlay._ok : Colors.white)
            .withValues(alpha: main ? 0.9 : 0.5);
      for (final chain in _bones) {
        for (var i = 1; i < chain.length; i++) {
          canvas.drawLine(
              at(hand.point(chain[i - 1])), at(hand.point(chain[i])), line);
        }
      }
      final dot = Paint()..color = Colors.white.withValues(alpha: 0.95);
      for (var i = 0; i < 21; i++) {
        canvas.drawCircle(at(hand.point(i)), main ? 3.2 : 2.4, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_HandPainter old) => !identical(old.frame, frame);
}

class _Scrim extends StatelessWidget {
  const _Scrim({required this.top});

  final bool top;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: top ? 0 : null,
      bottom: top ? null : 0,
      height: top ? 72 : 110,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: top ? Alignment.topCenter : Alignment.bottomCenter,
              end: top ? Alignment.bottomCenter : Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.55),
                Colors.transparent
              ],
            ),
          ),
        ),
      ),
    );
  }
}
