import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:senasgo/core/vision/sign_evaluator.dart';
import 'package:senasgo/core/vision/tolerance_profile.dart';
import 'package:senasgo/core/vision/vision_frame.dart';
import 'package:senasgo/features/practice/domain/sign_reference.dart';

/// Calibración del detector con grabaciones reales y con el esqueleto del
/// profesor (test/fixtures/vision, generadas con tool/vision).
///
/// - Cada grabación de una seña tiene que aceptarse en todos los niveles.
/// - Las manos en reposo nunca tienen que aceptarse como una seña.
/// - Ninguna grabación puede aceptarse como otra seña, salvo las parejas que
///   comparten los mismos parámetros medibles (anotadas abajo con su motivo).
const _signs = [
  'saludo_hola',
  'saludo_chau',
  'saludo_saludos',
  'numero_uno',
  'numero_dos',
  'numero_tres',
  'basico_gracias',
  'basico_si',
  'basico_no',
  'basico_por_favor',
];

/// Grabación -> seña que contiene.
const _positives = {
  'real_hola': 'saludo_hola',
  'real_saludos': 'saludo_saludos',
  'synth_saludo_hola': 'saludo_hola',
  'synth_saludo_chau': 'saludo_chau',
  'synth_saludo_saludos': 'saludo_saludos',
  'synth_numero_uno': 'numero_uno',
  'synth_numero_dos': 'numero_dos',
  'synth_numero_tres': 'numero_tres',
  'synth_basico_gracias': 'basico_gracias',
  'synth_basico_si': 'basico_si',
  'synth_basico_no': 'basico_no',
  'synth_basico_por_favor': 'basico_por_favor',
};

/// Confusiones aceptadas: grabación -> señas que también puede aprobar.
const _allowed = {
  // "Chau" empieza con la mano quieta al costado de la cabeza: es un "hola".
  'synth_saludo_chau': {'saludo_hola'},
  // "Dos" y "no" tienen la misma forma; el "no" del profesor no golpea los
  // dedos, así que la cámara no los puede distinguir.
  'synth_numero_dos': {'basico_no'},
  'synth_basico_no': {'numero_dos'},
  // Señas de otro tema con parámetros parecidos (puño que baja frente a la
  // cara; mano abierta sobre el pecho que se mueve).
  'real_otra_buenas_noches': {'basico_si', 'saludo_saludos'},
  'real_otra_divorciado': {'basico_por_favor'},
  'real_otra_mucho_gusto': {'basico_por_favor'},
};

const _rest = {'real_reposo', 'synth_idle'};

Map<String, List<VisionFrame>> _load() {
  final out = <String, List<VisionFrame>>{};
  for (final f in Directory('test/fixtures/vision').listSync()) {
    if (f is! File || !f.path.endsWith('.json')) continue;
    final name = f.uri.pathSegments.last.replaceAll('.json', '');
    out[name] = VisionFrame.listFromJson(f.readAsStringSync());
  }
  return out;
}

bool _accepts(List<VisionFrame> frames, String sign, int level) =>
    const SignEvaluator()
        .evaluateBest(
          frames: frames,
          reference: SignReference.of(sign),
          tolerance: ToleranceProfile.forLevel(level),
        )
        .isCorrect;

void main() {
  final recordings = _load();

  test('hay grabaciones de calibración', () {
    expect(recordings.keys, containsAll([..._positives.keys, ..._rest]));
  });

  for (final level in [1, 3, 5]) {
    group('nivel $level', () {
      for (final e in _positives.entries) {
        test('${e.key} se acepta como ${e.value}', () {
          expect(_accepts(recordings[e.key]!, e.value, level), isTrue);
        });
      }

      for (final name in _rest) {
        test('$name (reposo) no se acepta como ninguna seña', () {
          final wrong = [
            for (final s in _signs)
              if (_accepts(recordings[name]!, s, level)) s
          ];
          expect(wrong, isEmpty);
        });
      }

      test('sin confusiones fuera de las anotadas', () {
        final wrong = <String>[];
        for (final e in recordings.entries) {
          if (_rest.contains(e.key)) continue;
          for (final s in _signs) {
            if (s == _positives[e.key]) continue;
            if (_allowed[e.key]?.contains(s) ?? false) continue;
            if (_accepts(e.value, s, level)) wrong.add('${e.key} -> $s');
          }
        }
        expect(wrong, isEmpty);
      });
    });
  }

  test('sin cuerpo visible, el lugar no se evalúa pero la forma sí', () {
    final frames = [
      for (final f in recordings['synth_numero_uno']!)
        VisionFrame(hands: f.hands, body: null, aspect: f.aspect,
            timestamp: f.timestamp)
    ];
    final r = const SignEvaluator().evaluateBest(
      frames: frames,
      reference: SignReference.of('numero_uno'),
      tolerance: ToleranceProfile.forLevel(1),
    );
    expect(r.isCorrect, isTrue);
  });

  test('sin manos, falla la configuración con una pista', () {
    final r = const SignEvaluator().evaluate(
      frames: const [],
      reference: SignReference.of('saludo_hola'),
      tolerance: ToleranceProfile.forLevel(1),
    );
    expect(r.isCorrect, isFalse);
    expect(r.feedbackHint, isNotEmpty);
  });
}
