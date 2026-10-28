class ClothingCategory {
  const ClothingCategory({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.createdAt,
  });

  final int id;
  final String name;
  final bool isDefault;
  final DateTime createdAt;

  factory ClothingCategory.fromMap(Map<String, Object?> map) {
    return ClothingCategory(
      id: map['id'] as int,
      name: map['name'] as String,
      isDefault: map['is_default'] == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class ClothingBrand {
  const ClothingBrand({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.createdAt,
  });

  final int id;
  final String name;
  final bool isDefault;
  final DateTime createdAt;

  factory ClothingBrand.fromMap(Map<String, Object?> map) {
    return ClothingBrand(
      id: map['id'] as int,
      name: map['name'] as String,
      isDefault: map['is_default'] == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
