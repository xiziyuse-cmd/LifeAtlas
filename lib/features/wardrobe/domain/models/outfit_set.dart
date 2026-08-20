import 'dart:convert';

import 'season_tags.dart';

class OutfitSet {
  OutfitSet({
    this.id,
    required this.name,
    List<String> seasonTags = const [],
    List<int> clothingItemIds = const [],
    required this.createdAt,
    required this.updatedAt,
  }) : seasonTags = WardrobeSeasonTags.normalize(seasonTags, maxCount: 4),
       clothingItemIds = List.unmodifiable(clothingItemIds.toSet());

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
    return OutfitSet(
      id: map['id'] as int?,
      name: map['name'] as String,
      seasonTags: WardrobeSeasonTags.decodeStorage(
        map['season_tags'],
        maxCount: 4,
      ),
      clothingItemIds: clothingItemIds,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  OutfitSet copyWith({
    int? id,
    String? name,
    List<String>? seasonTags,
    List<int>? clothingItemIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OutfitSet(
      id: id ?? this.id,
      name: name ?? this.name,
      seasonTags: seasonTags ?? this.seasonTags,
      clothingItemIds: clothingItemIds ?? this.clothingItemIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
