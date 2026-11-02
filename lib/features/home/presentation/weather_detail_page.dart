import 'package:flutter/material.dart';
import '../data/weather_service.dart';
import '../domain/weather_model.dart';

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
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() work) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await work();
      if (mounted) setState(() => error = null);
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _load() => _run(() async {
    final value = await service.getCurrentWeather();
    if (mounted) setState(() => weather = value);
  });
  Future<void> _choose(Map<String, dynamic> city) => _run(() async {
    await service.selectCity(city);
    final value = await service.getCurrentWeather();
    if (mounted)
      setState(() {
        weather = value;
        cities = [];
      });
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
                  Text(
                    '${weather!.cached ? '缓存 · ' : ''}${weather!.date}\n获取时间：${DateTime.parse(weather!.fetchedAt).toLocal()}\n来源：和风天气',
                  ),
                  if (weather!.cached) Text(weather!.warning),
                  TextButton(
                    onPressed: busy ? null : _load,
                    child: const Text('刷新天气'),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        const Text('天气数据由和风天气提供。温度范围为当日预报；无有效数据时不会生成模拟天气。定位仅在点击按钮并授权后使用。'),
        const SelectableText('https://developer.qweather.com/attribution.html'),
      ],
    ),
  );
}
