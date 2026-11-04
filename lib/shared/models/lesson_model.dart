import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'lesson_model.g.dart';

@HiveType(typeId: 1)
class LessonModel extends Equatable {
  const LessonModel({
    required this.id,
    required this.title,
    required this.description,
    required this.signIds,
    required this.isCompleted,
    required this.difficulty,
    required this.order,
  });

  @HiveField(0)
  final String id;
  @HiveField(1)
  final String title;
  @HiveField(2)
  final String description;
  @HiveField(3)
  final List<String> signIds;
  @HiveField(4)
  final bool isCompleted;
  @HiveField(5)
  final int difficulty;
  @HiveField(6)
  final int order;

  LessonModel copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? signIds,
    bool? isCompleted,
    int? difficulty,
    int? order,
  }) {
    return LessonModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      signIds: signIds ?? this.signIds,
      isCompleted: isCompleted ?? this.isCompleted,
      difficulty: difficulty ?? this.difficulty,
      order: order ?? this.order,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        signIds,
        isCompleted,
        difficulty,
        order,
      ];
}
