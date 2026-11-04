import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:senasgo/core/vision/hand_geometry.dart';
import 'package:senasgo/core/vision/hand_landmarks.dart';
import 'package:senasgo/core/vision/tolerance_profile.dart';

void main() {
  const geometry = HandGeometry();

  test('El embedding es invariante a traslación y escala', () {
    final original = _hand();
    final moved = _transformed(original, dx: 0.18, dy: -0.12, scale: 2.4);

    final a = geometry.embedding(original);
    final b = geometry.embedding(moved);

    for (var i = 0; i < a.length; i++) {
      expect(b[i], closeTo(a[i], 1e-5));
    }
    expect(geometry.cosine(a, b), closeTo(1.0, 1e-5));
  });

  test('La estabilidad baja cuando la forma de la mano cambia', () {
    final same = geometry.shapeStability([_hand(), _hand()]);
    final changed = geometry.shapeStability([_hand(), _fist()]);

    expect(same, closeTo(1.0, 1e-5));
    expect(changed, lessThan(same));
  });

  test('El encuadre premia la mano centrada', () {
    expect(geometry.framingScore(_hand(wristX: 0.5, wristY: 0.5)),
        closeTo(1.0, 1e-5));
    expect(geometry.framingScore(_hand(wristX: 0.95, wristY: 0.95)),
        lessThan(0.2));
  });

  test('El umbral de forma sube con el nivel', () {
    final beginner = ToleranceProfile.forLevel(1);
    final advanced = ToleranceProfile.forLevel(5);

    expect(beginner.minShapeScore, closeTo(0.52, 1e-9));
    expect(advanced.minShapeScore, greaterThan(beginner.minShapeScore));
    expect(advanced.minPalmScore, greaterThan(beginner.minPalmScore));
    expect(advanced.minShapeStability,
        greaterThan(beginner.minShapeStability));
  });
}

HandLandmarks _hand({double wristX = 0.5, double wristY = 0.9}) {
  final p = Float32List(63);
  void set(int i, double x, double y) {
    p[i * 3] = x;
    p[i * 3 + 1] = y;
  }

  set(0, wristX, wristY);
  set(1, wristX - 0.10, wristY - 0.08);
  set(2, wristX - 0.17, wristY - 0.16);
  set(3, wristX - 0.23, wristY - 0.24);
  set(4, wristX - 0.29, wristY - 0.32);
  const xs = [0.38, 0.46, 0.54, 0.62];
  for (var f = 0; f < 4; f++) {
    final base = 5 + f * 4;
    final x = xs[f];
    set(base, x, 0.60);
    set(base + 1, x, 0.47);
    set(base + 2, x, 0.37);
    set(base + 3, x, 0.28);
  }
  return HandLandmarks(
    points: p,
    presence: 0.99,
    isRightHand: true,
    timestamp: DateTime.now(),
  );
}

HandLandmarks _fist() {
  final p = Float32List(63);
  void set(int i, double x, double y) {
    p[i * 3] = x;
    p[i * 3 + 1] = y;
  }

  set(0, 0.5, 0.9);
  set(1, 0.40, 0.82);
  set(2, 0.33, 0.74);
  set(3, 0.40, 0.70);
  set(4, 0.45, 0.66);
  const xs = [0.38, 0.46, 0.54, 0.62];
  for (var f = 0; f < 4; f++) {
    final base = 5 + f * 4;
    final x = xs[f];
    set(base, x, 0.60);
    set(base + 1, x, 0.47);
    set(base + 2, x, 0.55);
    set(base + 3, x, 0.64);
  }
  return HandLandmarks(
    points: p,
    presence: 0.99,
    isRightHand: true,
    timestamp: DateTime.now(),
  );
}

HandLandmarks _transformed(
  HandLandmarks hand, {
  required double dx,
  required double dy,
  required double scale,
}) {
  final out = Float32List(63);
  final wx = hand.points[0], wy = hand.points[1];
  for (var i = 0; i < 21; i++) {
    out[i * 3] = wx + (hand.points[i * 3] - wx) * scale + dx;
    out[i * 3 + 1] = wy + (hand.points[i * 3 + 1] - wy) * scale + dy;
    out[i * 3 + 2] = hand.points[i * 3 + 2] * scale;
  }
  return HandLandmarks(
    points: out,
    presence: hand.presence,
    isRightHand: hand.isRightHand,
    timestamp: hand.timestamp,
  );
}
