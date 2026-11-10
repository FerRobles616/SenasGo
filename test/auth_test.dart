import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/features/cloud/data/cloud_sync_service.dart';
import 'package:senasgo/main.dart';
import 'package:senasgo/shared/models/user_model.dart';

/// La app exige cuenta: sin sesión solo se ve la pantalla de acceso.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('senasgo_auth_test');
    Hive.init(dir.path);
    await HiveService.registerAdapters();
    await HiveService.initBoxes();
    await HiveService.seedIfEmpty();
    if (HiveService.userBox.isEmpty) {
      await HiveService.saveUser(UserModel.initial());
    }
    await HiveService.setOnboardingDone(true);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  testWidgets('Sin sesión la app abre en la pantalla de acceso',
      (tester) async {
    CloudSyncService.debugSignedIn = false;
    await tester.pumpWidget(const MyApp(cameras: []));
    await tester.pump();

    // En las pruebas no hay servidor: se ve el aviso de configuración y no
    // el camino de aprendizaje.
    expect(find.text('Creá tu cuenta'), findsOneWidget);
    expect(find.text('Falta configurar el servidor'), findsOneWidget);
    expect(find.text('EMPEZAR'), findsNothing);
    expect(find.text('Aprender'), findsNothing);
  });

  test('Cerrar sesión borra el progreso del teléfono y conserva la apariencia',
      () async {
    CloudSyncService.debugSignedIn = true;
    await HiveService.addXp(40);
    await HiveService.updateUsername('Ana');
    await HiveService.prefsBox.put('appearance', 'light');
    expect(HiveService.currentUser.xp, greaterThan(0));

    await CloudSyncService.signOut();

    expect(CloudSyncService.signedIn, isFalse);
    expect(CloudSyncService.session.value, isFalse);
    expect(HiveService.currentUser.xp, 0);
    expect(HiveService.currentUser.username, isNot('Ana'));
    expect(HiveService.onboardingDone, isFalse);
    expect(HiveService.prefsBox.get('appearance'), 'light');
    expect(HiveService.lessons, isNotEmpty);
  });
}
