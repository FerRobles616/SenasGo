import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:senasgo/core/services/device_performance.dart';
import 'package:senasgo/core/services/hive_service.dart';

/// Datos técnicos mínimos para reproducir un problema. Nunca incluye fotos,
/// nombres ni la posición de la cámara: solo versión, plataforma y avance.
class SupportDiagnostics {
  const SupportDiagnostics._();

  static Future<Map<String, String>> collect() async {
    var version = 'desconocida';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version}+${info.buildNumber}';
    } catch (_) {
      // En tests o entornos sin el plugin se deja "desconocida".
    }

    final platform = _platform();
    final progress = _safeProgress();
    return {
      'app': 'SeñasGo $version',
      'plataforma': platform,
      'dispositivo': DevicePerformance.isLowMemory ? 'gama baja' : 'estándar',
      if (progress != null) ...progress,
    };
  }

  static String _platform() {
    if (kIsWeb) return 'Web / desconocida';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
  }

  static Map<String, String>? _safeProgress() {
    try {
      final user = HiveService.currentUser;
      final progress = HiveService.progress;
      return {
        'nivel': '${user.level}',
        'xp': '${user.xp}',
        'señas_aprendidas': '${progress.completedSignIds.length}',
        'intentos': '${progress.totalAttempts}',
      };
    } catch (_) {
      return null;
    }
  }
}
