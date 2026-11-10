import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:senasgo/core/vision/sign_evaluator.dart';
import 'package:senasgo/core/vision/tolerance_profile.dart';
import 'package:senasgo/core/vision/vision_frame.dart';
import 'package:senasgo/features/practice/domain/sign_reference.dart';

// Herramienta de calibración: imprime la matriz de confusión.
// Uso: flutter test tool/vision/confusion_matrix_test.dart
void main() {
  test('matriz', () {
    const signs = [
      'saludo_hola', 'saludo_chau', 'saludo_saludos', 'numero_uno',
      'numero_dos', 'numero_tres', 'basico_gracias', 'basico_si', 'basico_no',
      'basico_por_favor'
    ];
    final files = Directory('test/fixtures/vision')
        .listSync()
        .whereType<File>()
        .map((f) => f.path)
        .toList()
      ..sort();
    for (final level in [1, 5]) {
      final tol = ToleranceProfile.forLevel(level);
      final b = StringBuffer('\nNIVEL $level  (O=acepta, .=rechaza; '
          'letra = primer parámetro que falla: F forma, P palma, L lugar, M movimiento)\n');
      b.writeln('${''.padRight(28)}${signs.map((s) => '${s.split('_').last}    '.substring(0, 4).padLeft(5)).join()}');
      for (final path in files) {
        final frames =
            VisionFrame.listFromJson(File(path).readAsStringSync());
        final name = path.split(RegExp(r'[\\/]')).last.replaceAll('.json', '');
        b.write(name.padRight(28));
        for (final s in signs) {
          final r = const SignEvaluator().evaluateBest(
              frames: frames,
              reference: SignReference.of(s),
              tolerance: tol);
          final code = r.isCorrect
              ? 'O'
              : switch (r.primaryIssue) {
                  SignParameter.manualConfig => 'f',
                  SignParameter.palmOrientation => 'p',
                  SignParameter.articulationPlace => 'l',
                  SignParameter.movement => 'm',
                  _ => '?',
                };
          b.write(code.padLeft(5));
        }
        b.writeln();
      }
      // ignore: avoid_print
      print(b);
    }
  });
}
