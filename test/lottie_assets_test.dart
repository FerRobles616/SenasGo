import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final name in const [
    'streak_flame.json',
    'xp_burst.json',
    'check_draw.json',
  ]) {
    test('La animación $name se puede cargar sin conexión', () async {
      final bytes = await File('assets/animations/$name').readAsBytes();
      final composition = await LottieComposition.fromBytes(bytes);

      expect(composition.layers, isNotEmpty);
      expect(composition.endFrame, greaterThan(0));
    });
  }
}
