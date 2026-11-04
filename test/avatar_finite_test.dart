import 'package:flutter_test/flutter_test.dart';
import 'package:senasgo/core/vision/hand_landmarks.dart';
import 'package:senasgo/features/avatar/data/sign_animation_catalog.dart';
import 'package:senasgo/features/avatar/presentation/rendering/avatar_skeleton.dart';
import 'package:senasgo/features/learning/data/seed_data.dart';

bool _finite(Vec3 p) => p.x.isFinite && p.y.isFinite && p.z.isFinite;

void main() {
  test('El esqueleto nunca produce coordenadas NaN o infinitas', () {
    for (final sign in SeedData.signs) {
      final a = SignAnimationCatalog.of(sign.id);
      for (var i = 0; i <= 200; i++) {
        final s = AvatarSkeleton.solve(a.sample(i / 200), breath: 0.004);
        final points = <Vec3>[
          s.neck,
          s.headCenter,
          for (final arm in [s.dominant, s.passive]) ...[
            arm.shoulder,
            arm.elbow,
            arm.hand.wrist,
            arm.hand.normal,
            ...arm.hand.palm,
            for (final f in arm.hand.fingers) ...f,
          ],
          for (final u in [-0.97, -0.36, 0.0, 0.36, 0.97])
            for (final v in [-0.52, -0.14, 0.04, 0.3, 0.78]) s.facePoint(u, v),
        ];
        for (final p in points) {
          expect(_finite(p), isTrue, reason: '${sign.id} i=$i $p');
        }
      }
    }
  });
}
