import 'package:flutter/material.dart';
import 'package:senasgo/features/avatar/domain/teacher_view.dart';

/// Un paso de la demostración guiada.
///
/// Cada paso tiene su propio clip corto en `teacher.glb` y termina sosteniendo
/// la pose. Así el estudiante puede mirar una cosa por vez en vez de intentar
/// seguir una animación completa y libre.
class TeacherStep {
  const TeacherStep({
    required this.title,
    required this.instruction,
    required this.clip,
    required this.view,
    required this.icon,
  });

  final String title;
  final String instruction;
  final String clip;
  final TeacherView view;
  final IconData icon;
}

/// Catálogo de pasos por seña.
///
/// Los textos son ilustrativos y están pendientes de validación por una persona
/// experta en LSPy. La UI muestra esa advertencia.
class TeacherLessonCatalog {
  const TeacherLessonCatalog._();

  /// Señas que tienen movimiento además de la forma y el lugar.
  static const movementSigns = <String>{
    'saludo_saludos',
    'saludo_chau',
    'basico_gracias',
    'basico_si',
    'basico_no',
    'basico_por_favor',
  };

  static List<TeacherStep> stepsFor(String signId) {
    final spec = _specs[signId];
    if (spec == null) return const [];
    return [
      TeacherStep(
        title: 'Forma',
        instruction: spec.forma,
        clip: '${signId}_forma',
        view: TeacherView.hands,
        icon: Icons.back_hand_outlined,
      ),
      TeacherStep(
        title: 'Lugar',
        instruction: spec.lugar,
        clip: '${signId}_lugar',
        view: TeacherView.body,
        icon: Icons.my_location_rounded,
      ),
      if (spec.movimiento != null)
        TeacherStep(
          title: 'Movimiento',
          instruction: spec.movimiento!,
          clip: '${signId}_movimiento',
          view: TeacherView.body,
          icon: Icons.swap_horiz_rounded,
        ),
    ];
  }

  /// Todos los clips de paso que debería incluir el GLB.
  static Set<String> get stepClipIds {
    final ids = <String>{};
    for (final entry in _specs.entries) {
      ids.add('${entry.key}_forma');
      ids.add('${entry.key}_lugar');
      if (entry.value.movimiento != null) {
        ids.add('${entry.key}_movimiento');
      }
    }
    return ids;
  }

  static const _specs = <String, _StepSpec>{
    'saludo_hola': _StepSpec(
      forma: 'Mano abierta, dedos extendidos y palma hacia adelante.',
      lugar: 'Al costado de la cabeza, a la altura del hombro.',
    ),
    'saludo_saludos': _StepSpec(
      forma: 'Mano plana, dedos juntos y un poco doblados en los nudillos.',
      lugar: 'La punta de los dedos junto a la frente, como un saludo.',
      movimiento: 'Separá la mano de la frente hacia el costado.',
    ),
    'saludo_chau': _StepSpec(
      forma: 'Mano abierta a la altura del hombro.',
      lugar: 'Llevá la mano al costado de la cabeza, con la palma al frente.',
      movimiento: 'Oscilá la mano de lado a lado, con la muñeca relajada.',
    ),
    'numero_uno': _StepSpec(
      forma: 'Índice extendido; los demás dedos doblados.',
      lugar: 'Mano a la altura del pecho, con la palma al frente.',
    ),
    'numero_dos': _StepSpec(
      forma: 'Índice y medio extendidos y separados, formando una V.',
      lugar: 'Mano a la altura del pecho, con la palma al frente.',
    ),
    'numero_tres': _StepSpec(
      forma: 'Índice, medio y anular extendidos; pulgar y meñique doblados.',
      lugar: 'Mano a la altura del pecho, con la palma al frente.',
    ),
    'basico_gracias': _StepSpec(
      forma: 'Mano abierta con la palma hacia vos.',
      lugar: 'Acercá los dedos al mentón.',
      movimiento:
          'Llevá la mano hacia adelante y abajo, con la palma hacia arriba.',
    ),
    'basico_si': _StepSpec(
      forma: 'Puño cerrado, con el pulgar apoyado sobre los dedos.',
      lugar: 'Puño a la altura del pecho.',
      movimiento: 'Bajá y subí el puño, como afirmando.',
    ),
    'basico_no': _StepSpec(
      forma: 'Índice y medio extendidos, formando una V.',
      lugar: 'Mano a la altura del pecho.',
      movimiento: 'Cerrá y abrí los dedos hacia el pulgar, dos veces.',
    ),
    'basico_por_favor': _StepSpec(
      forma: 'Mano abierta con la palma sobre el pecho.',
      lugar: 'Centro del pecho.',
      movimiento: 'Hacé un círculo pequeño sobre el pecho.',
    ),
  };
}

class _StepSpec {
  const _StepSpec({
    required this.forma,
    required this.lugar,
    this.movimiento,
  });

  final String forma;
  final String lugar;
  final String? movimiento;
}
