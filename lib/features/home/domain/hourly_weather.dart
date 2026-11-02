import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class HourlyWeather {
  HourlyWeather(this.time, this.icon, this.status, this.temperature);
  final DateTime time;
  final String icon, status;
  final double temperature;
}

class HourlyForecast {
  HourlyForecast._(
    this.cityId,
    this.zone,
    this.fetchedAt,
    this.hours,
    this.cached,
    this.warning,
  );
  final String cityId, zone, warning;
  final DateTime fetchedAt;
  final List<HourlyWeather> hours;
  final bool cached;
  static bool _initialized = false;

  static tz.Location location(String zone) {
    if (!_initialized) {
      tzdata.initializeTimeZones();
      _initialized = true;
    }
    return tz.getLocation(zone);
  }

  factory HourlyForecast.fromJson(
    Map<String, dynamic> data, {
    bool cached = false,
    String warning = '',
  }) {
    final zone = data['tz'] as String;
    location(zone); // Never silently group by the device timezone.
    final fetched = DateTime.parse(data['fetchedAt'] as String);
    final hours = (data['hours'] as List).map((raw) {
      final value = Map<String, dynamic>.from(raw as Map);
      final timeText = value['time'] as String;
      final temp = (value['temperature'] as num).toDouble();
      if (!RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(timeText) ||
          !temp.isFinite ||
          temp < -100 ||
          temp > 70 ||
          (value['status'] as String).isEmpty ||
          (value['icon'] as String).isEmpty) {
        throw const FormatException('小时天气数据无效');
      }
      return HourlyWeather(
        DateTime.parse(timeText),
        value['icon'] as String,
        value['status'] as String,
        temp,
      );
    }).toList()..sort((a, b) => a.time.compareTo(b.time));
    if (hours.isEmpty ||
        hours.map((h) => h.time).toSet().length != hours.length) {
      throw const FormatException('暂无有效小时预报');
    }
    return HourlyForecast._(
      data['cityId'] as String,
      zone,
      fetched,
      List.unmodifiable(hours),
      cached,
      warning,
    );
  }

  DateTime local(DateTime time) => tz.TZDateTime.from(time, location(zone));

  List<HourlyWeather> day(int offset, DateTime now) {
    final today = local(now);
    final date = DateTime.utc(today.year, today.month, today.day + offset);
    return hours.where((h) {
      final t = local(h.time);
      return h.time.add(const Duration(hours: 1)).isAfter(now) &&
          t.year == date.year &&
          t.month == date.month &&
          t.day == date.day;
    }).toList();
  }

  bool usable(DateTime now) => day(0, now).isNotEmpty || day(1, now).isNotEmpty;
  bool fresh(DateTime now) {
    final age = now.difference(fetchedAt);
    return !age.isNegative && age < const Duration(minutes: 15) && usable(now);
  }
}
