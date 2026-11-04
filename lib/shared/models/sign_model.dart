import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'sign_model.g.dart';

@HiveType(typeId: 2)
enum SignCategory {
  @HiveField(0)
  greetings,
  @HiveField(1)
  numbers,
  @HiveField(2)
  basics,
  @HiveField(3)
  family,
  @HiveField(4)
  emotions,
}

@HiveType(typeId: 3)
class SignModel extends Equatable {
  const SignModel({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.assetImagePath,
    required this.assetAnimationPath,
    required this.riveAssetPath,
    required this.keypointsLabel,
    required this.isActive,
    required this.tags,
  });

  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final SignCategory category;
  @HiveField(3)
  final String description;
  @HiveField(4)
  final String assetImagePath;
  @HiveField(5)
  final String? assetAnimationPath;
  @HiveField(6)
  final String? riveAssetPath;
  @HiveField(7)
  final String? keypointsLabel;
  @HiveField(8)
  final bool isActive;
  @HiveField(9)
  final List<String> tags;

  @override
  List<Object?> get props => [
        id,
        name,
        category,
        description,
        assetImagePath,
        assetAnimationPath,
        riveAssetPath,
        keypointsLabel,
        isActive,
        tags,
      ];
}
