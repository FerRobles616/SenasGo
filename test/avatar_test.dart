import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senasgo/core/vision/hand_landmarks.dart';
import 'package:senasgo/features/avatar/data/sign_animation_catalog.dart';
import 'package:senasgo/features/avatar/domain/sign_animation_model.dart';
import 'package:senasgo/features/avatar/presentation/controllers/avatar_playback_controller.dart';
import 'package:senasgo/features/avatar/presentation/controllers/gesture_avatar_controller.dart';
import 'package:senasgo/features/avatar/presentation/rendering/avatar_skeleton.dart';
import 'package:senasgo/features/avatar/presentation/widgets/gesture_avatar.dart';
import 'package:senasgo/features/avatar/presentation/widgets/pro_sign_language_avatar.dart';
import 'package:senasgo/features/learning/data/seed_data.dart';

void main() {
  group('Catálogo de animaciones', () {
    test('Cada seña del vocabulario tiene su animación', () {
      for (final sign in SeedData.signs) {
        final a = SignAnimationCatalog.of(sign.id);
        expect(a.signId, sign.id);
        expect(a.keyframes, isNotEmpty, reason: sign.id);
      }
    });

    test('Toda seña empieza y termina en reposo (sin cortes)', () {
      for (final sign in SeedData.signs) {
        final a = SignAnimationCatalog.of(sign.id);
        for (final t in [0.0, 1.0]) {
          final w = a.sample(t).dominant.wrist;
          expect(w.distanceTo(AvatarFrame.rest.dominant.wrist), lessThan(1e-6),
              reason: '${sign.id} t=$t');
        }
      }
    });

    test('La trayectoria es continua: no hay saltos entre fotogramas', () {
      for (final sign in SeedData.signs) {
        final a = SignAnimationCatalog.of(sign.id);
        Vec3? prev;
        for (var i = 0; i <= 600; i++) {
          final w = a.sample(i / 600).dominant.wrist;
          if (prev != null) {
            expect(w.distanceTo(prev), lessThan(0.02),
                reason: '${sign.id} i=$i');
          }
          prev = w;
        }
      }
    });

    test('En la retención la mano queda quieta', () {
      final a = SignAnimationCatalog.of('saludo_hola');
      final w1 = a.sample(0.6).dominant.wrist;
      final w2 = a.sample(0.7).dominant.wrist;
      expect(w1.distanceTo(w2), lessThan(1e-6));
    });

    test('"No" incluye la negación no manual (cabeza y ceño)', () {
      final a = SignAnimationCatalog.of('basico_no');
      final f = a.sample(0.34);
      expect(f.face.browFurrow, greaterThan(0.5));
      expect(f.body.headYaw.abs(), greaterThan(5));
    });
  });

  test('IK: brazo y antebrazo conservan su largo', () {
    final s = AvatarSkeleton.solve(
        SignAnimationCatalog.of('saludo_hola').sample(0.25));
    final arm = s.dominant;
    expect(arm.shoulder.distanceTo(arm.elbow),
        closeTo(AvatarSkeleton.upperArm, 1e-6));
    expect(arm.elbow.distanceTo(arm.hand.wrist),
        closeTo(AvatarSkeleton.forearm, 1e-6));
    expect(arm.hand.fingers, hasLength(5));
  });

  testWidgets('Controles: cámara lenta, pausa y repetir', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ProSignLanguageAvatar(
            animation: SignAnimationCatalog.of('saludo_chau'),
            autoplay: false,
          ),
        ),
      ),
    ));
    await tester.pump();

    final state = tester.state(find.byType(ProSignLanguageAvatar));
    final controller =
        (state as dynamic).controllerForTest as AvatarPlaybackController;

    expect(controller.speed, PlaybackSpeed.normal);
    await tester.tap(find.text('0.5x'));
    await tester.pump();
    expect(controller.speed, PlaybackSpeed.slow);

    await tester.tap(find.bySemanticsLabel('Reproducir'));
    await tester.pump(); // primer frame: arranca el reloj de la animación
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.isPlaying, isTrue);
    // A 0.5x la seña de 2.4 s dura 4.8 s: tras 0.5 s va por ~10 %.
    expect(controller.progress, closeTo(0.104, 0.02));

    await tester.tap(find.bySemanticsLabel('Repetir seña'));
    await tester.pump(const Duration(milliseconds: 16));
    expect(controller.progress, lessThan(0.02));

    await tester.pumpWidget(const SizedBox());
  });

  group('playSign', () {
    test('Encuentra la seña por palabra, sin importar tildes ni mayúsculas',
        () {
      expect(SignAnimationCatalog.resolve('Hola')?.signId, 'saludo_hola');
      expect(SignAnimationCatalog.resolve('  POR FAVOR ')?.signId,
          'basico_por_favor');
      expect(SignAnimationCatalog.resolve('si')?.signId, 'basico_si');
      expect(SignAnimationCatalog.resolve('Sí')?.signId, 'basico_si');
      expect(SignAnimationCatalog.resolve('basico_gracias')?.signId,
          'basico_gracias');
    });

    test('Una seña sin animación devuelve false y no cambia el avatar', () {
      final c = GestureAvatarController();
      expect(c.playSign('A'), isFalse);
      expect(c.current.signId, 'saludo_hola');
      expect(c.lastCommand, isNull);
    });

    testWidgets('playSign cambia la seña y reproduce; replay vuelve a empezar',
        (tester) async {
      final avatar = GestureAvatarController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: GestureAvatar(controller: avatar)),
        ),
      ));
      await tester.pump();
      final state = tester.state(find.byType(ProSignLanguageAvatar));
      final playback =
          (state as dynamic).controllerForTest as AvatarPlaybackController;
      expect(playback.isPlaying, isFalse);

      expect(avatar.playSign('Gracias'), isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(playback.animation.signId, 'basico_gracias');
      expect(playback.isPlaying, isTrue);
      final firstPlay = playback.playId;

      avatar.setSpeed(PlaybackSpeed.slow);
      await tester.pump();
      expect(playback.speed, PlaybackSpeed.slow);

      avatar.replay();
      await tester.pump();
      expect(playback.playId, firstPlay + 1);
      expect(playback.progress, lessThan(0.02));

      avatar.stop();
      await tester.pump(const Duration(milliseconds: 400));
      expect(playback.isPlaying, isFalse);
      expect(playback.progress, 0);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
