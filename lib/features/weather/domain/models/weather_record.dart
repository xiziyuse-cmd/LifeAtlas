class WeatherRecord {
  const WeatherRecord({
    this.id,
    required this.date,
    required this.region,
    required this.weatherType,
    this.currentTemperature,
    required this.minTemperature,
    required this.maxTemperature,
    required this.recordedAt,
    this.dataSource,
  });

  final int? id;
  final DateTime date;
  final String region;
  final String weatherType;
  final double? currentTemperature;
  final double minTemperature;
  final double maxTemperature;
  final DateTime recordedAt;
  final String? dataSource;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'record_date': date.toIso8601String(),
      'region': region,
      'weather_type': weatherType,
      'current_temperature': currentTemperature,
      'min_temperature': minTemperature,
      'max_temperature': maxTemperature,
      'recorded_at': recordedAt.toIso8601String(),
      'data_source': dataSource,
    };
  }

  factory WeatherRecord.fromMap(Map<String, Object?> map) {
    return WeatherRecord(
      id: map['id'] as int?,
      date: DateTime.parse(map['record_date'] as String),
      region: map['region'] as String,
      weatherType: map['weather_type'] as String,
      currentTemperature: (map['current_temperature'] as num?)?.toDouble(),
      minTemperature: (map['min_temperature'] as num).toDouble(),
      maxTemperature: (map['max_temperature'] as num).toDouble(),
      recordedAt: DateTime.parse(map['recorded_at'] as String),
      dataSource: map['data_source'] as String?,
    );
  }
}
