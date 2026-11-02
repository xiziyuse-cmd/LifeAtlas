class WeatherModel {
  const WeatherModel({
    required this.icon,
    required this.status,
    required this.currentTemperature,
    required this.minTemperature,
    required this.maxTemperature,
    this.isSimulated = false,
    this.region = '',
    this.date = '',
    this.fetchedAt = '',
    this.source = '',
    this.cached = false,
    this.warning = '',
  });
  final String icon, status, region, date, fetchedAt, source, warning;
  final double currentTemperature, minTemperature, maxTemperature;
  final bool isSimulated, cached;
  factory WeatherModel.fromJson(
    Map<String, dynamic> value, {
    bool cached = false,
    String warning = '',
  }) {
    final numbers = [
      'currentTemperature',
      'minTemperature',
      'maxTemperature',
    ].map((k) => (value[k] as num).toDouble()).toList();
    if (numbers.any((n) => !n.isFinite || n < -100 || n > 70) ||
        numbers[1] > numbers[2] ||
        value['isSimulated'] != false ||
        DateTime.tryParse(value['fetchedAt'] as String? ?? '') == null) {
      throw const FormatException('天气数据无效');
    }
    return WeatherModel(
      icon: value['icon'] as String,
      status: value['status'] as String,
      currentTemperature: numbers[0],
      minTemperature: numbers[1],
      maxTemperature: numbers[2],
      region: value['region'] as String,
      date: value['date'] as String,
      fetchedAt: value['fetchedAt'] as String,
      source: value['source'] as String,
      cached: cached,
      warning: warning,
    );
  }
}
