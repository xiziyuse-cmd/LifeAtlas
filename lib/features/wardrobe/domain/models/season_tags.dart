import 'dart:convert';

class WardrobeSeasonTags {
  const WardrobeSeasonTags._();

  static const supported = <String>['春', '夏', '秋', '冬'];

  static List<String> normalize(Iterable<String> values, {int maxCount = 3}) {
    final result = <String>[];
    for (final rawValue in values) {
      final value = rawValue.trim();
      if (!supported.contains(value)) {
        throw ArgumentError.value(rawValue, 'values', '不支持的季节标签');
      }
      if (!result.contains(value)) {
        result.add(value);
      }
    }
    if (result.length > maxCount) {
      throw ArgumentError('季节标签最多只能选择 $maxCount 个。');
    }
    return List.unmodifiable(result);
  }

  static List<String> decodeStorage(Object? encoded, {int maxCount = 3}) {
    if (encoded is! String || encoded.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) {
        return const [];
      }
      final result = <String>[];
      for (final value in decoded.whereType<String>()) {
        final normalized = value.trim();
        if (supported.contains(normalized) && !result.contains(normalized)) {
          result.add(normalized);
          if (result.length == maxCount) {
            break;
          }
        }
      }
      return List.unmodifiable(result);
    } on FormatException {
      return const [];
    }
  }
}
