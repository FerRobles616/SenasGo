import 'package:flutter/animation.dart';
import 'package:senasgo/core/vision/hand_landmarks.dart';
import 'package:senasgo/features/avatar/domain/sign_animation_model.dart';
import 'package:senasgo/features/learning/data/seed_data.dart';

/// Animaciones del vocabulario acotado.
///
/// IMPORTANTE (Riesgo R3 de la documentación v3_04): son representaciones
/// ilustrativas. Antes de usarlas como referencia, una persona conocedora de
/// LSPy debe revisar cada keyframe y marcar `validatedByLspyExpert: true`.
class SignAnimationCatalog {
  const SignAnimationCatalog._();

  // Lugares de articulación (espacio del cuerpo, mano dominante a la izquierda
  // de la pantalla, como un espejo).
  static const _forehead = Vec3(-0.09, 0.38, 0.2);
  static const _chin = Vec3(-0.03, 0.13, 0.2);
  static const _chest = Vec3(-0.03, -0.08, 0.15);
  static const _neutral = Vec3(-0.12, 0.02, 0.30);
  static const _shoulderHigh = Vec3(-0.24, 0.16, 0.26);

  /// Busca la animación por id (`saludo_hola`) o por la palabra que aprende
  /// el estudiante ("Hola", "por favor"), sin importar tildes ni mayúsculas.
  /// Devuelve null si la seña todavía no tiene animación (p. ej. letras).
  static SignAnimationModel? resolve(String signName) {
    final key = _normalize(signName);
    if (key.isEmpty) return null;
    for (final a in _all) {
      if (_normalize(a.signId) == key) return a;
    }
    for (final sign in SeedData.signs) {
      if (_normalize(sign.name) == key) return _byId[sign.id];
    }
    return null;
  }

