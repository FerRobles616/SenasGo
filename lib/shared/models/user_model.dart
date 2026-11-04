import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'user_model.g.dart';

@HiveType(typeId: 0)
class UserModel extends Equatable {
  const UserModel({
    required this.id,
    required this.username,
    required this.level,
    required this.xp,
    required this.completedLessons,
    required this.currentLessonId,
    required this.createdAt,
    required this.lastLogin,
  });

  factory UserModel.initial() {
    final now = DateTime.now();
    return UserModel(
      id: const Uuid().v4(),
      username: 'Usuario',
      level: 1, // Principiante - más tolerante
      xp: 0,
      completedLessons: const [],
      currentLessonId: null,
      createdAt: now,
      lastLogin: now,
    );
  }

  @HiveField(0)
  final String id;
  @HiveField(1)
  final String username;
  @HiveField(2)
  final int level;
  @HiveField(3)
  final int xp;
  @HiveField(4)
  final List<String> completedLessons;
  @HiveField(6)
  final String? currentLessonId;
  @HiveField(7)
  final DateTime createdAt;
  @HiveField(8)
  final DateTime lastLogin;

  UserModel copyWith({
    String? id,
    String? username,
    int? level,
    int? xp,
    List<String>? completedLessons,
    String? currentLessonId,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      completedLessons: completedLessons ?? this.completedLessons,
      currentLessonId: currentLessonId ?? this.currentLessonId,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  @override
  List<Object?> get props => [
        id,
        username,
        level,
        xp,
        completedLessons,
        currentLessonId,
        createdAt,
        lastLogin,
      ];
}
