import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('El archivo Rive está empaquetado y tiene cabecera válida', () async {
    final bytes = await File('assets/rive/streak_flame.riv').readAsBytes();

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), 'RIVE');
    expect(bytes.length, greaterThan(1000));
  });
}
