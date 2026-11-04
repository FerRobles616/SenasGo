import 'package:senasgo/features/practice/domain/sign_reference.dart';

enum ParameterStatus { passed, failed, notEvaluated }

class ParameterResult {
  const ParameterResult(this.status, {this.hint = ''});

  final ParameterStatus status;

  /// Indicación cualitativa para corregir (nunca un porcentaje).
  final String hint;
}

/// Resultado de evaluar una seña sobre los 5 parámetros formativos.
class SignEvaluation {
  const SignEvaluation(this.parameters);

  final Map<SignParameter, ParameterResult> parameters;

  bool get isCorrect =>
      parameters.values.every((p) => p.status != ParameterStatus.failed);

  /// Primer parámetro que falló, en orden pedagógico.
  SignParameter? get primaryIssue {
    for (final p in SignParameter.values) {
      if (parameters[p]?.status == ParameterStatus.failed) return p;
    }
    return null;
  }

  /// Mensaje cualitativo para la UI (documentación v3_04, estado 9).
  String get feedbackTitle {
    switch (primaryIssue) {
      case null:
        return '¡Muy bien!';
      case SignParameter.manualConfig:
        return '✕ Necesita mejorar: La posición de la mano no coincide con la guía';
      case SignParameter.palmOrientation:
        return '✕ Necesita mejorar: La orientación de la palma no coincide con la guía';
      case SignParameter.articulationPlace:
        return '✕ Necesita mejorar: El lugar de la seña no coincide con la guía';
      case SignParameter.movement:
        return '✕ Necesita mejorar: El movimiento no coincide con la guía';
      case SignParameter.facialExpression:
        return '✕ Necesita mejorar: Acompaña la seña con la expresión de la guía';
    }
  }

  String get feedbackHint {
    final issue = primaryIssue;
    if (issue == null) return 'Seña reconocida correctamente';
    final hint = parameters[issue]!.hint;
    return hint.isEmpty ? 'Revisa la guía e inténtalo nuevamente.' : hint;
  }
}
