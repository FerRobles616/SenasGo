// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProgressModelAdapter extends TypeAdapter<ProgressModel> {
  @override
  final int typeId = 4;

  @override
  ProgressModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProgressModel(
      userId: fields[0] as String,
      completedSignIds: (fields[1] as List).cast<String>(),
      streakDays: fields[2] as int,
      lastPracticeDate: fields[3] as DateTime?,
      totalPracticeTimeSeconds: fields[4] as int,
      correctAttempts: fields[5] as int,
      totalAttempts: fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ProgressModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.completedSignIds)
      ..writeByte(2)
      ..write(obj.streakDays)
      ..writeByte(3)
      ..write(obj.lastPracticeDate)
      ..writeByte(4)
      ..write(obj.totalPracticeTimeSeconds)
      ..writeByte(5)
      ..write(obj.correctAttempts)
      ..writeByte(6)
      ..write(obj.totalAttempts);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgressModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
