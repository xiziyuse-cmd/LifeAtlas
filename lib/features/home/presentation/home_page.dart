import 'dart:async';
import 'package:flutter/material.dart';

import '../data/weather_service.dart';
import '../../../core/database/date_key_codec.dart';
import '../data/home_repository.dart';
import '../domain/home_day_data.dart';
import '../domain/weather_model.dart';
import '../../wardrobe/data/wardrobe_repository.dart';
import '../../wardrobe/domain/models/clothing_recommendation.dart';
import '../../wardrobe/presentation/widgets/local_clothing_image.dart';
import 'widgets/home_calendar_panel.dart';
import 'widgets/home_weather_card.dart';
import 'weather_detail_page.dart';
import 'widgets/quick_record_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.homeRepository,
    this.wardrobeRepository,
    this.onSearch,
    this.onReturnToHome,
    this.dataRevision = 0,
  });

  final HomeRepository? homeRepository;
  final WardrobeRepository? wardrobeRepository;
  final VoidCallback? onSearch;
  final VoidCallback? onReturnToHome;
  final int dataRevision;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final QWeatherService _weatherService = QWeatherService();
  String? _weatherError;

  late DateTime _focusedMonth;
  late DateTime _selectedDate;
  WeatherModel? _weather;
  Map<DateTime, HomeDayData> _days = const {};
  List<ClothingRecommendation> _recommendations = const [];
  bool _isWeatherLoading = true;
  bool _weatherBusy = false;
  int _weatherRevision = 0;
  Timer? _weatherTimer;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    _focusedMonth = DateTime(today.year, today.month);
    _selectedDate = today;
    _days = widget.homeRepository == null
        ? _mockDaysForMonth(_focusedMonth)
        : const {};
    _loadMonth();
    _loadWeather();
    WidgetsBinding.instance.addObserver(this);
    _weatherTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _loadWeather(),
    );
  }

  @override
  void dispose() {
    _weatherTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadWeather();
    }
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataRevision != widget.dataRevision) {
      _loadMonth();
      _loadRecommendations();
    }
  }

  Future<void> _loadMonth() async {
    final repository = widget.homeRepository;
    if (repository == null) {
      return;
    }
    try {
      final days = await repository.loadMonth(_focusedMonth);
      if (!mounted) {
        return;
      }
      setState(() => _days = days);
    } on Object {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('日历记录加载失败，请稍后重试')));
    }
  }

  Future<void> _loadWeather() async {
    if (_weatherBusy) return;
    _weatherBusy = true;
    final revision = _weatherRevision;
    try {
      final weather = await _weatherService.getCurrentWeather();
      if (!mounted || revision != _weatherRevision) {
        return;
      }
      setState(() {
        _weather = weather;
        _isWeatherLoading = false;
        _weatherError = null;
      });
      await _loadRecommendations();
      await _loadMonth();
    } on Object catch (error) {
      if (!mounted || revision != _weatherRevision) {
        return;
      }
      setState(() {
        _weather = null;
        _isWeatherLoading = false;
        _weatherError = error.toString().replaceFirst('Bad state: ', '');
      });
    } finally {
      _weatherBusy = false;
      if (mounted && revision != _weatherRevision) {
        unawaited(_loadWeather());
      }
    }
  }

  Future<void> _loadRecommendations() async {
    final repository = widget.wardrobeRepository;
    if (repository == null ||
        _weather == null ||
        _weather!.date != DateKeyCodec.encode(DateTime.now())) {
      return;
    }
    try {
      final recommendations = await repository.recommendForTemperature(
        minTemperature: _weather!.minTemperature,
        maxTemperature: _weather!.maxTemperature,
        limit: 4,
      );
      if (!mounted) {
        return;
      }
      setState(() => _recommendations = recommendations);
    } on Object {
      if (mounted) {
        setState(() => _recommendations = const []);
      }
    }
  }

  void _changeMonth(int offset) {
    final nextMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + offset,
    );
    setState(() {
      _focusedMonth = nextMonth;
      _selectedDate = DateTime(nextMonth.year, nextMonth.month);
      if (widget.homeRepository == null) {
        _days = _mockDaysForMonth(nextMonth);
      }
    });
    _loadMonth();
  }

  void _returnToToday() {
    final today = _dateOnly(DateTime.now());
    setState(() {
      _focusedMonth = DateTime(today.year, today.month);
      _selectedDate = today;
      if (widget.homeRepository == null) {
        _days = _mockDaysForMonth(_focusedMonth);
      }
    });
    _loadMonth();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const PageStorageKey('home-content'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          InkWell(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WeatherDetailPage(service: _weatherService),
                ),
              );
              if (mounted) {
                widget.onReturnToHome?.call();
                _weatherRevision++;
                setState(() {
                  _weather = null;
                  _weatherError = null;
                  _isWeatherLoading = true;
                });
                await _loadWeather();
              }
            },
            child: _weather == null
                ? Container(
                    key: const ValueKey('home-weather-bar'),
                    constraints: const BoxConstraints(minHeight: 72),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _isWeatherLoading
                                ? '正在获取天气…'
                                : (_weatherError ?? '点击选择城市并获取真实天气'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  )
                : HomeWeatherCard(
                    weather: _weather!,
                    isLoading: _isWeatherLoading,
                    recommendationNames: _recommendations
                        .map((r) => r.item.name)
                        .toList(),
                  ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: HomeCalendarPanel(
              month: _focusedMonth,
              selectedDate: _selectedDate,
              days: _days,
              onPreviousMonth: () => _changeMonth(-1),
              onNextMonth: () => _changeMonth(1),
              onToday: _returnToToday,
              onDateSelected: (date) {
                setState(() => _selectedDate = date);
                final selectedData =
                    _days[_dateOnly(date)] ?? HomeDayData.empty(date);
                if (selectedData.outfitItems.isNotEmpty) {
                  _showDailyOutfit(selectedData);
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          QuickRecordBar(onSearch: widget.onSearch ?? () {}),
        ],
      ),
    );
  }

  Future<void> _showDailyOutfit(HomeDayData data) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data.date.month}月${data.date.day}日穿搭',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                for (final item in data.outfitItems)
                  ListTile(
                    key: ValueKey('home-selected-outfit-${item.id}'),
                    contentPadding: EdgeInsets.zero,
                    leading: LocalClothingImage(
                      imagePath: item.imagePath,
                      width: 48,
                      height: 48,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    title: Text(item.name),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (mounted) widget.onReturnToHome?.call();
  }

  static Map<DateTime, HomeDayData> _mockDaysForMonth(DateTime month) {
    final days = <DateTime, HomeDayData>{
      DateTime(month.year, month.month, 5): HomeDayData(
        date: DateTime(month.year, month.month, 5),
        hasWeatherRecord: true,
        weatherType: '多云',
        currentTemperature: 26,
        minTemperature: 22,
        maxTemperature: 30,
      ),
      DateTime(month.year, month.month, 12): HomeDayData(
        date: DateTime(month.year, month.month, 12),
        hasOutfitRecord: true,
      ),
      DateTime(month.year, month.month, 18): HomeDayData(
        date: DateTime(month.year, month.month, 18),
        textEntries: const ['整理今日生活记录'],
      ),
    };

    final today = DateTime.now();
    if (today.year == month.year && today.month == month.month) {
      final date = _dateOnly(today);
      days[date] = HomeDayData(
        date: date,
        hasWeatherRecord: true,
        hasOutfitRecord: true,
        weatherType: '多云',
        currentTemperature: 26,
        minTemperature: 22,
        maxTemperature: 30,
        textEntries: const ['今天的模拟 AI 记录'],
      );
    }

    return days;
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
