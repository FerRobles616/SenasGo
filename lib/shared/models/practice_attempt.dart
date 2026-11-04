import 'package:equatable/equatable.dart';

/// Registro liviano de un intento, para la pantalla de progreso.
/// Se guarda como mapa dentro de la caja de juego (no necesita adaptador Hive).
class PracticeAttempt extends Equatable {
  const PracticeAttempt({
    required this.signId,
    required this.correct,
    required this.at,
  });

  factory PracticeAttempt.fromMap(Map<dynamic, dynamic> map) => PracticeAttempt(
        signId: map['signId'] as String? ?? '',
        correct: map['correct'] as bool? ?? false,
        at: DateTime.tryParse(map['at'] as String? ?? '') ?? DateTime.now(),
      );

  final String signId;
  final bool correct;
  final DateTime at;

  Map<String, dynamic> toMap() => {
        'signId': signId,
        'correct': correct,
        'at': at.toIso8601String(),
      };

  @override
  List<Object?> get props => [signId, correct, at];
}
