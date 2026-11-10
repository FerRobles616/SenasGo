import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:senasgo/core/vision/vision_frame.dart';

/// Contrato del motor de puntos de manos y cuerpo.
abstract class LandmarkEngine {
  /// Carga los modelos. Devuelve true si el detector real está listo.
  Future<bool> load();

  /// Detecta manos y cuerpo en una imagen RGBA derecha y espejada.
  Future<VisionFrame?> detect(
    Uint8List rgba, {
    required int width,
    required int height,
    required DateTime timestamp,
  });

  void dispose();
}

/// MediaPipe Tasks (HandLandmarker + PoseLandmarker) a través del canal
/// nativo `senasgo/vision` (Android: VisionChannel.kt).
///
/// Donde no hay canal (web, iOS por ahora, tests) [load] devuelve false y la
/// práctica queda en modo conceptual.
class MediaPipeLandmarkEngine implements LandmarkEngine {
  MediaPipeLandmarkEngine({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('senasgo/vision');

  final MethodChannel _channel;
  final Logger _logger = Logger();
  bool _ready = false;

  /// Delegado que usa el equipo ("gpu" o "cpu"); para diagnóstico.
  String delegate = 'none';

  @override
  Future<bool> load() async {
    if (_ready) return true;
    try {
      final r = await _channel.invokeMapMethod<String, Object?>('load');
      _ready = r?['ok'] == true;
      delegate = r?['delegate']?.toString() ?? 'none';
      if (!_ready) _logger.w('MediaPipe no se pudo cargar.');
    } on MissingPluginException {
      _ready = false;
    } on PlatformException catch (e) {
      _logger.w('MediaPipe no disponible: ${e.message}');
      _ready = false;
    }
    return _ready;
  }

  @override
  Future<VisionFrame?> detect(
    Uint8List rgba, {
    required int width,
    required int height,
    required DateTime timestamp,
  }) async {
    if (!_ready) return null;
    try {
      final r = await _channel.invokeMethod<Map<Object?, Object?>>('detect', {
        'rgba': rgba,
        'width': width,
        'height': height,
        'timestampMs': timestamp.millisecondsSinceEpoch,
      });
      if (r == null) return null;
      return VisionFrame.fromMap(r, aspect: width / height,
          timestamp: timestamp);
    } on PlatformException catch (e) {
      _logger.w('Error del detector: ${e.message}');
      return null;
    }
  }

  @override
  void dispose() {
    if (!_ready) return;
    _ready = false;
    _channel.invokeMethod<void>('close').catchError((_) {});
  }
}
