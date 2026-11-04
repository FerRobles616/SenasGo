import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:senasgo/core/constants/app_constants.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/challenges/presentation/views/challenges_view.dart';
import 'package:senasgo/features/profile/presentation/views/home_shortcut_view.dart';
import 'package:senasgo/features/streak/presentation/views/streak_view.dart';
import 'package:senasgo/main.dart';
import 'package:senasgo/shared/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('senasgo_redesign_test');
    Hive.init(dir.path);
    await HiveService.registerAdapters();
    await HiveService.initBoxes();
    await HiveService.seedIfEmpty();
    if (HiveService.userBox.isEmpty) {
      await HiveService.saveUser(UserModel.initial());
    }
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  group('Onboarding y bienvenida', () {
    testWidgets('Primer arranque abre en la pantalla de bienvenida',
        (tester) async {
      await tester.runAsync(() => HiveService.setOnboardingDone(false));

      await tester.pumpWidget(const MyApp(cameras: []));
      await tester.pump();

      expect(find.textContaining('Aprendé LSPy'), findsOneWidget);
      expect(find.text('EMPEZAR'), findsOneWidget);
      expect(find.text('Saltar'), findsOneWidget);

      await tester.runAsync(() => HiveService.setOnboardingDone(true));
    });

    test('Recompensa de bienvenida entrega 10 XP y no duplica', () async {
      final initialXp = HiveService.currentUser.xp;
      expect(HiveService.welcomeRewardClaimed, isFalse);

      await HiveService.claimWelcomeReward();
      expect(HiveService.welcomeRewardClaimed, isTrue);
      expect(HiveService.currentUser.xp,
          initialXp + AppConstants.welcomeRewardXp);

      // Segundo intento no debe sumar más XP
      await HiveService.claimWelcomeReward();
      expect(HiveService.currentUser.xp,
          initialXp + AppConstants.welcomeRewardXp);
    });
  });

  group('Nuevas pantallas locales', () {
    testWidgets('Pantalla de retos muestra metas y recompensas',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const ChallengesView(),
        ),
      );
      await tester.pump();

      expect(find.text('Retos de la semana'), findsOneWidget);
      expect(find.text('Ganá 20 XP hoy'), findsOneWidget);
      expect(find.text('Practicá 3 señas distintas'), findsOneWidget);
    });

    testWidgets('Pantalla de racha muestra calendario y protecciones',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const StreakView(),
        ),
      );
      await tester.pump();

      expect(find.text('Mi racha'), findsOneWidget);
      expect(find.text('días de racha'), findsOneWidget);
      expect(find.text('mejor racha'), findsOneWidget);
    });

    testWidgets('Tutorial de acceso rápido explica cómo anclar la app',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const HomeShortcutView(),
        ),
      );
      await tester.pump();

      expect(find.text('Tené SeñasGo a mano'), findsOneWidget);
      expect(find.text('Acceso rápido'), findsOneWidget);
      expect(find.textContaining('Mantené presionado'), findsOneWidget);
    });
  });
}
