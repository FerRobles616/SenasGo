import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/core/theme/app_theme.dart';
import 'package:senasgo/features/profile/presentation/views/profile_view.dart';
import 'package:senasgo/shared/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Hive.init(Directory.systemTemp.createTempSync('senasgo_chest_test').path);
    await HiveService.registerAdapters();
    await HiveService.initBoxes();
    await HiveService.seedIfEmpty();
    await HiveService.saveUser(UserModel.initial());
    await HiveService.setOnboardingDone(true);
  });

  tearDownAll(() => Hive.deleteFromDisk());

  test('Un cofre se entrega una sola vez', () async {
    final before = HiveService.currentUser.xp;
    expect(HiveService.isChestClaimed('unit_test'), isFalse);

    final first = await HiveService.claimChest(
      chestId: 'unit_test',
      xp: 20,
    );
    expect(first, isTrue);
    expect(HiveService.isChestClaimed('unit_test'), isTrue);
    expect(HiveService.currentUser.xp, before + 20);

    final second = await HiveService.claimChest(
      chestId: 'unit_test',
      xp: 20,
    );
    expect(second, isFalse);
    expect(HiveService.currentUser.xp, before + 20);
  });

  testWidgets('El perfil ya no tiene modo invitado', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: const ProfileView(),
    ));
    await tester.pump();

    expect(find.textContaining('Invitado'), findsNothing);
    expect(find.textContaining('apodo'), findsNothing);

    await tester.tap(find.byTooltip('Editar nombre'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Tu nombre'), findsWidgets);
    expect(find.textContaining('Se sincroniza con tu cuenta'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pump();
  });

  test('El recordatorio de práctica se guarda y se borra', () async {
    await HiveService.setReminder(weekday: 3, hour: 19, minute: 30);
    expect(HiveService.reminderEnabled, isTrue);
    expect(HiveService.reminderWeekday, 3);
    expect(HiveService.reminderHour, 19);
    expect(HiveService.reminderMinute, 30);

    await HiveService.clearReminder();
    expect(HiveService.reminderEnabled, isFalse);
  });
}
