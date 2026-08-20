import 'dart:convert';

import 'season_tags.dart';

class ClothingItem {
  ClothingItem({
    this.id,
    required this.name,
    required this.imagePath,
    this.brand,
    this.category,
    this.brandId,
    this.categoryId,
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
    this.purchasePrice,
    this.purchaseDate,
    this.notes,
    this.isDeleted = false,
    this.wearCount = 0,
    this.minWornTemperature,
    this.maxWornTemperature,
    required this.createdAt,
    required this.updatedAt,
  }) : seasonTags = WardrobeSeasonTags.normalize(seasonTags);

  final int? id;
  final String name;
  final String imagePath;
  final String? brand;
  final String? category;
  final int? brandId;
  final int? categoryId;
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
  final double? purchasePrice;
  final DateTime? purchaseDate;
  final String? notes;
  final bool isDeleted;
  final int wearCount;
  final double? minWornTemperature;
  final double? maxWornTemperature;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'image_path': imagePath,
      'brand': brand,
      'category': category,
      'brand_id': brandId,
      'category_id': categoryId,
      'season_tags': jsonEncode(seasonTags),
      'color': color,
      'material': material,
      'size': size,
      'clothing_length': clothingLength,
      'shoulder_width': shoulderWidth,
      'chest_circumference': chestCircumference,
      'sleeve_length': sleeveLength,
      'waist_circumference': waistCircumference,
      'hip_circumference': hipCircumference,
      'trouser_length': trouserLength,
      'purchase_price': purchasePrice,
      'purchase_date': purchaseDate?.toIso8601String(),
      'notes': notes,
      'is_deleted': isDeleted ? 1 : 0,
      'wear_count': wearCount,
      'min_worn_temperature': minWornTemperature,
      'max_worn_temperature': maxWornTemperature,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ClothingItem.fromMap(Map<String, Object?> map) {
    return ClothingItem(
      id: map['id'] as int?,
      name: map['name'] as String,
      imagePath: map['image_path'] as String,
      brand: map['brand'] as String?,
      category: map['category'] as String?,
      brandId: map['brand_id'] as int?,
      categoryId: map['category_id'] as int?,
      seasonTags: WardrobeSeasonTags.decodeStorage(map['season_tags']),
      color: map['color'] as String?,
      material: map['material'] as String?,
      size: map['size'] as String?,
      clothingLength: (map['clothing_length'] as num?)?.toDouble(),
      shoulderWidth: (map['shoulder_width'] as num?)?.toDouble(),
      chestCircumference: (map['chest_circumference'] as num?)?.toDouble(),
      sleeveLength: (map['sleeve_length'] as num?)?.toDouble(),
      waistCircumference: (map['waist_circumference'] as num?)?.toDouble(),
      hipCircumference: (map['hip_circumference'] as num?)?.toDouble(),
      trouserLength: (map['trouser_length'] as num?)?.toDouble(),
      purchasePrice: (map['purchase_price'] as num?)?.toDouble(),
      purchaseDate: _dateTimeOrNull(map['purchase_date']),
      notes: map['notes'] as String?,
      isDeleted: map['is_deleted'] == 1,
      wearCount: map['wear_count'] as int? ?? 0,
      minWornTemperature: (map['min_worn_temperature'] as num?)?.toDouble(),
      maxWornTemperature: (map['max_worn_temperature'] as num?)?.toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  static DateTime? _dateTimeOrNull(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.parse(value);
  }

  ClothingItem copyWith({
    int? id,
    String? name,
    String? imagePath,
    String? brand,
    String? category,
    int? brandId,
    int? categoryId,
    List<String>? seasonTags,
    String? color,
    String? material,
    String? size,
    double? clothingLength,
    double? shoulderWidth,
    double? chestCircumference,
    double? sleeveLength,
    double? waistCircumference,
    double? hipCircumference,
    double? trouserLength,
    double? purchasePrice,
    DateTime? purchaseDate,
    String? notes,
    bool? isDeleted,
    int? wearCount,
    double? minWornTemperature,
    double? maxWornTemperature,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClothingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      brandId: brandId ?? this.brandId,
      categoryId: categoryId ?? this.categoryId,
      seasonTags: seasonTags ?? this.seasonTags,
      color: color ?? this.color,
      material: material ?? this.material,
      size: size ?? this.size,
      clothingLength: clothingLength ?? this.clothingLength,
      shoulderWidth: shoulderWidth ?? this.shoulderWidth,
      chestCircumference: chestCircumference ?? this.chestCircumference,
      sleeveLength: sleeveLength ?? this.sleeveLength,
      waistCircumference: waistCircumference ?? this.waistCircumference,
      hipCircumference: hipCircumference ?? this.hipCircumference,
      trouserLength: trouserLength ?? this.trouserLength,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      notes: notes ?? this.notes,
      isDeleted: isDeleted ?? this.isDeleted,
      wearCount: wearCount ?? this.wearCount,
      minWornTemperature: minWornTemperature ?? this.minWornTemperature,
      maxWornTemperature: maxWornTemperature ?? this.maxWornTemperature,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
