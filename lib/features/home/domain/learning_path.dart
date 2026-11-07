import 'package:senasgo/core/services/hive_service.dart';
import 'package:senasgo/shared/models/lesson_model.dart';
import 'package:senasgo/shared/models/sign_model.dart';

/// Estado visual de un nodo del camino.
enum NodeStatus {
  /// Ya practicada correctamente.
  completed,

  /// La próxima seña a practicar: se destaca con rebote.
  current,

  /// Aún no desbloqueada: en gris.
  locked,
}

class PathNode {
  const PathNode({
    required this.sign,
    required this.lessonId,
    required this.status,
    required this.indexInPath,
  });

  final SignModel sign;
  final String lessonId;
  final NodeStatus status;

  /// Posición global en el camino (define el zigzag).
  final int indexInPath;
}

class PathUnit {
  const PathUnit(
      {required this.index, required this.lesson, required this.nodes});

  final int index;
  final LessonModel lesson;
  final List<PathNode> nodes;

  int get completedCount =>
      nodes.where((n) => n.status == NodeStatus.completed).length;
  bool get isLocked => nodes.every((n) => n.status == NodeStatus.locked);
}

class PlayerStats {
  const PlayerStats({
    required this.streak,
    required this.practicedToday,
    required this.xp,
  });

  final int streak;
  final bool practicedToday;

  /// XP acumulada: define el nivel y el rigor de la evaluación.
  final int xp;
}

/// Arma el camino: las unidades son las lecciones y cada nodo, una seña.
/// Se avanza en orden; la primera seña no aprendida es la actual y todo lo
/// que viene después queda bloqueado.
class LearningPath {
  const LearningPath({required this.units, required this.stats});

  final List<PathUnit> units;
  final PlayerStats stats;

  PathNode? get current {
    for (final u in units) {
      for (final n in u.nodes) {
        if (n.status == NodeStatus.current) return n;
      }
    }
    return null;
  }

  factory LearningPath.build({
    required List<LessonModel> lessons,
    required List<SignModel> Function(String lessonId) signsOf,
    required Set<String> learned,
    required PlayerStats stats,
  }) {
    var foundCurrent = false;
    var index = 0;
    final units = <PathUnit>[];
    for (var u = 0; u < lessons.length; u++) {
      final lesson = lessons[u];
      final nodes = <PathNode>[];
      for (final sign in signsOf(lesson.id)) {
        final NodeStatus status;
        if (learned.contains(sign.id)) {
          status = NodeStatus.completed;
        } else if (!foundCurrent) {
          status = NodeStatus.current;
          foundCurrent = true;
        } else {
          status = NodeStatus.locked;
        }
        nodes.add(PathNode(
            sign: sign,
            lessonId: lesson.id,
            status: status,
            indexInPath: index++));
      }
      units.add(PathUnit(index: u, lesson: lesson, nodes: nodes));
    }
    return LearningPath(units: units, stats: stats);
  }

  /// Lee el estado local (Hive).
  factory LearningPath.fromStorage() => LearningPath.build(
        lessons: HiveService.lessons,
        signsOf: HiveService.signsOf,
        learned: HiveService.learnedSignIds,
        stats: PlayerStats(
          streak: HiveService.streak,
          practicedToday: HiveService.practicedToday,
          xp: HiveService.currentUser.xp,
        ),
      );
}
