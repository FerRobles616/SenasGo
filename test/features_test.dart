import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:senasgo/core/services/hive_service.dart';
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
