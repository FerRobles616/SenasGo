import 'dart:math' as math;

import 'package:senasgo/core/vision/hand_landmarks.dart';
import 'package:senasgo/core/vision/tolerance_profile.dart';
import 'package:senasgo/core/vision/vision_frame.dart';
import 'package:senasgo/features/practice/domain/sign_evaluation.dart';
import 'package:senasgo/features/practice/domain/sign_reference.dart';

/// Evalúa los parámetros formativos de una seña a partir de una secuencia de
/// cuadros (manos en 2D y 3D + pose del cuerpo de MediaPipe).
///
/// - Configuración manual: rectitud 3D de cada dedo, por mayoría de cuadros.
/// - Orientación de la palma: normal 3D de la palma, por mayoría.
/// - Lugar: posición de la mano respecto de cara, mentón, pecho y hombros.
/// - Movimiento: trayectoria de la palma medida en "anchos de hombro".
/// - Expresión facial: todavía no se evalúa (se informa como tal, nunca como
///   acierto simulado).
///
/// La persona no siempre empieza en el mismo momento: se prueban varios
/// tramos de la grabación y se queda con el mejor ([evaluateBest]).
class SignEvaluator {
  const SignEvaluator();

  /// Duración de cada tramo que se evalúa.
  static const Duration segment = Duration(milliseconds: 1300);

  /// Evalúa todos los tramos de [frames] y devuelve el mejor resultado.
  SignEvaluation evaluateBest({
    required List<VisionFrame> frames,
    required SignReference reference,
    required ToleranceProfile tolerance,
  }) {
    final usable = [for (final f in frames) if (f.activeHand != null) f];
    if (usable.length < 3) {
      return evaluate(
          frames: usable, reference: reference, tolerance: tolerance);
    }
    SignEvaluation? best;
    var bestScore = -1.0;
    for (var start = 0; start < usable.length; start += 2) {
      final end = usable[start].timestamp.add(segment);
      final part = [
        for (var i = start; i < usable.length; i++)
          if (!usable[i].timestamp.isAfter(end)) usable[i]
      ];
      if (part.length < 3 && best != null) break;
      final result =
          evaluate(frames: part, reference: reference, tolerance: tolerance);
      final score = result.score;
      if (score > bestScore) {
        bestScore = score;
        best = result;
      }
      if (result.isCorrect) break;
      if (part.last == usable.last) break;
    }
    return best!;
  }

  /// Evalúa un tramo de cuadros.
  SignEvaluation evaluate({
    required List<VisionFrame> frames,
    required SignReference reference,
    required ToleranceProfile tolerance,
  }) {
    final hands = _track(frames);
    if (hands.isEmpty) {
      const missing = ParameterResult(ParameterStatus.failed,
          hint: 'No se vio la mano. Mantenla dentro de la imagen.');
      return SignEvaluation({
        SignParameter.manualConfig: missing,
        SignParameter.palmOrientation:
            const ParameterResult(ParameterStatus.notEvaluated),
        SignParameter.articulationPlace:
            const ParameterResult(ParameterStatus.notEvaluated),
        SignParameter.movement:
            const ParameterResult(ParameterStatus.notEvaluated),
        SignParameter.facialExpression:
            const ParameterResult(ParameterStatus.notEvaluated),
      });
    }
    return SignEvaluation({
      SignParameter.manualConfig: _manual(hands, reference, tolerance),
      SignParameter.palmOrientation: _palm(hands, reference, tolerance),
      SignParameter.articulationPlace: _place(hands, reference, tolerance),
      SignParameter.movement: _movement(hands, reference, tolerance),
      SignParameter.facialExpression: const ParameterResult(
        ParameterStatus.notEvaluated,
        hint: 'La expresión facial todavía no se evalúa automáticamente.',
      ),
    });
  }

