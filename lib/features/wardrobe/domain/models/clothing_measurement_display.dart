import 'clothing_item.dart';

String? clothingCircumferenceDisplay(ClothingItem item, String base) {
  final hasRange =
      item.parameterValues.containsKey('${base}_min') ||
      item.parameterValues.containsKey('${base}_max');
  final legacy =
      item.parameterValues[base]?.numberValue ??
      switch (base) {
        'waist_circumference' => item.waistCircumference,
        'hip_circumference' => item.hipCircumference,
        _ => null,
      };
  return measurementRangeDisplay(
    hasRange ? item.parameterValues['${base}_min']?.numberValue : legacy,
    hasRange ? item.parameterValues['${base}_max']?.numberValue : legacy,
  );
}

/// Presentation only: a missing boundary remains missing in stored data.
String? measurementRangeDisplay(double? minimum, double? maximum) {
  if (minimum == null && maximum == null) return null;
  String number(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
  if (minimum == null || maximum == null || minimum == maximum) {
    return '${number(minimum ?? maximum!)} cm';
  }
  return '${number(minimum)} – ${number(maximum)} cm';
}
