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
import 'package:senasgo/features/learning/presentation/views/lesson_list_view.dart';
import 'package:senasgo/features/practice/domain/sign_evaluation.dart';
import 'package:senasgo/features/practice/domain/sign_reference.dart';
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

    test('Mano abierta con palma a la cámara cumple "Hola"', () {
      final result = evaluator.evaluate(
        frames: [_hand(open: true)],
        reference: SignReference.of('saludo_hola'),
        tolerance: tolerance,
      );
      expect(result.isCorrect, isTrue);
      expect(result.parameters[SignParameter.manualConfig]!.status,
          ParameterStatus.passed);
      expect(result.parameters[SignParameter.palmOrientation]!.status,
          ParameterStatus.passed);
    });

    test('Puño cerrado falla "Hola" con mensaje cualitativo', () {
      final result = evaluator.evaluate(
        frames: [_hand(open: false)],
        reference: SignReference.of('saludo_hola'),
        tolerance: tolerance,
      );
      expect(result.isCorrect, isFalse);
      expect(result.feedbackTitle,
          '✕ Necesita mejorar: La posición de la mano no coincide con la guía');
      expect(result.feedbackTitle, isNot(contains('%')));
    });

    test('Dorso de la mano hacia la cámara falla la orientación', () {
      final result = evaluator.evaluate(
        frames: [_hand(open: true, rightHand: false)],
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

    test('Luz pareja se acepta y genera la entrada del modelo', () {
      final result = processFrame(
          FrameRequest(_frame(center: 120, border: 130), inputSize: 32));
      expect(result.lighting, LightingStatus.ok);
      expect(result.modelInput!.length, 32 * 32 * 3);
    });
  });
}

/// Mano sintética vertical (selfie espejada): índice a la izquierda del meñique.
HandLandmarks _hand({required bool open, bool rightHand = true}) {
  final p = Float32List(63);
  void set(int i, double x, double y) {
    p[i * 3] = x;
    p[i * 3 + 1] = y;
  }

  set(0, 0.5, 0.9); // muñeca
  // Pulgar: CMC, MCP, IP, TIP
  set(1, 0.40, 0.82);
  set(2, 0.33, 0.74);
  set(3, open ? 0.27 : 0.40, open ? 0.66 : 0.70);
  set(4, open ? 0.21 : 0.45, open ? 0.58 : 0.66);
  // Índice, medio, anular, meñique: MCP, PIP, DIP, TIP
  const xs = [0.38, 0.46, 0.54, 0.62];
  for (var f = 0; f < 4; f++) {
    final base = 5 + f * 4;
    final x = xs[f];
    set(base, x, 0.60);
    set(base + 1, x, 0.47);
    set(base + 2, x, open ? 0.37 : 0.55);
    set(base + 3, x, open ? 0.28 : 0.64);
  }
  return HandLandmarks(
    points: p,
    presence: 0.99,
    isRightHand: rightHand,
    timestamp: DateTime.now(),
  );
}

/// Fotograma YUV420 sintético de 80x100 (recuadro guía 60x60) con luma distinta dentro y fuera del recuadro.
FrameData _frame({required int center, required int border}) {
  const w = 80, h = 100;
  final y = Uint8List(w * h);
  for (var r = 0; r < h; r++) {
    for (var c = 0; c < w; c++) {
      final inside = c >= 10 && c < 70 && r >= 20 && r < 80;
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
