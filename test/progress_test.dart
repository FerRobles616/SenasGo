import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/shared/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('senasgo_progress');
    Hive.init(dir.path);
    await HiveService.registerAdapters();
    await HiveService.initBoxes();
    await HiveService.seedIfEmpty();
  });

  setUp(() async {
    await HiveService.progressBox.clear();
    await HiveService.gameBox.clear();
    await HiveService.userBox.clear();
    await HiveService.saveUser(UserModel.initial());
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  test('Una seña correcta suma XP y la marca como aprendida', () async {
    final user = await HiveService.recordAttempt(
      signId: 'saludo_hola',
      correct: true,
    );

    expect(user.xp, 10);
    expect(HiveService.progress.completedSignIds, contains('saludo_hola'));
    expect(HiveService.recentAttempts.first.signId, 'saludo_hola');
    expect(HiveService.recentAttempts.first.correct, isTrue);
  });

  test('Un intento incorrecto no suma XP y conserva el progreso', () async {
    final user = await HiveService.recordAttempt(
      signId: 'saludo_hola',
      correct: false,
    );

    expect(user.xp, 0);
    expect(HiveService.progress.totalAttempts, 1);
    expect(HiveService.progress.correctAttempts, 0);
  });

  test('Los intentos recientes se ordenan del más nuevo al más viejo',
      () async {
    await HiveService.recordAttempt(signId: 'saludo_hola', correct: true);
    await HiveService.recordAttempt(signId: 'numero_uno', correct: false);

    final attempts = HiveService.recentAttempts;
    expect(attempts, hasLength(2));
    expect(attempts.first.signId, 'numero_uno');
    expect(attempts.last.signId, 'saludo_hola');
  });

  test('Los umbrales de nivel son coherentes', () {
    expect(HiveService.xpForLevel(1), 0);
    expect(HiveService.xpForLevel(5), 1000);
    expect(HiveService.xpToNextLevel(0), 100);
    expect(HiveService.xpToNextLevel(1000), isNull);
  });
}