  /// Sigue a una sola mano a lo largo del tramo.
  ///
  /// Con las dos manos a la vista, la "mano activa" de cada cuadro puede
  /// saltar de una a otra; ese salto parecería un movimiento que nadie hizo.
  /// Se elige la mano que más veces fue la activa y se la sigue por su
  /// etiqueta; si el detector le cambia la etiqueta en un cuadro suelto, se la
  /// reconoce por estar donde estaba la mano en el cuadro anterior.
  List<({VisionFrame frame, HandLandmarks hand})> _track(
      List<VisionFrame> frames) {
    var right = 0, left = 0;
    for (final f in frames) {
      final a = f.activeHand;
      if (a == null) continue;
      a.isRightHand ? right++ : left++;
    }
    if (right + left == 0) return const [];
    final side = right >= left;
    final out = <({VisionFrame frame, HandLandmarks hand})>[];
    Vec3? prev;
    for (final f in frames) {
      HandLandmarks? pick;
      for (final h in f.hands) {
        if (h.isRightHand == side) pick = h;
      }
      if (pick != null && prev != null && f.hands.length > 1) {
        // Dos manos con la misma etiqueta o etiqueta cruzada: la más cercana.
        final near = f.hands.reduce((a, b) =>
            a.palmCenter.distanceTo(prev!) <= b.palmCenter.distanceTo(prev)
                ? a
                : b);
        if (near.palmCenter.distanceTo(prev) + 0.08 <
            pick.palmCenter.distanceTo(prev)) {
          pick = near;
        }
      }
      if (pick == null && prev != null) {
        for (final h in f.hands) {
          if (h.palmCenter.distanceTo(prev) <= 0.12) pick = h;
        }
      }
      if (pick == null) continue;
      prev = pick.palmCenter;
      out.add((frame: f, hand: pick));
    }
    return out;
  }

  // ─────────────────────────── forma de la mano ───────────────────────────

  static const _fingerNames = [
    'el pulgar',
    'el índice',
    'el dedo medio',
    'el anular',
    'el meñique'
  ];

  double _shapeScore(HandLandmarks hand, SignReference ref) {
    final ext = hand.fingerExtension;
    var sum = 0.0, n = 0;
    for (var i = 0; i < 5; i++) {
      final expected = ref.fingers[i];
      if (expected == null) continue;
      sum += expected ? ext[i] : 1 - ext[i];
      n++;
    }
    return n == 0 ? 1 : sum / n;
  }

  ParameterResult _manual(
    List<({VisionFrame frame, HandLandmarks hand})> hands,
    SignReference ref,
    ToleranceProfile tol,
  ) {
    if (ref.fingers.every((f) => f == null)) {
      return const ParameterResult(ParameterStatus.notEvaluated);
    }
    final scores = [for (final h in hands) _shapeScore(h.hand, ref)];
    final score = _median(scores);
    // Además del promedio, cada dedo exigido tiene que coincidir: una mano
    // abierta no es "tres" aunque tres de sus cuatro dedos sí lo sean.
    final ext = _medianList([for (final h in hands) h.hand.fingerExtension]);
    var everyFinger = true;
    for (var i = 1; i < 5; i++) {
      final expected = ref.fingers[i];
      if (expected == null) continue;
      final agreement = expected ? ext[i] : 1 - ext[i];
      if (agreement < 0.4) everyFinger = false;
    }
    if (everyFinger && score >= tol.minShapeScore) {
      return ParameterResult(ParameterStatus.passed, score: score);
    }
    // Pista: el dedo que más se aleja de la guía, en el cuadro típico.
    var worst = -1;
    var worstGap = 0.0;
    for (var i = 1; i < 5; i++) {
      final expected = ref.fingers[i];
      if (expected == null) continue;
      final gap = expected ? 1 - ext[i] : ext[i];
      if (gap > worstGap) {
        worstGap = gap;
        worst = i;
      }
    }
    final hint = worst < 0
        ? 'Compara la forma de tus dedos con la guía.'
        : ref.fingers[worst]!
            ? 'Extiende ${_fingerNames[worst]} como en la guía.'
            : 'Dobla ${_fingerNames[worst]} como en la guía.';
    return ParameterResult(ParameterStatus.failed, hint: hint, score: score);
  }

  // ─────────────────────────── palma ───────────────────────────

