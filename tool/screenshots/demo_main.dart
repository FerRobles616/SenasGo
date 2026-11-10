// Modo demostración para las capturas de la documentación.
//
// Arranca la app real con datos de ejemplo y sin iniciar sesión en ninguna
// cuenta. La práctica con cámara reproduce puntos de mano grabados (una
// persona haciendo "Hola"), así que el evaluador real decide el resultado.
//
// Uso:
//   flutter build web -t tool/screenshots/demo_main.dart \
//       --dart-define-from-file=supabase.json
//   Parámetros de la URL (antes del #):
//     ?modo=auth   pantalla de ingreso (sin sesión)
//     ?modo=nuevo  cuenta recién creada (bienvenida)
//     (sin modo)   cuenta con progreso de ejemplo
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:senasgo/core/config/hive_config.dart';
import 'package:senasgo/core/services/camera_service.dart';
import 'package:senasgo/core/services/device_performance.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/core/services/inference_service.dart';
import 'package:senasgo/core/services/landmark_engine.dart';
import 'package:senasgo/core/theme/theme_controller.dart';
import 'package:senasgo/core/vision/vision_frame.dart';
import 'package:senasgo/features/cloud/data/cloud_sync_service.dart';
import 'package:senasgo/features/support/data/support_repository.dart';
import 'package:senasgo/features/support/domain/support_ticket.dart';
import 'package:senasgo/main.dart';
import 'package:senasgo/shared/models/user_model.dart';

import 'hola_landmarks.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final mode = Uri.base.queryParameters['modo'] ?? 'demo';
  await DevicePerformance.init();
  await HiveConfig.init();
  await HiveService.registerAdapters();
  await HiveService.initBoxes();
  await HiveService.clearUserData();
  await HiveService.seedIfEmpty();
  await HiveService.saveUser(UserModel.initial());
  ThemeController.init();
  await CloudSyncService.initialize();

  if (mode != 'auth') {
    CloudSyncService.debugSignedIn = true;
    await HiveService.updateUsername('Ana');
    if (mode == 'demo') await _seedProgress();
  }

  runApp(MyApp(
    cameras: const [],
    cameraServiceBuilder: _ReplayCamera.new,
    inferenceServiceBuilder: () =>
        InferenceService(engine: _ReplayEngine()),
  ));
}

Future<void> _seedProgress() async {
  await HiveService.setOnboardingDone(true);
  await HiveService.claimWelcomeReward();
  for (final id in ['saludo_hola', 'saludo_chau', 'saludo_saludos']) {
    await HiveService.recordAttempt(signId: id, correct: true);
  }
  await HiveService.recordAttempt(signId: 'numero_uno', correct: false);
  await HiveService.recordAttempt(signId: 'numero_uno', correct: true);
  await HiveService.markLessonCompleted('leccion_saludos');
  // Racha de ejemplo: los últimos 6 días con práctica.
  final now = DateTime.now();
  String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  await HiveService.gameBox.put('practiceDays', [
    for (var i = 5; i >= 0; i--) key(now.subtract(Duration(days: i))),
  ]);
  await HiveService.gameBox.put('streakDays', 6);
  await HiveService.gameBox.put('bestStreak', 9);
  await HiveService.gameBox.put('streakDate', now);
  await HiveService.setReminder(weekday: DateTime.monday, hour: 19, minute: 0);

  final sent = SupportTicket.create(
    category: SupportCategory.content,
    message: 'En la seña Gracias, el profesor podría separar más la mano '
        'del mentón.',
    context: 'Lección Palabras básicas',
  );
  await SupportRepository.save(sent);
  await SupportRepository.markSent(
      sent.id, now.subtract(const Duration(hours: 3)));
  final solved = SupportTicket.create(
    category: SupportCategory.bug,
    message: 'La cámara tardó en abrir la primera vez.',
    context: 'Práctica',
  );
  await SupportRepository.save(solved);
  await SupportRepository.markSent(
      solved.id, now.subtract(const Duration(days: 2)));
  await SupportRepository.setResolved(solved.id, true);
}

/// Cámara simulada: entrega un cuadro gris parejo 10 veces por segundo.
class _ReplayCamera extends CameraService {
  _ReplayCamera() : super(const []);

  Timer? _timer;
  bool _on = false;

  static const _w = 64, _h = 48;
  // ignore: deprecated_member_use
  static final CameraImage _image = CameraImage.fromPlatformData({
    'format': 35,
    'width': _w,
    'height': _h,
    'planes': [
      {
        'bytes': Uint8List(_w * _h)..fillRange(0, _w * _h, 120),
        'bytesPerRow': _w,
        'bytesPerPixel': 1,
      },
      for (var i = 0; i < 2; i++)
        {
          'bytes': Uint8List(_w * _h ~/ 4)..fillRange(0, _w * _h ~/ 4, 128),
          'bytesPerRow': _w ~/ 2,
          'bytesPerPixel': 1,
        },
    ],
  });

  @override
  Future<CameraIssue> initialize() async => CameraIssue.none;

  @override
  bool get isStreaming => _on;

  @override
  int get rotationDeg => 0;

  @override
  bool get isFrontCamera => true;

  @override
  Future<void> startImageStream(
      void Function(CameraImage image) onFrame) async {
    _timer?.cancel();
    _on = true;
    _ReplayEngine.restart();
    _timer = Timer.periodic(
        const Duration(milliseconds: 100), (_) => onFrame(_image));
  }

  @override
  Future<void> stopImageStream() async {
    _timer?.cancel();
    _on = false;
  }

  @override
  Future<void> release() => stopImageStream();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Detector simulado: devuelve, cuadro a cuadro, los puntos grabados.
class _ReplayEngine implements LandmarkEngine {
  static final List<VisionFrame> _frames =
      VisionFrame.listFromJson(holaLandmarks);
  static int _next = 0;
  static const int _hold = 26;

  static void restart() => _next = 0;

  @override
  Future<bool> load() async => true;

  @override
  Future<VisionFrame?> detect(
    Uint8List rgba, {
    required int width,
    required int height,
    required DateTime timestamp,
  }) async {
    // Después del saludo la mano queda quieta en alto (último cuadro con la
    // mano levantada), sin saltos que parezcan un movimiento.
    final f = _frames[_next < _hold ? _next++ : _hold];
    return VisionFrame(
        hands: f.hands, body: f.body, aspect: f.aspect, timestamp: timestamp);
  }

  @override
  void dispose() {}
}
