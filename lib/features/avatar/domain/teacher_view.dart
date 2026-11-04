/// Encuadre del profesor 3D.
///
/// La vista no es libre: el profesor elige el encuadre que mejor muestra cada
/// paso de la seña.
enum TeacherView {
  /// Plano medio: cabeza, hombros, pecho y manos. Nunca piernas.
  body('Torso'),
  hands('Manos');

  const TeacherView(this.label);

  final String label;
}
