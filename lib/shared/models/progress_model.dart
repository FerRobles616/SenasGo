import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'progress_model.g.dart';

@HiveType(typeId: 4)
class ProgressModel extends Equatable {
  const ProgressModel({
    required this.userId,
    required this.completedSignIds,
    required this.streakDays,
    required this.lastPracticeDate,
    required this.totalPracticeTimeSeconds,
    required this.correctAttempts,
    required this.totalAttempts,
  });

  @HiveField(0)
  final String userId;
  @HiveField(1)
  final List<String> completedSignIds;
  @HiveField(2)
  final int streakDays;
  @HiveField(3)
  final DateTime? lastPracticeDate;
  @HiveField(4)
  final int totalPracticeTimeSeconds;
  @HiveField(5)
  final int correctAttempts;
  @HiveField(6)
  final int totalAttempts;

  double get accuracy =>
      totalAttempts == 0 ? 0 : correctAttempts / totalAttempts;

  ProgressModel copyWith({
    String? userId,
    List<String>? completedSignIds,
    int? streakDays,
    DateTime? lastPracticeDate,
    int? totalPracticeTimeSeconds,
    int? correctAttempts,
    int? totalAttempts,
  }) {
    return ProgressModel(
      userId: userId ?? this.userId,
      completedSignIds: completedSignIds ?? this.completedSignIds,
      streakDays: streakDays ?? this.streakDays,
      lastPracticeDate: lastPracticeDate ?? this.lastPracticeDate,
      totalPracticeTimeSeconds:
          totalPracticeTimeSeconds ?? this.totalPracticeTimeSeconds,
      correctAttempts: correctAttempts ?? this.correctAttempts,
      totalAttempts: totalAttempts ?? this.totalAttempts,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        completedSignIds,
        streakDays,
        lastPracticeDate,
        totalPracticeTimeSeconds,
        correctAttempts,
        totalAttempts,
      ];
}
