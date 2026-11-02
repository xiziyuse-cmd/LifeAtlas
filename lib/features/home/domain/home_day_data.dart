enum HomeDayMarker { weather, outfit, text, image }

class HomeOutfitItem {
  const HomeOutfitItem({
    required this.id,
    required this.name,
    required this.imagePath,
  });

  final int id;
  final String name;
  final String imagePath;
}

class HomeDayData {
  const HomeDayData({
    required this.date,
    this.hasWeatherRecord = false,
    this.weatherType,
    this.currentTemperature,
    this.minTemperature,
    this.maxTemperature,
    this.hasOutfitRecord = false,
    this.outfitItems = const [],
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
  final List<HomeOutfitItem> outfitItems;
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
    List<HomeOutfitItem>? outfitItems,
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
      outfitItems: outfitItems ?? this.outfitItems,
      textEntries: textEntries ?? this.textEntries,
      imagePaths: imagePaths ?? this.imagePaths,
    );
  }
}
