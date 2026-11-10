/// Los 5 parámetros formativos de una seña.
enum SignParameter {
  manualConfig('Configuración manual'),
  palmOrientation('Orientación de la palma'),
  articulationPlace('Lugar de articulación'),
  movement('Movimiento'),
  facialExpression('Expresión facial');

  const SignParameter(this.label);

  final String label;
}

enum PalmFacing {
  camera('Gira la palma hacia la cámara.'),
  signer('Gira la palma hacia ti.'),
  side('Pon la palma de costado.'),
  up('Gira la palma hacia arriba.'),
  down('Gira la palma hacia abajo.');

  const PalmFacing(this.hint);

  final String hint;
}

/// Dónde se hace la seña respecto del cuerpo (se mide con la pose).
enum SignPlace {
  besideHead('Ubica la mano al costado de la cabeza, a la altura del hombro.'),
  raised('Levanta la mano frente al cuerpo, entre el pecho y la cara.'),
  forehead('Empieza con la punta de los dedos junto a la frente.'),
  chin('Empieza con la punta de los dedos junto al mentón.'),
  chest('Apoya la mano sobre el pecho.'),
  any('');

  const SignPlace(this.hint);

  final String hint;
}

enum MovementPattern {
  none('Mantén la mano quieta mientras haces la seña.'),
  lateral('Mueve la mano de lado a lado.'),
  vertical('Mueve la mano de arriba hacia abajo.'),
  awayFromFace('Separa la mano de la cara con un movimiento claro.'),
  circular('Haz un movimiento circular con la mano.'),
  any('');

  const MovementPattern(this.hint);

  final String hint;
}

/// Especificación de referencia de cada seña para la evaluación.
///
/// Calibrada con video de un señante (Hola, Saludos) y con el esqueleto del
/// profesor 3D (las 10 señas); ver test/sign_detection_test.dart.
/// IMPORTANTE: los valores son ilustrativos y deben ser validados por una
/// persona conocedora de LSPy antes de usarse como referencia real.
class SignReference {
  const SignReference({
    required this.signId,
    required this.fingers,
    required this.palm,
    required this.movement,
    this.place = SignPlace.any,
    this.usesFace = false,
  });

  final String signId;

  /// Dedo extendido (true), doblado (false) o indistinto (null):
  /// pulgar, índice, medio, anular, meñique.
  final List<bool?> fingers;

  final PalmFacing? palm;
  final MovementPattern movement;
  final SignPlace place;

  /// La seña lleva expresión facial gramatical (todavía no se evalúa).
  final bool usesFace;

  static SignReference of(String signId) =>
      _catalog[signId] ??
      SignReference(
        signId: signId,
        fingers: const [null, null, null, null, null],
        palm: null,
        movement: MovementPattern.any,
      );

  static const Map<String, SignReference> _catalog = {
    'saludo_hola': SignReference(
      signId: 'saludo_hola',
      fingers: [null, true, true, true, true],
      palm: PalmFacing.camera,
      place: SignPlace.besideHead,
      movement: MovementPattern.none,
    ),
    'saludo_chau': SignReference(
      signId: 'saludo_chau',
      fingers: [null, true, true, true, true],
      palm: PalmFacing.camera,
      place: SignPlace.besideHead,
      movement: MovementPattern.lateral,
    ),
    'saludo_saludos': SignReference(
      signId: 'saludo_saludos',
      fingers: [null, true, true, true, true],
      palm: null,
      place: SignPlace.forehead,
      movement: MovementPattern.awayFromFace,
      usesFace: true,
    ),
    'numero_uno': SignReference(
      signId: 'numero_uno',
      fingers: [null, true, false, false, false],
      palm: null,
      place: SignPlace.raised,
      movement: MovementPattern.none,
    ),
    'numero_dos': SignReference(
      signId: 'numero_dos',
      fingers: [null, true, true, false, false],
      palm: null,
      place: SignPlace.raised,
      movement: MovementPattern.none,
    ),
    'numero_tres': SignReference(
      signId: 'numero_tres',
      fingers: [null, true, true, true, false],
      palm: null,
      place: SignPlace.raised,
      movement: MovementPattern.none,
    ),
    'basico_gracias': SignReference(
      signId: 'basico_gracias',
      fingers: [null, true, true, true, true],
      palm: PalmFacing.signer,
      place: SignPlace.chin,
      movement: MovementPattern.awayFromFace,
      usesFace: true,
    ),
    'basico_si': SignReference(
      signId: 'basico_si',
      fingers: [null, false, false, false, false],
      palm: null,
      place: SignPlace.raised,
      movement: MovementPattern.vertical,
      usesFace: true,
    ),
    'basico_no': SignReference(
      signId: 'basico_no',
      fingers: [null, true, true, false, false],
      palm: null,
      place: SignPlace.raised,
      movement: MovementPattern.any,
      usesFace: true,
    ),
    'basico_por_favor': SignReference(
      signId: 'basico_por_favor',
      fingers: [null, true, true, true, true],
      palm: PalmFacing.signer,
      place: SignPlace.chest,
      movement: MovementPattern.circular,
    ),
  };
}
