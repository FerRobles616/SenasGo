import 'dart:math' as math;

import 'package:senasgo/core/vision/hand_geometry.dart';
import 'package:senasgo/core/vision/hand_landmarks.dart';
import 'package:senasgo/core/vision/tolerance_profile.dart';
import 'package:senasgo/features/practice/domain/sign_evaluation.dart';
import 'package:senasgo/features/practice/domain/sign_reference.dart';

/// Evalúa los 5 parámetros formativos a partir de una secuencia de landmarks.
///
/// - Configuración manual: clasificador TFLite si existe; si no, plantilla de
///   dedos extendidos/doblados de [SignReference].
/// - Orientación de la palma: normal geométrica de la palma.
/// - Movimiento: trayectoria de la muñeca durante la ventana de evaluación.
/// - Lugar de articulación y expresión facial: requieren detectar rostro y
///   cuerpo (MediaPipe Face Mesh / Pose), fuera del alcance de esta fase.
///   Se informan como "no evaluado", nunca como acierto simulado.
class SignEvaluator {
  const SignEvaluator({HandGeometry geometry = const HandGeometry()})
      : _geometry = geometry;

  final HandGeometry _geometry;

  SignEvaluation evaluate({
    required List<HandLandmarks> frames,
    required SignReference reference,
    required ToleranceProfile tolerance,
    double? classifierScore,
  }) {
    final last = frames.last;
    return SignEvaluation({
      SignParameter.manualConfig:
          _manual(frames, reference, tolerance, classifierScore),
      SignParameter.palmOrientation: _palm(last, reference, tolerance),
      SignParameter.articulationPlace: const ParameterResult(
        ParameterStatus.notEvaluated,
        hint: 'Requiere detección de rostro y cuerpo (Fase 2).',
      ),
      SignParameter.movement: _movement(frames, reference, tolerance),
      SignParameter.facialExpression: const ParameterResult(
        ParameterStatus.notEvaluated,
        hint: 'Requiere detección de rostro (Fase 2).',
      ),
    });
  }

  ParameterResult _manual(
    List<HandLandmarks> frames,
    SignReference ref,
    ToleranceProfile tol,
    double? classifierScore,
  ) {
    final hand = frames.last;
    final double score;
    if (classifierScore != null) {
      score = classifierScore;
    } else {
      // Geometría estable: una mano que cambia de forma durante la ventana
      // no debe aprobar solo porque un fotograma aislado se parezca.
      final stability = _geometry.shapeStability(frames);
      if (frames.length >= 3 && stability < tol.minShapeStability) {
        return const ParameterResult(
          ParameterStatus.failed,
          hint: 'Mantené la forma de la mano estable mientras se evalúa.',
        );
      }

      final ext = hand.fingerExtension;
      var sum = 0.0, n = 0;
      for (var i = 0; i < 5; i++) {
        final expected = ref.fingers[i];
        if (expected == null) continue;
        sum += expected ? ext[i] : 1 - ext[i];
        n++;
      }
      if (n == 0) return const ParameterResult(ParameterStatus.notEvaluated);
      score = sum / n;
    }
    return score >= tol.minShapeScore
        ? const ParameterResult(ParameterStatus.passed)
        : ParameterResult(ParameterStatus.failed, hint: _fingerHint(hand, ref));
  }

  String _fingerHint(HandLandmarks hand, SignReference ref) {
    const names = [
      'el pulgar',
      'el índice',
      'el dedo medio',
      'el anular',
      'el meñique'
    ];
    final ext = hand.fingerExtension;
    for (var i = 0; i < 5; i++) {
      final expected = ref.fingers[i];
      if (expected == true && ext[i] < 0.5) {
        return 'Extiende ${names[i]} como en la guía.';
      }
      if (expected == false && ext[i] > 0.5) {
        return 'Dobla ${names[i]} como en la guía.';
      }
    }
    return 'Compara la forma de tus dedos con la guía.';
  }

  ParameterResult _palm(
      HandLandmarks hand, SignReference ref, ToleranceProfile tol) {
    final expected = ref.palm;
    if (expected == null) {
      return const ParameterResult(ParameterStatus.notEvaluated);
    }

    final n = hand.palmNormal;
    final score = switch (expected) {
      PalmFacing.camera => _geometry.palmFacingScore(hand),
      PalmFacing.signer => 1 - _geometry.palmFacingScore(hand),
      PalmFacing.up => ((-n.y) + 1) / 2,
      PalmFacing.down => (n.y + 1) / 2,
      PalmFacing.side => n.x.abs(),
    };
    return score >= tol.minPalmScore
        ? const ParameterResult(ParameterStatus.passed)
        : ParameterResult(ParameterStatus.failed, hint: expected.hint);
  }

  ParameterResult _movement(
    List<HandLandmarks> frames,
    SignReference ref,
    ToleranceProfile tol,
  ) {
    if (ref.movement == MovementPattern.any) {
      return const ParameterResult(ParameterStatus.notEvaluated);
    }
    if (frames.length < 3) {
      return ParameterResult(ParameterStatus.failed, hint: ref.movement.hint);
    }

    var minX = 1.0, maxX = 0.0, minY = 1.0, maxY = 0.0;
    var minS = double.infinity, maxS = 0.0, path = 0.0;
    Vec3? prev;
    for (final f in frames) {
      final w = f.point(HandLandmarks.wrist);
      minX = math.min(minX, w.x);
      maxX = math.max(maxX, w.x);
      minY = math.min(minY, w.y);
      maxY = math.max(maxY, w.y);
      minS = math.min(minS, f.palmSize);
      maxS = math.max(maxS, f.palmSize);
      if (prev != null) path += Vec3(w.x - prev.x, w.y - prev.y, 0).length;
      prev = w;
    }
    final dx = maxX - minX, dy = maxY - minY;
    double clamp01(double v) => v.clamp(0.0, 1.0);

    final score = switch (ref.movement) {
      MovementPattern.none => 1 - clamp01(math.max(dx, dy) / 0.15),
      MovementPattern.lateral =>
        clamp01(dx / 0.12) * (dx / math.max(dx + dy, 1e-6)),
      MovementPattern.vertical =>
        clamp01(dy / 0.12) * (dy / math.max(dx + dy, 1e-6)),
      MovementPattern.forward =>
        clamp01((maxS / math.max(minS, 1e-6) - 1) / 0.25),
      MovementPattern.circular => clamp01(math.min(dx, dy) / 0.08) *
          clamp01(path / math.max(2.5 * math.max(dx, dy), 1e-6)),
      MovementPattern.any => 1.0,
    };
    return score >= tol.minMovementScore
        ? const ParameterResult(ParameterStatus.passed)
        : ParameterResult(ParameterStatus.failed, hint: ref.movement.hint);
  }
}
