import 'package:flutter/material.dart';

import '../data/weather_service.dart';
import '../domain/home_day_data.dart';
import '../domain/weather_model.dart';
import 'widgets/home_calendar_panel.dart';
import 'widgets/home_weather_card.dart';
import 'widgets/quick_record_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final WeatherService _weatherService = const MockWeatherService();

  late DateTime _focusedMonth;
  late DateTime _selectedDate;
  WeatherModel _weather = const WeatherModel(
    icon: '☁️',
    status: '多云',
    currentTemperature: 26,
    minTemperature: 22,
    maxTemperature: 30,
    isSimulated: true,
  );
  Map<DateTime, HomeDayData> _days = const {};
  bool _isWeatherLoading = true;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    _focusedMonth = DateTime(today.year, today.month);
    _selectedDate = today;
    _days = _mockDaysForMonth(_focusedMonth);
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    try {
      final weather = await _weatherService.getCurrentWeather();
      if (!mounted) {
        return;
      }
      setState(() {
        _weather = weather;
        _isWeatherLoading = false;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() => _isWeatherLoading = false);
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
      _days = _mockDaysForMonth(nextMonth);
    });
  }

  void _returnToToday() {
    final today = _dateOnly(DateTime.now());
    setState(() {
      _focusedMonth = DateTime(today.year, today.month);
      _selectedDate = today;
      _days = _mockDaysForMonth(_focusedMonth);
    });
  }

  void _showImagePlaceholder() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('图片上传接口已预留，当前版本仅展示 UI')));
  }

  Future<bool> _showAiPlaceholder(String _) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('AI 接口暂未接入，当前版本仅展示输入 UI')));
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const PageStorageKey('home-content'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          HomeWeatherCard(weather: _weather, isLoading: _isWeatherLoading),
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
              },
            ),
          ),
          const SizedBox(height: 8),
          QuickRecordBar(
            onImagePressed: _showImagePlaceholder,
            onSend: _showAiPlaceholder,
          ),
        ],
      ),
    );
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
