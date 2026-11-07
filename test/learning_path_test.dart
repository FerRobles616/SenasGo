import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:senasgo/core/constants/app_constants.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/home/domain/learning_path.dart';
import 'package:senasgo/features/home/presentation/views/learning_path_view.dart';
import 'package:senasgo/features/learning/data/seed_data.dart';
import 'package:senasgo/shared/models/user_model.dart';

const _stats = PlayerStats(
  streak: 3,
  practicedToday: true,
  energy: 4,
  maxEnergy: 5,
  xp: 30,
);

LearningPath _pathWith(Set<String> learned) => LearningPath.build(
      lessons: SeedData.lessons,
      signsOf: (id) {
        final lesson = SeedData.lessons.firstWhere((l) => l.id == id);
        return [
          for (final s in lesson.signIds)
            SeedData.signs.firstWhere((x) => x.id == s)
        ];
      },
      learned: learned,
      stats: _stats,
    );

void main() {
  group('Camino de aprendizaje', () {
    test('Sin progreso: la primera seña es la actual y el resto está bloqueado',
        () {
      final path = _pathWith({});
      final nodes = [for (final u in path.units) ...u.nodes];
      expect(nodes.first.status, NodeStatus.current);
      expect(nodes.skip(1).every((n) => n.status == NodeStatus.locked), isTrue);
    });

    test('Con progreso: lo aprendido queda completado y avanza la actual', () {
      final path = _pathWith({'saludo_hola', 'saludo_chau', 'saludo_saludos'});
      expect(
          path.units.first.nodes.every((n) => n.status == NodeStatus.completed),
          isTrue);
      expect(path.current?.sign.id, 'numero_uno');
      expect(path.units.last.isLocked, isTrue);
    });

    test('Todo aprendido: no hay seña actual', () {
      final path = _pathWith({for (final s in SeedData.signs) s.id});
      expect(path.current, isNull);
    });
  });

  group('Racha y energía (Hive)', () {
    setUpAll(() async {
      Hive.init(Directory.systemTemp.createTempSync('senasgo_game').path);
      await HiveService.registerAdapters();
      await HiveService.initBoxes();
      await HiveService.seedIfEmpty();
      await HiveService.saveUser(UserModel.initial());
      await HiveService.setOnboardingDone(true);
    });

    tearDownAll(() => Hive.deleteFromDisk());

    test('Un intento incorrecto resta una vida', () async {
      expect(HiveService.energy, AppConstants.maxEnergy);
      await HiveService.recordAttempt(signId: 'saludo_hola', correct: false);
      expect(HiveService.energy, AppConstants.maxEnergy - 1);
      expect(HiveService.nextEnergyIn, isNotNull);
    });

    test('La energía se recarga con el tiempo', () async {
      await HiveService.gameBox.put('energy', 1);
      await HiveService.gameBox.put(
          'energyAt', DateTime.now().subtract(AppConstants.energyRegen * 2.5));
      expect(HiveService.energy, 3);
    });

    test('Nunca baja de cero', () async {
      await HiveService.gameBox.put('energy', 0);
      await HiveService.gameBox.put('energyAt', DateTime.now());
      expect(await HiveService.spendEnergy(), 0);
    });

    test('Una seña correcta inicia la racha y suma una sola vez por día',
        () async {
      expect(HiveService.streak, 0);
      await HiveService.recordAttempt(signId: 'saludo_hola', correct: true);
      expect(HiveService.streak, 1);
      expect(HiveService.practicedToday, isTrue);
      await HiveService.recordAttempt(signId: 'saludo_chau', correct: true);
      expect(HiveService.streak, 1);
    });

    test('Practicar al día siguiente suma; saltear un día la corta', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await HiveService.gameBox.put('streakDays', 4);
      await HiveService.gameBox.put('streakDate', yesterday);
      expect(HiveService.streak, 4);
      await HiveService.recordAttempt(signId: 'numero_uno', correct: true);
      expect(HiveService.streak, 5);

      await HiveService.gameBox
          .put('streakDate', DateTime.now().subtract(const Duration(days: 3)));
      expect(HiveService.streak, 0);
    });
  });

  testWidgets('La pantalla muestra estadísticas, mascota y EMPEZAR',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: LearningPathView(pathLoader: () => _pathWith({'saludo_hola'})),
    ));
    await tester.pump();

    expect(find.text('3'), findsOneWidget); // racha
    expect(find.text('4'), findsOneWidget); // energía
    expect(find.text('30'), findsOneWidget); // XP
    expect(find.text('EMPEZAR'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Jaguareté dice')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Chau, siguiente')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Hola, completada')), findsOneWidget);

    // Tocar la seña actual abre la hoja con PRACTICAR.
    final chau = find.bySemanticsLabel(RegExp('Chau, siguiente'));
    await tester.ensureVisible(chau);
    await tester.pump();
    await tester.tap(chau);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Demostración'), findsOneWidget);
    expect(find.text('Repaso'), findsOneWidget);
  });
}
