import 'season_tags.dart';

class ClothingImageParameters {
  ClothingImageParameters({
    this.name,
    this.brand,
    this.category,
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
    Map<String, Object?> parameterValues = const {},
  }) : seasonTags = WardrobeSeasonTags.normalize(seasonTags),
       parameterValues = Map.unmodifiable(parameterValues);

  final String? name;
  final String? brand;
  final String? category;
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
  final Map<String, Object?> parameterValues;

  factory ClothingImageParameters.fromJson(Map<String, Object?> json) {
    final measurements = _objectMap(json['measurements']);
    final parameters = _objectMap(json['parameters']);
    Object? value(String key) => measurements[key] ?? json[key];

    return ClothingImageParameters(
      name: _string(json['name']),
      brand: _string(json['brand']),
      category: _string(json['category']),
      seasonTags: _stringList(json['seasonTags'] ?? json['season_tags']),
      color: _string(json['color']),
      material: _string(json['material']),
      size: _string(json['size']),
      clothingLength: _number(
        value('clothingLength') ?? value('clothing_length'),
      ),
      shoulderWidth: _number(value('shoulderWidth') ?? value('shoulder_width')),
      chestCircumference: _number(
        value('chestCircumference') ?? value('chest_circumference'),
      ),
      sleeveLength: _number(value('sleeveLength') ?? value('sleeve_length')),
      waistCircumference: _number(
        value('waistCircumference') ?? value('waist_circumference'),
      ),
      hipCircumference: _number(
        value('hipCircumference') ?? value('hip_circumference'),
      ),
      trouserLength: _number(value('trouserLength') ?? value('trouser_length')),
      parameterValues: {
        for (final entry in parameters.entries)
          entry.key: ?_parameterValue(entry.value),
      },
    );
  }

  static Map<String, Object?> _objectMap(Object? value) {
    if (value is! Map) {
      return const {};
    }
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  static String? _string(Object? value) {
    if (value is! String) {
      return null;
    }
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return [for (final item in value) ?_string(item)];
  }

  static double? _number(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  static Object? _parameterValue(Object? value) {
    final number = _number(value);
    if (number != null) {
      return number;
    }
    return _string(value);
  }
}
