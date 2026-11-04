import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:senasgo/core/constants/app_constants.dart';
import 'package:senasgo/core/services/inference_service.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/core/vision/frame_processor.dart';
import 'package:senasgo/features/practice/presentation/controllers/practice_controller.dart';

/// Tarjeta de cámara con el recuadro guía de encuadre (estados 3, 4, 6 y 7).
class CameraOverlay extends StatelessWidget {
  const CameraOverlay({required this.state, this.controller, super.key});

  final PracticeState state;
  final CameraController? controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final live = state.showsCamera && c != null && c.value.isInitialized;
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
              // Velos oscuros: el texto blanco se lee aunque la imagen sea clara.
              const _Scrim(top: true),
              const _Scrim(top: false),
              _topBar(),
              Center(
                child: FractionallySizedBox(
                  widthFactor: AppConstants.guideBoxFraction,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: _boxColor, width: 3),
                      ),
                      child: live && state.handVisible
                          ? null
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.back_hand_outlined,
                                    size: 88,
                                    color: _boxColor.withValues(alpha: 0.7)),
                                const SizedBox(height: 12),
                                Text(_boxLabel,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 14)),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              Positioned(left: 0, right: 0, bottom: 18, child: _statusLine()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    final edge = state.mode == EngineMode.edgeAi;
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
              edge ? 'EDGE AI' : 'SIMULADA',
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

  Widget _statusLine() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.circle, size: 8, color: _boxColor),
            const SizedBox(width: 8),
            Text(_statusText,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        if (state.mode == EngineMode.conceptual) ...[
          const SizedBox(height: 4),
          const Text('Contorno ilustrativo · Pendiente de validación LSPy',
              style: TextStyle(color: Colors.white60, fontSize: 11.5)),
        ],
      ],
    );
  }

  Color get _boxColor {
    if (state.stage == PracticeStage.handNotDetected ||
        state.lighting != LightingStatus.ok) {
      return const Color(0xFFF5C9A8);
    }
    if (state.stage == PracticeStage.evaluating) return const Color(0xFFA8E6CF);
    if (state.handVisible) return const Color(0xFFA8E6CF);
    return const Color(0xFFBFD9FF);
  }

  String get _boxLabel => state.stage == PracticeStage.handNotDetected
      ? 'Mano fuera del área'
      : 'Área para tu mano';

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
    return switch (state.stage) {
      PracticeStage.framing =>
        state.handVisible ? 'Mano dentro del recuadro' : 'Vista de encuadre',
      PracticeStage.capturing => 'Detectando...',
      PracticeStage.evaluating => 'Evaluando ejecución...',
      PracticeStage.handNotDetected => 'Sin detección',
      _ => '',
    };
  }
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
      height: top ? 72 : 96,
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