  ParameterResult _palm(
    List<({VisionFrame frame, HandLandmarks hand})> hands,
    SignReference ref,
    ToleranceProfile tol,
  ) {
    final expected = ref.palm;
    if (expected == null) {
      return const ParameterResult(ParameterStatus.notEvaluated);
    }
    double frameScore(HandLandmarks hand) {
      final n = hand.palmNormal;
      return switch (expected) {
        PalmFacing.camera => (-n.z + 1) / 2,
        PalmFacing.signer => (n.z + 1) / 2,
        PalmFacing.up => (-n.y + 1) / 2,
        PalmFacing.down => (n.y + 1) / 2,
        PalmFacing.side => n.x.abs(),
      };
    }

    // Percentil 70: durante un movimiento la palma gira un poco; alcanza con
    // que la mayor parte del tramo tenga la orientación de la guía.
    final score =
        _percentile([for (final h in hands) frameScore(h.hand)], 0.7);
    return score >= tol.minPalmScore
        ? ParameterResult(ParameterStatus.passed, score: score)
        : ParameterResult(ParameterStatus.failed,
            hint: expected.hint, score: score);
  }

  // ─────────────────────────── lugar ───────────────────────────

  ParameterResult _place(
    List<({VisionFrame frame, HandLandmarks hand})> hands,
    SignReference ref,
    ToleranceProfile tol,
  ) {
    if (ref.place == SignPlace.any) {
      return const ParameterResult(ParameterStatus.notEvaluated);
    }
    var seen = 0, inside = 0;
    for (final h in hands) {
      final ok = _inPlace(h.frame, h.hand, ref.place);
      if (ok == null) continue;
      seen++;
      if (ok) inside++;
    }
    if (seen < 2) {
      return const ParameterResult(
        ParameterStatus.notEvaluated,
        hint: 'Aleja un poco el teléfono para que se vean tu cara y tus '
            'hombros.',
      );
    }
    final fraction = inside / seen;
    // Frente y mentón son el punto de partida: alcanza con pasar por ahí.
    final transient =
        ref.place == SignPlace.forehead || ref.place == SignPlace.chin;
    final needed = transient
        ? math.max(3 / seen, tol.minPlaceFraction * 0.4)
        : tol.minPlaceFraction;
    return fraction >= needed
        ? ParameterResult(ParameterStatus.passed, score: fraction)
        : ParameterResult(ParameterStatus.failed,
            hint: ref.place.hint, score: fraction);
  }

  /// true/false si se pudo medir; null si no hay cuerpo visible.
  bool? _inPlace(VisionFrame f, HandLandmarks hand, SignPlace place) {
    final body = f.body;
    if (body == null || f.shoulderWidth == null) return null;
    final nose = body.point(BodyLandmarks.nose);
    final ls = body.point(BodyLandmarks.leftShoulder);
    final rs = body.point(BodyLandmarks.rightShoulder);
    final shoulders = Vec3((ls.x + rs.x) / 2, (ls.y + rs.y) / 2, 0);
    final ml = body.point(BodyLandmarks.mouthLeft);
    final mr = body.point(BodyLandmarks.mouthRight);
    final mouth = Vec3((ml.x + mr.x) / 2, (ml.y + mr.y) / 2, 0);

    final palm = hand.palmCenter;
    final palmN = f.toBodyUnits(palm, nose)!; // respecto de la nariz
    final palmS = f.toBodyUnits(palm, shoulders)!; // respecto de los hombros
    final tips = [
      hand.point(HandLandmarks.indexTip),
      hand.point(HandLandmarks.middleTip)
    ];
    switch (place) {
      case SignPlace.besideHead:
        return palmN.x.abs() >= 0.35 && palmS.y >= -1.0 && palmS.y <= 0.45;
      case SignPlace.raised:
        return palmS.y <= 0.6;
      case SignPlace.forehead:
        return tips.any((t) {
          final p = f.toBodyUnits(t, nose)!;
          return p.y <= 0.05 && p.y >= -1.0 && p.x.abs() <= 1.2;
        });
      case SignPlace.chin:
        return tips.any((t) =>
            f.toBodyUnits(t, mouth)!.length <= 0.42 &&
            f.toBodyUnits(t, nose)!.y >= -0.05);
      case SignPlace.chest:
        return palmS.y >= -0.05 && palmS.y <= 0.65 && palmS.x.abs() <= 0.6;
      case SignPlace.any:
        return true;
    }
  }

  // ─────────────────────────── movimiento ───────────────────────────

