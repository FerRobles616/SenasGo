import 'package:senasgo/shared/models/lesson_model.dart';
import 'package:senasgo/shared/models/sign_model.dart';

/// Catálogo inicial (vocabulario acotado LSPy).
/// Se copia a Hive al iniciar (ver HiveService.seedIfEmpty) y de ahí se lee
/// siempre local. "Hola" y "Saludos" siguen la clase de CODA DOS LENGUAS
/// ("Saludos & Presentaciones"), grabada por el autor de la app.
class SeedData {
  const SeedData._();

  static final List<SignModel> signs = [
    const SignModel(
      id: 'saludo_hola',
      name: 'Hola',
      category: SignCategory.greetings,
      description:
          'Mano abierta en alto, a la altura del hombro, con la palma hacia '
          'la otra persona.',
      assetImagePath: 'assets/images/saludo_hola.png',
      assetAnimationPath: 'assets/animations/saludo_hola.json',
      riveAssetPath: null,
      keypointsLabel: 'saludo_hola',
      isActive: true,
      tags: ['saludo', 'hola', 'básico'],
    ),
    const SignModel(
      id: 'saludo_chau',
      name: 'Chau',
      category: SignCategory.greetings,
      description: 'Mano abierta que se mueve lateralmente en despedida.',
      assetImagePath: 'assets/images/saludo_chau.png',
      assetAnimationPath: null,
      riveAssetPath: null,
      keypointsLabel: 'saludo_chau',
      isActive: true,
      tags: ['despedida', 'chau'],
    ),
    const SignModel(
      id: 'saludo_saludos',
      name: 'Saludos',
      category: SignCategory.greetings,
      description:
          'Mano plana que sale desde la frente hacia el costado, como un '
          'saludo.',
      assetImagePath: 'assets/images/saludo_saludos.png',
      assetAnimationPath: null,
      riveAssetPath: null,
      keypointsLabel: 'saludo_saludos',
      isActive: true,
      tags: ['saludo', 'saludos'],
    ),
    const SignModel(
      id: 'numero_uno',
      name: 'Uno',
      category: SignCategory.numbers,
      description: 'Índice extendido hacia arriba.',
      assetImagePath: 'assets/images/numero_uno.png',
      assetAnimationPath: null,
      riveAssetPath: null,
      keypointsLabel: 'numero_uno',
      isActive: true,
      tags: ['número', '1'],
    ),
    const SignModel(
      id: 'numero_dos',
      name: 'Dos',
      category: SignCategory.numbers,
      description: 'Índice y medio extendidos en V hacia arriba.',
      assetImagePath: 'assets/images/numero_dos.png',
      assetAnimationPath: null,
      riveAssetPath: null,
      keypointsLabel: 'numero_dos',
      isActive: true,
      tags: ['número', '2'],
    ),
    const SignModel(
      id: 'numero_tres',
      name: 'Tres',
      category: SignCategory.numbers,
      description: 'Índice, medio y anular extendidos.',
      assetImagePath: 'assets/images/numero_tres.png',
      assetAnimationPath: null,
      riveAssetPath: null,
      keypointsLabel: 'numero_tres',
      isActive: true,
      tags: ['número', '3'],
    ),
    const SignModel(
      id: 'basico_gracias',
      name: 'Gracias',
      category: SignCategory.basics,
      description: 'Mano plana desde el mentón hacia adelante.',
      assetImagePath: 'assets/images/basico_gracias.png',
      assetAnimationPath: null,
      riveAssetPath: null,
      keypointsLabel: 'basico_gracias',
      isActive: true,
      tags: ['cortesía', 'gracias'],
    ),
    const SignModel(
      id: 'basico_si',
      name: 'Sí',
      category: SignCategory.basics,
      description: 'Puño cerrado que asiente verticalmente.',
      assetImagePath: 'assets/images/basico_si.png',
      assetAnimationPath: null,
      riveAssetPath: null,
      keypointsLabel: 'basico_si',
      isActive: true,
      tags: ['afirmación', 'sí'],
    ),
    const SignModel(
      id: 'basico_no',
      name: 'No',
      category: SignCategory.basics,
      description: 'Índice y medio que se abren y cierran lateralmente.',
      assetImagePath: 'assets/images/basico_no.png',
      assetAnimationPath: null,
      riveAssetPath: null,
      keypointsLabel: 'basico_no',
      isActive: true,
      tags: ['negación', 'no'],
    ),
    const SignModel(
      id: 'basico_por_favor',
      name: 'Por favor',
      category: SignCategory.basics,
      description: 'Mano plana sobre el pecho con movimiento circular.',
      assetImagePath: 'assets/images/basico_por_favor.png',
      assetAnimationPath: null,
      riveAssetPath: null,
      keypointsLabel: 'basico_por_favor',
      isActive: true,
      tags: ['cortesía', 'por favor'],
    ),
  ];

  static final List<LessonModel> lessons = [
    const LessonModel(
      id: 'leccion_saludos',
      title: 'Saludos',
      description: 'Aprendé a saludar y despedirte en LSPy.',
      signIds: ['saludo_hola', 'saludo_chau', 'saludo_saludos'],
      isCompleted: false,
      difficulty: 1,
      order: 1,
    ),
    const LessonModel(
      id: 'leccion_numeros',
      title: 'Números',
      description: 'Contá del 1 al 3 con las manos.',
      signIds: ['numero_uno', 'numero_dos', 'numero_tres'],
      isCompleted: false,
      difficulty: 1,
      order: 2,
    ),
    const LessonModel(
      id: 'leccion_basicas',
      title: 'Palabras Básicas',
      description: 'Frases de uso cotidiano: gracias, sí, no, por favor.',
      signIds: ['basico_gracias', 'basico_si', 'basico_no', 'basico_por_favor'],
      isCompleted: false,
      difficulty: 2,
      order: 3,
    ),
  ];
}
