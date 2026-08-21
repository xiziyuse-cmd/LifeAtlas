enum ClothingMeasurementField {
  clothingLength,
  shoulderWidth,
  chestCircumference,
  sleeveLength,
  waistCircumference,
  hipCircumference,
  trouserLength,
}

class ClothingParameterProfile {
  const ClothingParameterProfile._(this.fields);

  static const all = ClothingParameterProfile._({
    ClothingMeasurementField.clothingLength,
    ClothingMeasurementField.shoulderWidth,
    ClothingMeasurementField.chestCircumference,
    ClothingMeasurementField.sleeveLength,
    ClothingMeasurementField.waistCircumference,
    ClothingMeasurementField.hipCircumference,
    ClothingMeasurementField.trouserLength,
  });

  static const upperBody = ClothingParameterProfile._({
    ClothingMeasurementField.clothingLength,
    ClothingMeasurementField.shoulderWidth,
    ClothingMeasurementField.chestCircumference,
    ClothingMeasurementField.sleeveLength,
  });

  static const trousers = ClothingParameterProfile._({
    ClothingMeasurementField.waistCircumference,
    ClothingMeasurementField.hipCircumference,
    ClothingMeasurementField.trouserLength,
  });

  static const skirts = ClothingParameterProfile._({
    ClothingMeasurementField.clothingLength,
    ClothingMeasurementField.waistCircumference,
    ClothingMeasurementField.hipCircumference,
  });

  static const noMeasurements = ClothingParameterProfile._({});

  final Set<ClothingMeasurementField> fields;

  bool includes(ClothingMeasurementField field) => fields.contains(field);

  static ClothingParameterProfile forCategory(String? category) {
    final normalized = category?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) {
      return all;
    }
    if (_matches(normalized, const ['外套', '内搭', '上衣'])) {
      return upperBody;
    }
    if (_matches(normalized, const ['长裤', '短裤'])) {
      return trousers;
    }
    if (_matches(normalized, const ['裙装'])) {
      return skirts;
    }
    if (_matches(normalized, const ['鞋', '包', '饰品'])) {
      return noMeasurements;
    }
    return all;
  }

  static bool _matches(String category, List<String> names) {
    return names.any((name) => category == name.toLowerCase());
  }
}
