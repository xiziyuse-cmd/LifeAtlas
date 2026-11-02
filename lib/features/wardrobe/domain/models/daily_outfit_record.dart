import '../../../../core/database/date_key_codec.dart';

class DailyOutfitRecord {
  const DailyOutfitRecord({
    this.id,
    required this.date,
    this.clothingItemIds = const [],
    required this.recordedAt,
    this.updatedAt,
    this.weatherType,
    this.minTemperature,
    this.maxTemperature,
    this.temperatureAppliedAt,
  });

  final int? id;
  final DateTime date;
  final List<int> clothingItemIds;
  final DateTime recordedAt;
  final DateTime? updatedAt;
  final String? weatherType;
  final double? minTemperature;
  final double? maxTemperature;
  final DateTime? temperatureAppliedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'record_date': DateKeyCodec.encode(date),
      'recorded_at': recordedAt.toIso8601String(),
      'updated_at': (updatedAt ?? recordedAt).toIso8601String(),
      'weather_type': weatherType,
      'min_temperature': minTemperature,
      'max_temperature': maxTemperature,
      'temperature_applied_at': temperatureAppliedAt?.toIso8601String(),
    };
  }

  factory DailyOutfitRecord.fromMap(
    Map<String, Object?> map, {
    List<int> clothingItemIds = const [],
  }) {
    return DailyOutfitRecord(
      id: map['id'] as int?,
      date: DateKeyCodec.decode(map['record_date'] as String),
      clothingItemIds: clothingItemIds,
      recordedAt: DateTime.parse(map['recorded_at'] as String),
      updatedAt: _dateTimeOrNull(map['updated_at']),
      weatherType: map['weather_type'] as String?,
      minTemperature: (map['min_temperature'] as num?)?.toDouble(),
      maxTemperature: (map['max_temperature'] as num?)?.toDouble(),
      temperatureAppliedAt: _dateTimeOrNull(map['temperature_applied_at']),
    );
  }

  static DateTime? _dateTimeOrNull(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.parse(value);
  }

  DailyOutfitRecord copyWith({
    int? id,
    DateTime? date,
    List<int>? clothingItemIds,
    DateTime? recordedAt,
    DateTime? updatedAt,
    String? weatherType,
    double? minTemperature,
    double? maxTemperature,
    DateTime? temperatureAppliedAt,
  }) {
    return DailyOutfitRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      clothingItemIds: clothingItemIds ?? this.clothingItemIds,
      recordedAt: recordedAt ?? this.recordedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      weatherType: weatherType ?? this.weatherType,
      minTemperature: minTemperature ?? this.minTemperature,
      maxTemperature: maxTemperature ?? this.maxTemperature,
      temperatureAppliedAt: temperatureAppliedAt ?? this.temperatureAppliedAt,
    );
  }
}
