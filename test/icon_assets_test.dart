import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// Los iconos ilustrados son PNG con transparencia real. Este test evita que
/// vuelvan a colarse fondos claros, sombras o restos del damero original.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final files = [
    ...Directory('assets/icons/features').listSync().whereType<File>(),
    ...Directory('assets/icons/nav').listSync().whereType<File>(),
  ].where((file) => file.path.endsWith('.png')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('Hay 21 iconos ilustrados registrados', () {
    expect(files, hasLength(21));
  });

  for (final file in files) {
    test('${file.path} tiene fondo transparente y sin borde claro', () async {
      final codec = await ui.instantiateImageCodec(await file.readAsBytes());
      final frame = await codec.getNextFrame();
      final image = frame.image;
      addTearDown(image.dispose);
      addTearDown(codec.dispose);

      expect(image.width, 256);
      expect(image.height, 256);

      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(data, isNotNull);
      final bytes = data!.buffer
          .asUint8List(data.offsetInBytes, data.lengthInBytes);
      int alphaAt(int x, int y) => bytes[(y * image.width + x) * 4 + 3];

      expect(alphaAt(0, 0), 0);
      expect(alphaAt(image.width - 1, 0), 0);
      expect(alphaAt(0, image.height - 1), 0);
      expect(alphaAt(image.width - 1, image.height - 1), 0);

      var lightBorderPixels = 0;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          final onBorder = x < 6 ||
              y < 6 ||
              x >= image.width - 6 ||
              y >= image.height - 6;
          if (!onBorder) continue;
          final i = (y * image.width + x) * 4;
          final isVisible = bytes[i + 3] > 0;
          final isLight = bytes[i] > 180 &&
              bytes[i + 1] > 180 &&
              bytes[i + 2] > 180;
          if (isVisible && isLight) lightBorderPixels++;
        }
      }
      expect(lightBorderPixels, 0,
          reason: 'El borde no debe conservar restos claros del fondo');
    });
  }
}
