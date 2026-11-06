import 'package:flutter_test/flutter_test.dart';
import 'package:senasgo/features/avatar/data/sign_animation_catalog.dart';
import 'package:senasgo/features/avatar/domain/teacher_step.dart';
import 'package:senasgo/features/avatar/presentation/widgets/jaguar_teacher.dart';
import 'package:senasgo/features/learning/data/seed_data.dart';

void main() {
  test('Cada seña del catálogo tiene clip y animación 2D de respaldo', () {
    for (final sign in SeedData.signs) {
      expect(JaguarTeacher.clipIds, contains(sign.id),
          reason: 'Falta el clip 3D de ${sign.id}');
      expect(SignAnimationCatalog.of(sign.id).keyframes, isNotEmpty,
          reason: 'Falta la animación 2D de ${sign.id}');
    }
    expect(JaguarTeacher.clipIds, contains('idle'));
  });

  test('La animación se resuelve por nombre sin tildes ni mayúsculas', () {
    expect(SignAnimationCatalog.resolve('Hola')?.signId, 'saludo_hola');
    expect(SignAnimationCatalog.resolve('POR FAVOR')?.signId,
        'basico_por_favor');
    expect(SignAnimationCatalog.resolve('seña inexistente'), isNull);
  });

  test('Cada seña tiene una demostración guiada por pasos', () {
    for (final sign in SeedData.signs) {
      final steps = TeacherLessonCatalog.stepsFor(sign.id);
      expect(steps.length, greaterThanOrEqualTo(2),
          reason: '${sign.id} necesita al menos forma y lugar');
      expect(steps.first.title, 'Forma');
      expect(steps.first.view, TeacherView.hands);
      expect(steps[1].title, 'Lugar');
      expect(steps[1].view, TeacherView.body);
      for (final step in steps) {
        expect(step.clip, startsWith('${sign.id}_'));
        expect(step.instruction, isNotEmpty);
      }
    }
  });

  test('Los números no tienen paso de movimiento', () {
    for (final id in ['numero_uno', 'numero_dos', 'numero_tres']) {
      final steps = TeacherLessonCatalog.stepsFor(id);
      expect(steps.map((s) => s.title), isNot(contains('Movimiento')));
    }
  });

  test('El catálogo de pasos cubre todos los clips del GLB', () {
    expect(TeacherLessonCatalog.stepClipIds.length, 26);
    expect(TeacherLessonCatalog.stepClipIds, contains('saludo_hola_forma'));
    expect(
        TeacherLessonCatalog.stepClipIds, contains('basico_por_favor_movimiento'));
  });
}
