import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:senasgo/core/services/device_performance.dart';

/// Causa por la que la cámara no está disponible (contingencia de hardware).
enum CameraIssue {
  none,
  permissionDenied,
  permissionPermanentlyDenied,
  noCamera,
  busy
}

/// Inicialización segura de la cámara y lectura del ImageStream limitada a
/// 10-15 FPS (control térmico).
class CameraService extends ChangeNotifier {
  CameraService(this.cameras);

  final List<CameraDescription> cameras;
  final Logger _logger = Logger();

  CameraController? _controller;
  CameraIssue _issue = CameraIssue.none;
  bool _initializing = false;
  bool _streaming = false;
  bool _disposed = false;
  int _lastFrameMs = 0;
  void Function(CameraImage image)? _onFrame;

  CameraController? get controller => _controller;
  bool get isReady => _controller?.value.isInitialized ?? false;
  bool get isStreaming => _streaming;
  CameraIssue get issue => _issue;

  CameraDescription? get _description => _controller?.description;

  /// Rotación horaria para ver el fotograma derecho (app fija en vertical).
  int get rotationDeg => _description?.sensorOrientation ?? 0;

  /// La cámara frontal se espeja, igual que la vista previa.
  bool get isFrontCamera =>
      _description?.lensDirection == CameraLensDirection.front;

  /// Pide el permiso y abre la cámara frontal. Nunca lanza excepciones:
  /// cualquier falla queda en [issue] para que la UI muestre la contingencia.
  Future<CameraIssue> initialize() async {
    if (isReady) return CameraIssue.none;
    if (_initializing) return _issue;
    _initializing = true;
    try {
      _issue = await _ensurePermission();
      if (_issue != CameraIssue.none) return _issue;

      if (cameras.isEmpty) return _issue = CameraIssue.noCamera;

      final description = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        description,
        // Resolución baja: el modelo solo necesita 224x224 y se calienta menos.
        DevicePerformance.isLowMemory
            ? ResolutionPreset.low
            : ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      _controller = controller;
      return _issue = CameraIssue.none;
    } on CameraException catch (e) {
      _logger.w('Cámara no disponible: ${e.code} ${e.description}');
      await _controller?.dispose();
      _controller = null;
      return _issue = switch (e.code) {
        'CameraAccessDenied' ||
        'cameraPermission' =>
          CameraIssue.permissionDenied,
        'CameraAccessDeniedWithoutPrompt' ||
        'CameraAccessRestricted' =>
          CameraIssue.permissionPermanentlyDenied,
        // Sensor ocupado por otra app, desconectado o error del driver.
        _ => CameraIssue.busy,
      };
    } catch (e) {
      _logger.e('Error inesperado al abrir la cámara: $e');
      return _issue = CameraIssue.busy;
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<CameraIssue> _ensurePermission() async {
    var status = await Permission.camera.status;
    if (status.isDenied) status = await Permission.camera.request();
    if (status.isGranted || status.isLimited) return CameraIssue.none;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return CameraIssue.permissionPermanentlyDenied;
    }
    return CameraIssue.permissionDenied;
  }

  /// Inicia el flujo de imágenes con descarte de fotogramas para no superar
  /// [DevicePerformance.targetFps] (10-15 FPS; nunca los 30-60 del sensor).
  Future<void> startImageStream(
      void Function(CameraImage image) onFrame) async {
    final c = _controller;
    _onFrame = onFrame;
    if (c == null || !c.value.isInitialized || c.value.isStreamingImages) {
      return;
    }

    final minIntervalMs = 1000 ~/ DevicePerformance.targetFps;
    try {
      await c.startImageStream((image) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastFrameMs < minIntervalMs) return;
        _lastFrameMs = now;
        _onFrame?.call(image);
      });
      _streaming = true;
    } on CameraException catch (e) {
      _logger.w('No se pudo iniciar el stream: ${e.code}');
      _issue = CameraIssue.busy;
    }
    notifyListeners();
  }

  /// Detiene el análisis (feedback, pausa, app en segundo plano): ahorra
  /// batería y evita sobrecalentamiento.
  Future<void> stopImageStream() async {
    final c = _controller;
    _streaming = false;
    if (c != null && c.value.isInitialized && c.value.isStreamingImages) {
      try {
        await c.stopImageStream();
      } on CameraException catch (e) {
        _logger.w('Error al detener el stream: ${e.code}');
      }
    }
    notifyListeners();
  }

  /// Libera el sensor (por ejemplo al pasar la app a segundo plano).
  Future<void> release() async {
    await stopImageStream();
    final c = _controller;
    _controller = null;
    await c?.dispose();
    notifyListeners();
  }

  Future<bool> openSettings() => openAppSettings();

  /// Las operaciones de la cámara son asíncronas y pueden terminar después
  /// de cerrar la pantalla de práctica: en ese caso no se notifica a nadie.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _onFrame = null;
    final c = _controller;
    _controller = null;
    c?.dispose();
    super.dispose();
  }
}