  static String _normalize(String text) {
    const from = 'áéíóúüñÁÉÍÓÚÜÑ';
    const to = 'aeiouunAEIOUUN';
    final buffer = StringBuffer();
    for (final ch in text.trim().split('')) {
      final i = from.indexOf(ch);
      buffer.write(i < 0 ? ch : to[i]);
    }
    return buffer.toString().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), ' ');
  }

  static SignAnimationModel of(String signId) =>
      _byId[signId] ?? _fallback(signId);

  static final Map<String, SignAnimationModel> _byId = {
    for (final a in _all) a.signId: a,
  };

  static SignAnimationModel _fallback(String signId) => SignAnimationModel(
        signId: signId,
        duration: const Duration(milliseconds: 1600),
        keyframes: const [
          AvatarKeyframe(
              at: 0.35,
              dominant: HandPose(wrist: _neutral, shape: HandShape.open),
              phase: 'Configuración'),
          AvatarKeyframe(
              at: 0.7,
              dominant: HandPose(wrist: _neutral, shape: HandShape.open),
              phase: 'Retención'),
        ],
      );

  static final List<SignAnimationModel> _all = [
    // HOLA: mano abierta en alto, a la altura del hombro, sostenida.
    const SignAnimationModel(
      signId: 'saludo_hola',
      riveSignIndex: 0,
      duration: Duration(milliseconds: 2400),
      keyframes: [
        AvatarKeyframe(
          at: 0.35,
          dominant: HandPose(wrist: _shoulderHigh, shape: HandShape.open),
          face: FaceExpression.friendly,
          phase: 'Lugar: a la altura del hombro',
        ),
        AvatarKeyframe(
          at: 0.75,
          dominant: HandPose(wrist: _shoulderHigh, shape: HandShape.open),
          face: FaceExpression.friendly,
          body: BodyPose(headRoll: 3, label: 'cabeza inclinada'),
          phase: 'Retención',
        ),
      ],
    ),

    // SALUDOS: mano plana junto a la frente que sale hacia el costado.
    const SignAnimationModel(
      signId: 'saludo_saludos',
      riveSignIndex: 9,
      duration: Duration(milliseconds: 2600),
      keyframes: [
        AvatarKeyframe(
          at: 0.3,
          dominant: HandPose(
              wrist: _forehead,
              shape: HandShape.open,
              palm: PalmOrientation(roll: -10)),
          face: FaceExpression.friendly,
          phase: 'Lugar: frente',
        ),
        AvatarKeyframe(
          at: 0.55,
          dominant: HandPose(
              wrist: Vec3(-0.26, 0.33, 0.34),
              shape: HandShape.open,
              palm: PalmOrientation(roll: -25)),
          face: FaceExpression.friendly,
          body: BodyPose(headPitch: -4, label: 'cabeza erguida'),
          easing: Curves.easeOutCubic,
          phase: 'Movimiento: hacia afuera',
        ),
        AvatarKeyframe(
          at: 0.72,
          dominant: HandPose(
              wrist: Vec3(-0.26, 0.33, 0.34),
              shape: HandShape.open,
              palm: PalmOrientation(roll: -25)),
          face: FaceExpression.friendly,
          phase: 'Retención',
        ),
      ],
    ),

    // CHAU: palma al frente con movimiento lateral repetido.
    SignAnimationModel(
      signId: 'saludo_chau',
      riveSignIndex: 1,
      duration: const Duration(milliseconds: 2400),
      keyframes: [
        const AvatarKeyframe(
          at: 0.2,
          dominant: HandPose(wrist: _shoulderHigh, shape: HandShape.open),
          face: FaceExpression.friendly,
          phase: 'Configuración: mano abierta',
        ),
        for (var i = 0; i < 4; i++)
          AvatarKeyframe(
            at: 0.32 + i * 0.12,
            dominant: HandPose(
              wrist: _shoulderHigh + Vec3(i.isEven ? 0.07 : -0.05, 0, 0),
              shape: HandShape.open,
              palm: PalmOrientation(roll: i.isEven ? 14 : -14),
            ),
            face: FaceExpression.friendly,
            body: const BodyPose(headRoll: 4, label: 'cabeza inclinada'),
            easing: Curves.easeInOutSine,
            phase: 'Movimiento: lateral',
          ),
      ],
    ),

    _number('numero_uno', HandShape.index, 2),
    _number('numero_dos', HandShape.v, 3),
    _number('numero_tres', HandShape.three, 4),

    // GRACIAS: mano plana desde el mentón hacia adelante, con sonrisa.
    const SignAnimationModel(
      signId: 'basico_gracias',
      riveSignIndex: 5,
      duration: Duration(milliseconds: 2200),
      keyframes: [
        AvatarKeyframe(
          at: 0.28,
          dominant: HandPose(
              wrist: _chin,
              shape: HandShape.flat,
              palm: PalmOrientation(yaw: 170, pitch: -5)),
          face: FaceExpression.friendly,
          phase: 'Lugar: mentón',
        ),
        AvatarKeyframe(
          at: 0.62,
          dominant: HandPose(
              wrist: Vec3(-0.09, 0.02, 0.42),
              shape: HandShape.flat,
              palm: PalmOrientation(yaw: 170, pitch: -60)),
          face: FaceExpression.friendly,
          body: BodyPose(headPitch: 8, torsoLean: 3, label: 'leve reverencia'),
          easing: Curves.easeOutCubic,
          phase: 'Movimiento: hacia adelante',
        ),
        AvatarKeyframe(
          at: 0.8,
          dominant: HandPose(
              wrist: Vec3(-0.09, 0.02, 0.42),
              shape: HandShape.flat,
              palm: PalmOrientation(yaw: 170, pitch: -60)),
          face: FaceExpression.friendly,
          body: BodyPose(headPitch: 4, label: 'leve reverencia'),
          phase: 'Retención',
        ),
      ],
    ),

    // SÍ: puño que asiente; la cabeza acompaña el movimiento.
    SignAnimationModel(
      signId: 'basico_si',
      riveSignIndex: 6,
      duration: const Duration(milliseconds: 2200),
      keyframes: [
        const AvatarKeyframe(
          at: 0.22,
          dominant: HandPose(
              wrist: _neutral,
              shape: HandShape.fist,
              palm: PalmOrientation(yaw: 90)),
          face: FaceExpression.affirm,
          phase: 'Configuración: puño',
        ),
        for (var i = 0; i < 4; i++)
          AvatarKeyframe(
            at: 0.34 + i * 0.12,
            dominant: HandPose(
              wrist: _neutral + Vec3(0, i.isEven ? -0.05 : 0.02, 0),
              shape: HandShape.fist,
              palm: PalmOrientation(yaw: 90, pitch: i.isEven ? 35 : -5),
            ),
            face: FaceExpression.affirm,
            body: BodyPose(
                headPitch: i.isEven ? 12 : -2, label: 'asiente con la cabeza'),
            easing: Curves.easeInOutSine,
            phase: 'Movimiento: vertical',
          ),
      ],
    ),

    // NO: índice y medio se cierran contra el pulgar; la cabeza niega y el
    // ceño se frunce (negación no manual).
    SignAnimationModel(
      signId: 'basico_no',
      riveSignIndex: 7,
      duration: const Duration(milliseconds: 2300),
      keyframes: [
        const AvatarKeyframe(
          at: 0.22,
          dominant: HandPose(
              wrist: _neutral,
              shape: HandShape.v,
              palm: PalmOrientation(yaw: 60)),
          face: FaceExpression.negation,
          phase: 'Configuración',
        ),
        for (var i = 0; i < 4; i++)
          AvatarKeyframe(
            at: 0.34 + i * 0.12,
            dominant: HandPose(
              wrist: _neutral,
              shape: i.isEven ? HandShape.pinch : HandShape.v,
              palm: const PalmOrientation(yaw: 60),
            ),
            face: FaceExpression.negation,
            body: BodyPose(
                headYaw: i.isEven ? 14 : -14, label: 'niega con la cabeza'),
            easing: Curves.easeInOutSine,
            phase: 'Movimiento: abrir y cerrar',
          ),
      ],
    ),

    // POR FAVOR: mano plana sobre el pecho con movimiento circular.
    SignAnimationModel(
      signId: 'basico_por_favor',
      riveSignIndex: 8,
      duration: const Duration(milliseconds: 2600),
      keyframes: [
        AvatarKeyframe(
          at: 0.2,
          dominant: HandPose(
            wrist: _chest + const Vec3(0.05, 0, 0),
            shape: HandShape.flat,
            palm: const PalmOrientation(yaw: 180, roll: 70),
          ),
          face: FaceExpression.pleading,
          phase: 'Lugar: pecho',
        ),
        for (var i = 1; i <= 6; i++)
          AvatarKeyframe(
            at: 0.2 + i * 0.09,
            dominant: HandPose(
              wrist: _chest + Vec3(0.05 * _cos(i), 0.05 * _sin(i), 0),
              shape: HandShape.flat,
              palm: const PalmOrientation(yaw: 180, roll: 70),
            ),
            face: FaceExpression.pleading,
            body: const BodyPose(headRoll: -5, label: 'cabeza inclinada'),
            easing: Curves.linear,
            phase: 'Movimiento: circular',
          ),
      ],
    ),
  ];

  /// Números: configuración estática frente al cuerpo, palma al estudiante.
  static SignAnimationModel _number(
          String id, HandShape shape, int riveIndex) =>
      SignAnimationModel(
        signId: id,
        riveSignIndex: riveIndex,
        duration: const Duration(milliseconds: 1800),
        keyframes: [
          AvatarKeyframe(
            at: 0.35,
            dominant:
                HandPose(wrist: const Vec3(-0.14, 0.12, 0.28), shape: shape),
            phase: 'Configuración manual',
          ),
          AvatarKeyframe(
            at: 0.75,
            dominant:
                HandPose(wrist: const Vec3(-0.14, 0.13, 0.28), shape: shape),
            phase: 'Retención',
          ),
        ],
      );

  // Seis puntos de un círculo (60° cada uno), empezando arriba a la derecha.
  static double _cos(int i) => const [0.5, -0.5, -1.0, -0.5, 0.5, 1.0][i - 1];
  static double _sin(int i) =>
      const [0.87, 0.87, 0.0, -0.87, -0.87, 0.0][i - 1];
}
