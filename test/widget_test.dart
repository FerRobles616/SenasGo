import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:senasgo/core/constants/app_constants.dart';
import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/core/theme/theme_controller.dart';
import 'package:senasgo/core/vision/frame_processor.dart';
import 'package:senasgo/core/vision/hand_landmarks.dart';
import 'package:senasgo/core/vision/sign_evaluator.dart';
import 'package:senasgo/core/vision/tolerance_profile.dart';
import 'package:senasgo/core/vision/vision_frame.dart';
import 'package:senasgo/features/learning/presentation/views/lesson_list_view.dart';
import 'package:senasgo/features/practice/domain/sign_evaluation.dart';
import 'package:senasgo/features/practice/domain/sign_reference.dart';
import 'package:senasgo/features/cloud/data/cloud_sync_service.dart';
import 'package:senasgo/main.dart';
import 'package:senasgo/shared/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Hive puro en el test (sin path_provider)
    final dir = Directory.systemTemp.createTempSync('senasgo_test');
    Hive.init(dir.path);
    await HiveService.registerAdapters();
    await HiveService.initBoxes();
    await HiveService.seedIfEmpty();
    if (HiveService.userBox.isEmpty) {
      await HiveService.saveUser(UserModel.initial());
    }
    // La app exige cuenta: estas pruebas arrancan con sesión simulada.
    CloudSyncService.debugSignedIn = true;
    // Los tests de la app arrancan en el camino, no en la bienvenida.
    await HiveService.setOnboardingDone(true);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  testWidgets('La app inicia en el camino de aprendizaje',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(cameras: []));
    await tester.pump();

    // Barra de navegación, primera unidad y la seña actual destacada.
    expect(find.text('Aprender'), findsOneWidget);
    expect(find.text('Saludos'), findsWidgets);
    expect(find.text('EMPEZAR'), findsOneWidget);
    expect(find.text('LSPy'), findsOneWidget);
  });

  testWidgets('La biblioteca separa lecciones del vocabulario',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LessonListView()));
    await tester.pump();

    expect(find.text('Lecciones'), findsWidgets);
    expect(find.text('Todas las señas'), findsNothing);

    await tester.tap(find.text('Señas'));
    await tester.pump();

    expect(find.text('Todas las señas'), findsOneWidget);
  });

  test('La apariencia elegida se guarda localmente', () async {
    ThemeController.init();
    expect(ThemeController.instance.preference, AppearancePreference.dark);

    await ThemeController.instance.setPreference(AppearancePreference.light);
    ThemeController.init();
    expect(ThemeController.instance.preference, AppearancePreference.light);

    await ThemeController.instance.setPreference(AppearancePreference.dark);
  });

  test('El usuario inicial tiene estado válido', () {
    final user = UserModel.initial();
    expect(user.level, 1);
    expect(user.xp, 0);
    expect(user.completedLessons, isEmpty);
  });

  test('Los XP otorgados por seña correcta son +10', () {
    expect(AppConstants.xpPerCorrectSign, 10);
  });

  test('La tolerancia es más amplia para principiantes', () {
    final beginner = ToleranceProfile.forLevel(1);
    final expert = ToleranceProfile.forLevel(5);
    expect(beginner.minShapeScore, lessThan(expert.minShapeScore));
    expect(beginner.palmToleranceDeg, greaterThan(expert.palmToleranceDeg));
    expect(ToleranceProfile.forLevel(9).level, 5);
  });

  group('Evaluación de los parámetros formativos', () {
    const evaluator = SignEvaluator();
    final tolerance = ToleranceProfile.forLevel(1);
    List<VisionFrame> load(String name) => VisionFrame.listFromJson(
        File('test/fixtures/vision/$name.json').readAsStringSync());

    test('Una grabación real de "Hola" cumple los parámetros', () {
      final result = evaluator.evaluateBest(
        frames: load('real_hola'),
        reference: SignReference.of('saludo_hola'),
        tolerance: tolerance,
      );
      expect(result.isCorrect, isTrue);
      expect(result.parameters[SignParameter.manualConfig]!.status,
          ParameterStatus.passed);
      expect(result.parameters[SignParameter.palmOrientation]!.status,
          ParameterStatus.passed);
      expect(result.parameters[SignParameter.facialExpression]!.status,
          ParameterStatus.notEvaluated);
    });

    test('Puño cerrado falla "Hola" con mensaje cualitativo', () {
      final result = evaluator.evaluateBest(
        frames: load('synth_basico_si'),
        reference: SignReference.of('saludo_hola'),
        tolerance: tolerance,
      );
      expect(result.isCorrect, isFalse);
      expect(result.feedbackTitle,
          '✕ Necesita mejorar: La posición de la mano no coincide con la guía');
      expect(result.feedbackTitle, isNot(contains('%')));
    });

    test('Dorso de la mano hacia la cámara falla la orientación', () {
      // Misma grabación, con la palma girada: se invierte la lateralidad.
      final flipped = [
        for (final f in load('real_hola'))
          VisionFrame(
            hands: [
              for (final h in f.hands)
                HandLandmarks(
                  points: h.points,
                  world: h.world,
                  presence: h.presence,
                  isRightHand: !h.isRightHand,
                  timestamp: h.timestamp,
                )
            ],
            body: f.body,
            aspect: f.aspect,
            timestamp: f.timestamp,
          )
      ];
      final result = evaluator.evaluateBest(
        frames: flipped,
        reference: SignReference.of('saludo_hola'),
        tolerance: tolerance,
      );
      expect(result.primaryIssue, SignParameter.palmOrientation);
    });
  });

  group('Chequeo de iluminación', () {
    test('Ambiente oscuro se rechaza', () {
      expect(
          processFrame(FrameRequest(_frame(center: 20, border: 20))).lighting,
          LightingStatus.tooDark);
    });

    test('Contraluz fuerte se rechaza', () {
      expect(
          processFrame(FrameRequest(_frame(center: 90, border: 230))).lighting,
          LightingStatus.backlit);
    });

    test('Luz pareja se acepta y genera la imagen para el detector', () {
      final result = processFrame(
          FrameRequest(_frame(center: 120, border: 130), maxSide: 50));
      expect(result.lighting, LightingStatus.ok);
      expect(result.width, 40);
      expect(result.height, 50);
      expect(result.rgba!.length, 40 * 50 * 4);
      // Gris neutro (U=V=128): R=G=B y opaco.
      final o = (25 * 40 + 20) * 4;
      expect(result.rgba![o], result.rgba![o + 1]);
      expect(result.rgba![o + 3], 255);
    });

    test('Sin pedir imagen solo se mide la luz', () {
      final result =
          processFrame(FrameRequest(_frame(center: 120, border: 130)));
      expect(result.rgba, isNull);
    });
  });
}

/// Fotograma YUV420 sintético de 80x100 con luma distinta en la zona central
/// (donde está la persona) y en los bordes.
FrameData _frame({required int center, required int border}) {
  const w = 80, h = 100;
  final y = Uint8List(w * h);
  for (var r = 0; r < h; r++) {
    for (var c = 0; c < w; c++) {
      final inside = c >= 16 && c < 64 && r >= 10 && r < 90;
      y[r * w + c] = inside ? center : border;
    }
  }
  final uv = Uint8List((w ~/ 2) * (h ~/ 2))
    ..fillRange(0, (w ~/ 2) * (h ~/ 2), 128);
  return FrameData(
    width: w,
    height: h,
    isBgra: false,
    planes: [y, uv, Uint8List.fromList(uv)],
    rowStrides: const [w, w ~/ 2, w ~/ 2],
    pixelStrides: const [1, 1, 1],
    rotationDeg: 0,
    mirror: false,
  );
}
