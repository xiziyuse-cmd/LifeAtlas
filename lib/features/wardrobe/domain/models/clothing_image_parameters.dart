import 'season_tags.dart';

class ClothingImageParameters {
  ClothingImageParameters({
    this.name,
    this.brand,
    this.category,
    List<String> seasonTags = const [],
    this.color,
    this.material,
    this.size,
    this.clothingLength,
    this.shoulderWidth,
    this.chestCircumference,
    this.sleeveLength,
    this.waistCircumference,
    this.hipCircumference,
    this.trouserLength,
  }) : seasonTags = WardrobeSeasonTags.normalize(seasonTags);

  final String? name;
  final String? brand;
  final String? category;
  final List<String> seasonTags;
  final String? color;
  final String? material;
  final String? size;
  final double? clothingLength;
  final double? shoulderWidth;
  final double? chestCircumference;
  final double? sleeveLength;
  final double? waistCircumference;
  final double? hipCircumference;
  final double? trouserLength;
}
