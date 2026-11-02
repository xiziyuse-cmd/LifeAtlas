import 'package:flutter/material.dart';
import '../data/weather_service.dart';
import '../domain/weather_model.dart';
import '../domain/hourly_weather.dart';
import 'widgets/weather_attribution.dart';

class WeatherDetailPage extends StatefulWidget {
  const WeatherDetailPage({super.key, this.service});
  final QWeatherService? service;
  @override
  State<WeatherDetailPage> createState() => _WeatherDetailPageState();
}

class _WeatherDetailPageState extends State<WeatherDetailPage> {
  late final service = widget.service ?? QWeatherService();
  final query = TextEditingController();
  List<Map<String, dynamic>> cities = [];
  WeatherModel? weather;
  HourlyForecast? hourly;
  String? hourlyError;
  bool hourlyLoading = false;
  int revision = 0;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    revision++;
    query.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _fetch({bool forceRefresh = false}) async {
    final request = ++revision;
    setState(() {
      hourlyLoading = true;
      hourlyError = null;
    });
    // Each panel succeeds or fails independently, with one busy state for city changes.
    await Future.wait([
      (() async {
        try {
          final value = await service.getCurrentWeather(
            forceRefresh: forceRefresh,
          );
          if (mounted && request == revision) {
            setState(() {
              weather = value;
              error = null;
            });
          }
        } catch (e) {
          if (mounted && request == revision) {
            setState(
              () => error = e.toString().replaceFirst('Bad state: ', ''),
            );
          }
        }
      })(),
      (() async {
        try {
          final value = await service.getHourlyWeather(
            forceRefresh: forceRefresh,
          );
          if (mounted && request == revision) setState(() => hourly = value);
        } catch (e) {
          if (mounted && request == revision) {
            setState(() {
              hourly = null;
              hourlyError = e.toString().replaceFirst('Bad state: ', '');
            });
          }
        } finally {
          if (mounted && request == revision) {
            setState(() => hourlyLoading = false);
          }
        }
      })(),
    ]);
  }

  Future<void> _load({bool forceRefresh = false}) =>
      _run(() => _fetch(forceRefresh: forceRefresh));
  Future<void> _choose(Map<String, dynamic> city) => _run(() async {
    await service.selectCity(city);
    if (!mounted) return;
    setState(() {
      weather = null;
      hourly = null;
      error = null;
      cities = [];
    });
    await _fetch();
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('天气与城市')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: query,
          decoration: const InputDecoration(
            labelText: '城市名称',
            hintText: '如：成都、上海',
          ),
          onSubmitted: (_) => _run(() async {
            final list = await service.searchCities(query.text);
            if (mounted) setState(() => cities = list);
          }),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => _run(() async {
                      final list = await service.searchCities(query.text);
                      if (mounted) setState(() => cities = list);
                    }),
              icon: const Icon(Icons.search),
              label: const Text('搜索城市'),
            ),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => _run(() async {
                      final list = await service.locate();
                      if (mounted) setState(() => cities = list);
                    }),
              icon: const Icon(Icons.my_location),
              label: const Text('使用当前位置'),
            ),
          ],
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        for (final city in cities)
          ListTile(
            title: Text(city['name'] as String),
            subtitle: Text(city['region'] as String),
            trailing: const Icon(Icons.chevron_right),
            onTap: busy ? null : () => _choose(city),
          ),
        if (weather != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weather!.region,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${weather!.icon} ${weather!.status} ${weather!.currentTemperature.round()}℃',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    '当天预报 ${weather!.minTemperature.round()}℃ – ${weather!.maxTemperature.round()}℃',
                  ),
                  const SizedBox(height: 12),
                  if (weather!.cached) Text(weather!.warning),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${weather!.cached ? '缓存 · ' : ''}获取时间：${_fetchedTime(weather!.fetchedAt)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const WeatherAttribution(showLabel: true),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => _load(forceRefresh: true),
                        child: const Text('刷新天气'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (weather == null)
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: busy ? null : () => _load(forceRefresh: true),
              child: const Text('刷新天气'),
            ),
          ),
        const SizedBox(height: 16),
        Text('逐小时天气', style: Theme.of(context).textTheme.titleLarge),
        if (hourlyLoading) const LinearProgressIndicator(),
        if (hourlyError != null) Text('小时预报暂不可用：$hourlyError'),
        if (hourly != null) ...[
          Text(
            '城市时间 · ${hourly!.zone}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (hourly!.cached) Text('缓存预报 · ${hourly!.warning}'),
          for (var day = 0; day < 2; day++) _hourlyDay(context, day),
        ],
        if (weather == null) const WeatherAttribution(showLabel: true),
      ],
    ),
  );

  String _fetchedTime(String value) {
    final time = DateTime.tryParse(value)?.toLocal();
    return time == null ? '未知' : time.toString().substring(5, 16);
  }

  Widget _hourlyDay(BuildContext context, int day) {
    final entries = hourly!.day(day, service.clock());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(day == 0 ? '今天' : '明天'),
        ),
        if (entries.isEmpty) const Text('暂无该日小时预报'),
        SingleChildScrollView(
          key: ValueKey('hourly-day-$day'),
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in entries)
                SizedBox(
                  width: 92,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${hourly!.local(entry.time).hour.toString().padLeft(2, '0')}:00',
                        ),
                        Text(entry.icon, style: const TextStyle(fontSize: 28)),
                        Text(entry.status, textAlign: TextAlign.center),
                        Text('${entry.temperature.round()}℃'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