  ParameterResult _movement(
    List<({VisionFrame frame, HandLandmarks hand})> hands,
    SignReference ref,
    ToleranceProfile tol,
  ) {
    if (ref.movement == MovementPattern.any) {
      return const ParameterResult(ParameterStatus.notEvaluated);
    }
    if (hands.length < 3) {
      return ParameterResult(ParameterStatus.failed, hint: ref.movement.hint);
    }
    // Trayectoria de la palma en "anchos de hombro" (o en tamaños de palma
    // si no se ve el cuerpo).
    final path = <Vec3>[];
    final faceDist = <double>[];
    for (final h in hands) {
      final f = h.frame;
      final c = h.hand.palmCenter;
      final s = f.shoulderWidth;
      if (s != null) {
        path.add(Vec3(c.x * f.aspect / s, c.y / s, 0));
        final nose = f.body!.point(BodyLandmarks.nose);
        final tip = h.hand.point(HandLandmarks.middleTip);
        faceDist.add(f.toBodyUnits(tip, nose)!.length);
      } else {
        final p = math.max(h.hand.palmSize, 1e-6) * 3.0;
        path.add(Vec3(c.x * f.aspect / p, c.y / p, 0));
      }
    }
    final xs = [for (final p in path) p.x];
    final ys = [for (final p in path) p.y];
    final dx = xs.reduce(math.max) - xs.reduce(math.min);
    final dy = ys.reduce(math.max) - ys.reduce(math.min);
    var length = 0.0;
    for (var i = 1; i < path.length; i++) {
      length += path[i].distanceTo(path[i - 1]);
    }
    final slack = tol.movementSlack;
    int turns(List<double> v, double minStep) {
      var count = 0, dir = 0;
      var anchor = v.first;
      for (final x in v.skip(1)) {
        final d = x - anchor;
        if (d.abs() < minStep) continue;
        final s = d.sign.toInt();
        if (dir != 0 && s != dir) count++;
        dir = s;
        anchor = x;
      }
      return count;
    }

    final bool ok;
    switch (ref.movement) {
      case MovementPattern.none:
        ok = math.max(dx, dy) <= 0.25 * slack;
      case MovementPattern.lateral:
        // Un saludo: al menos dos cambios de dirección de lado a lado.
        ok = dx >= 0.30 / slack && turns(xs, 0.12 / slack) >= 2;
      case MovementPattern.vertical:
        // Asentir: sube y baja en el lugar, sin desplazarse de costado.
        ok = dy >= 0.06 / slack &&
            dy <= 0.6 * slack &&
            dx <= 0.3 * slack &&
            turns(ys, 0.03 / slack) >= 2;
      case MovementPattern.awayFromFace:
        if (faceDist.length >= 3) {
          final closest = faceDist.reduce(math.min);
          final i = faceDist.indexOf(closest);
          final after = faceDist.sublist(i).reduce(math.max);
          ok = after - closest >= 0.20 / slack;
        } else {
          ok = math.max(dx, dy) >= 0.25 / slack;
        }
      case MovementPattern.circular:
        // Un círculo real: recorre en los dos ejes y vuelve en los dos.
        final tx = turns(xs, 0.05 / slack), ty = turns(ys, 0.05 / slack);
        ok = math.min(dx, dy) >= 0.12 / slack &&
            tx >= 1 &&
            ty >= 1 &&
            tx + ty >= 3 &&
            length >= 2.2 * math.max(dx, dy) / slack;
      case MovementPattern.any:
        ok = true;
    }
    return ok
        ? const ParameterResult(ParameterStatus.passed)
        : ParameterResult(ParameterStatus.failed, hint: ref.movement.hint);
  }

  // ─────────────────────────── utilidades ───────────────────────────

  static double _median(List<double> v) {
    if (v.isEmpty) return 0;
    final s = [...v]..sort();
    final m = s.length ~/ 2;
    return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
  }

  static double _percentile(List<double> v, double q) {
    if (v.isEmpty) return 0;
    final s = [...v]..sort();
    return s[((s.length - 1) * q).round()];
  }

  static List<double> _medianList(List<List<double>> rows) => [
        for (var i = 0; i < rows.first.length; i++)
          _median([for (final r in rows) r[i]])
      ];
}
