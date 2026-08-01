enum HomeDayMarker { weather, outfit, text, image }

class HomeDayData {
  const HomeDayData({
    required this.date,
    this.hasWeatherRecord = false,
    this.weatherType,
    this.currentTemperature,
    this.minTemperature,
    this.maxTemperature,
    this.hasOutfitRecord = false,
    this.textEntries = const [],
    this.imagePaths = const [],
  });

  factory HomeDayData.empty(DateTime date) {
    return HomeDayData(date: DateTime(date.year, date.month, date.day));
  }

  final DateTime date;
  final bool hasWeatherRecord;
  final String? weatherType;
  final double? currentTemperature;
  final double? minTemperature;
  final double? maxTemperature;
  final bool hasOutfitRecord;
  final List<String> textEntries;
  final List<String> imagePaths;

  Set<HomeDayMarker> get markers {
    return {
      if (hasWeatherRecord) HomeDayMarker.weather,
      if (hasOutfitRecord) HomeDayMarker.outfit,
      if (textEntries.isNotEmpty) HomeDayMarker.text,
      if (imagePaths.isNotEmpty) HomeDayMarker.image,
    };
  }

  bool get hasAnyRecord => markers.isNotEmpty;

  HomeDayData copyWith({
    bool? hasWeatherRecord,
    String? weatherType,
    double? currentTemperature,
    double? minTemperature,
    double? maxTemperature,
    bool? hasOutfitRecord,
    List<String>? textEntries,
    List<String>? imagePaths,
  }) {
    return HomeDayData(
      date: date,
      hasWeatherRecord: hasWeatherRecord ?? this.hasWeatherRecord,
      weatherType: weatherType ?? this.weatherType,
      currentTemperature: currentTemperature ?? this.currentTemperature,
      minTemperature: minTemperature ?? this.minTemperature,
      maxTemperature: maxTemperature ?? this.maxTemperature,
      hasOutfitRecord: hasOutfitRecord ?? this.hasOutfitRecord,
      textEntries: textEntries ?? this.textEntries,
      imagePaths: imagePaths ?? this.imagePaths,
    );
  }
}
