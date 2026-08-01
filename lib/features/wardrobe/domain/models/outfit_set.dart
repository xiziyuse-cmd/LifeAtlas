import 'dart:convert';

class OutfitSet {
  const OutfitSet({
    this.id,
    required this.name,
    this.seasonTags = const [],
    this.clothingItemIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String name;
  final List<String> seasonTags;
  final List<int> clothingItemIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'season_tags': jsonEncode(seasonTags),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory OutfitSet.fromMap(
    Map<String, Object?> map, {
    List<int> clothingItemIds = const [],
  }) {
    final encodedSeasonTags = map['season_tags'] as String? ?? '[]';

    return OutfitSet(
      id: map['id'] as int?,
      name: map['name'] as String,
      seasonTags: List<String>.from(jsonDecode(encodedSeasonTags) as List),
      clothingItemIds: clothingItemIds,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
