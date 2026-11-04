// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sign_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SignModelAdapter extends TypeAdapter<SignModel> {
  @override
  final int typeId = 3;

  @override
  SignModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SignModel(
      id: fields[0] as String,
      name: fields[1] as String,
      category: fields[2] as SignCategory,
      description: fields[3] as String,
      assetImagePath: fields[4] as String,
      assetAnimationPath: fields[5] as String?,
      riveAssetPath: fields[6] as String?,
      keypointsLabel: fields[7] as String?,
      isActive: fields[8] as bool,
      tags: (fields[9] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, SignModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.assetImagePath)
      ..writeByte(5)
      ..write(obj.assetAnimationPath)
      ..writeByte(6)
      ..write(obj.riveAssetPath)
      ..writeByte(7)
      ..write(obj.keypointsLabel)
      ..writeByte(8)
      ..write(obj.isActive)
      ..writeByte(9)
      ..write(obj.tags);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SignCategoryAdapter extends TypeAdapter<SignCategory> {
  @override
  final int typeId = 2;

  @override
  SignCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SignCategory.greetings;
      case 1:
        return SignCategory.numbers;
      case 2:
        return SignCategory.basics;
      case 3:
        return SignCategory.family;
      case 4:
        return SignCategory.emotions;
      default:
        return SignCategory.greetings;
    }
  }

  @override
  void write(BinaryWriter writer, SignCategory obj) {
    switch (obj) {
      case SignCategory.greetings:
        writer.writeByte(0);
        break;
      case SignCategory.numbers:
        writer.writeByte(1);
        break;
      case SignCategory.basics:
        writer.writeByte(2);
        break;
      case SignCategory.family:
        writer.writeByte(3);
        break;
      case SignCategory.emotions:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
