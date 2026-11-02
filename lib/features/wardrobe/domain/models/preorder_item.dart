class PreorderItem {
  const PreorderItem({
    this.id,
    this.name,
    required this.imagePath,
    this.brand,
    this.category,
    this.brandId,
    this.categoryId,
    this.price,
    this.material,
    this.size,
    this.clothingLength,
    this.shoulderWidth,
    this.chestCircumference,
    this.sleeveLength,
    this.waistCircumference,
    this.hipCircumference,
    this.trouserLength,
    this.productUrl,
    this.description,
    this.notes,
    this.isPurchased = false,
    this.purchasedAt,
    this.clothingItemId,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String? name;
  final String imagePath;
  final String? brand;
  final String? category;
  final int? brandId;
  final int? categoryId;
  final double? price;
  final String? material;
  final String? size;
  final double? clothingLength;
  final double? shoulderWidth;
  final double? chestCircumference;
  final double? sleeveLength;
  final double? waistCircumference;
  final double? hipCircumference;
  final double? trouserLength;
  final String? productUrl;
  final String? description;
  final String? notes;
  final bool isPurchased;
  final DateTime? purchasedAt;
  final int? clothingItemId;
  final bool isDeleted;
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
      'price': price,
      'material': material,
      'size': size,
      'clothing_length': clothingLength,
      'shoulder_width': shoulderWidth,
      'chest_circumference': chestCircumference,
      'sleeve_length': sleeveLength,
      'waist_circumference': waistCircumference,
      'hip_circumference': hipCircumference,
      'trouser_length': trouserLength,
      'product_url': productUrl,
      'description': description,
      'notes': notes,
      'is_purchased': isPurchased ? 1 : 0,
      'purchased_at': purchasedAt?.toIso8601String(),
      'clothing_item_id': clothingItemId,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PreorderItem.fromMap(Map<String, Object?> map) {
    return PreorderItem(
      id: map['id'] as int?,
      name: map['name'] as String?,
      imagePath: map['image_path'] as String,
      brand: map['brand'] as String?,
      category: map['category'] as String?,
      brandId: map['brand_id'] as int?,
      categoryId: map['category_id'] as int?,
      price: (map['price'] as num?)?.toDouble(),
      material: map['material'] as String?,
      size: map['size'] as String?,
      clothingLength: (map['clothing_length'] as num?)?.toDouble(),
      shoulderWidth: (map['shoulder_width'] as num?)?.toDouble(),
      chestCircumference: (map['chest_circumference'] as num?)?.toDouble(),
      sleeveLength: (map['sleeve_length'] as num?)?.toDouble(),
      waistCircumference: (map['waist_circumference'] as num?)?.toDouble(),
      hipCircumference: (map['hip_circumference'] as num?)?.toDouble(),
      trouserLength: (map['trouser_length'] as num?)?.toDouble(),
      productUrl: map['product_url'] as String?,
      description: map['description'] as String?,
      notes: map['notes'] as String?,
      isPurchased: map['is_purchased'] == 1,
      purchasedAt: _dateTimeOrNull(map['purchased_at']),
      clothingItemId: map['clothing_item_id'] as int?,
      isDeleted: map['is_deleted'] == 1,
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

  PreorderItem copyWith({
    int? id,
    String? name,
    String? imagePath,
    String? brand,
    String? category,
    int? brandId,
    int? categoryId,
    double? price,
    String? material,
    String? size,
    double? clothingLength,
    double? shoulderWidth,
    double? chestCircumference,
    double? sleeveLength,
    double? waistCircumference,
    double? hipCircumference,
    double? trouserLength,
    String? productUrl,
    String? description,
    String? notes,
    bool? isPurchased,
    DateTime? purchasedAt,
    int? clothingItemId,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PreorderItem(
      id: id ?? this.id,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      brandId: brandId ?? this.brandId,
      categoryId: categoryId ?? this.categoryId,
      price: price ?? this.price,
      material: material ?? this.material,
      size: size ?? this.size,
      clothingLength: clothingLength ?? this.clothingLength,
      shoulderWidth: shoulderWidth ?? this.shoulderWidth,
      chestCircumference: chestCircumference ?? this.chestCircumference,
      sleeveLength: sleeveLength ?? this.sleeveLength,
      waistCircumference: waistCircumference ?? this.waistCircumference,
      hipCircumference: hipCircumference ?? this.hipCircumference,
      trouserLength: trouserLength ?? this.trouserLength,
      productUrl: productUrl ?? this.productUrl,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      isPurchased: isPurchased ?? this.isPurchased,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      clothingItemId: clothingItemId ?? this.clothingItemId,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
