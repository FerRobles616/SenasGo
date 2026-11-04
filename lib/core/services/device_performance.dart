import 'package:flutter/foundation.dart';
import 'package:senasgo/core/constants/app_constants.dart';
import 'package:senasgo/core/services/device_memory_stub.dart'
    if (dart.library.io) 'package:senasgo/core/services/device_memory_io.dart'
    as memory;

/// Detecta la capacidad del dispositivo para decidir el nivel de detalle
/// del avatar del profesor (Fallback Visual por poca RAM) y el FPS de análisis.
class DevicePerformance {
  DevicePerformance._();

  /// Por debajo de esta RAM total el avatar Rive pasa a 2D estático.
  static const int lowRamBytes = 3 * 1024 * 1024 * 1024; // 3 GB

  static bool _lowMemory = false;

  static bool get isLowMemory => _lowMemory;

  /// FPS de análisis (control térmico 10-15 FPS).
  static int get targetFps =>
      _lowMemory ? AppConstants.targetFpsMin : AppConstants.targetFpsMax;

  /// Se llama una vez en main(). En Android lee la RAM física total desde
  /// /proc/meminfo (no requiere permisos). iOS no expone ese dato sin código
  /// nativo; los iPhone soportados (iOS 15+) tienen 2 GB o más y se tratan
  /// como capaces.
  static Future<void> init() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final bytes = await memory.totalRamBytes();
    // Si no se puede medir se asume capacidad suficiente.
    _lowMemory = bytes != null && bytes < lowRamBytes;
  }
}
