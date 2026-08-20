class DateKeyCodec {
  const DateKeyCodec._();

  static final RegExp _datePrefix = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');

  static String encode(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  static DateTime decode(String value) {
    final match = _datePrefix.firstMatch(value.trim());
    if (match == null) {
      throw FormatException('Invalid date value: $value');
    }

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw FormatException('Invalid calendar date: $value');
    }
    return date;
  }

  static String normalizeStorageValue(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Missing date value');
    }
    return encode(decode(value));
  }
}
