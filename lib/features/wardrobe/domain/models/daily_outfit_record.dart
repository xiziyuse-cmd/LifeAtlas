class DailyOutfitRecord {
  const DailyOutfitRecord({
    this.id,
    required this.date,
    this.clothingItemIds = const [],
    required this.recordedAt,
    this.weatherType,
    this.minTemperature,
    this.maxTemperature,
  });

  final int? id;
  final DateTime date;
  final List<int> clothingItemIds;
  final DateTime recordedAt;
  final String? weatherType;
  final double? minTemperature;
  final double? maxTemperature;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'record_date': date.toIso8601String(),
      'recorded_at': recordedAt.toIso8601String(),
      'weather_type': weatherType,
      'min_temperature': minTemperature,
      'max_temperature': maxTemperature,
    };
  }

  factory DailyOutfitRecord.fromMap(
    Map<String, Object?> map, {
    List<int> clothingItemIds = const [],
  }) {
    return DailyOutfitRecord(
      id: map['id'] as int?,
      date: DateTime.parse(map['record_date'] as String),
      clothingItemIds: clothingItemIds,
      recordedAt: DateTime.parse(map['recorded_at'] as String),
      weatherType: map['weather_type'] as String?,
      minTemperature: (map['min_temperature'] as num?)?.toDouble(),
      maxTemperature: (map['max_temperature'] as num?)?.toDouble(),
    );
  }
}
