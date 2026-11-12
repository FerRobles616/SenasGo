import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('La llama Lottie se puede cargar sin conexión', () async {
    final bytes =
        await File('assets/animations/streak_flame.json').readAsBytes();
    final composition = await LottieComposition.fromBytes(bytes);

    expect(composition.layers, isNotEmpty);
    expect(composition.endFrame, greaterThan(0));
  });
}
