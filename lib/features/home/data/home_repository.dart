import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/home_day_data.dart';

class HomeRepository {
  HomeRepository({AppDatabase? database})
    : _database = database ?? _sharedDatabase;

  static final AppDatabase _sharedDatabase = AppDatabase();

  final AppDatabase _database;

  Future<Map<DateTime, HomeDayData>> loadMonth(DateTime month) async {
    final database = await _database.database;
    final firstDay = DateTime(month.year, month.month);
    final nextMonth = DateTime(month.year, month.month + 1);
    final rangeArguments = [
      firstDay.toIso8601String(),
      nextMonth.toIso8601String(),
    ];
    final days = <DateTime, HomeDayData>{};

    final weatherRows = await database.query(
      'weather_records',
      where: 'record_date >= ? AND record_date < ?',
      whereArgs: rangeArguments,
      orderBy: 'record_date ASC',
    );
    for (final row in weatherRows) {
      final date = _dateOnly(DateTime.parse(row['record_date'] as String));
      final current = days[date] ?? HomeDayData.empty(date);
      days[date] = current.copyWith(
        hasWeatherRecord: true,
        weatherType: row['weather_type'] as String?,
        currentTemperature: (row['current_temperature'] as num?)?.toDouble(),
        minTemperature: (row['min_temperature'] as num?)?.toDouble(),
        maxTemperature: (row['max_temperature'] as num?)?.toDouble(),
      );
    }

    final outfitRows = await database.query(
      'daily_outfit_records',
      columns: const ['record_date'],
      where: 'record_date >= ? AND record_date < ?',
      whereArgs: rangeArguments,
      orderBy: 'record_date ASC',
    );
    for (final row in outfitRows) {
      final date = _dateOnly(DateTime.parse(row['record_date'] as String));
      final current = days[date] ?? HomeDayData.empty(date);
      days[date] = current.copyWith(hasOutfitRecord: true);
    }

    final calendarRows = await database.query(
      'calendar_records',
      where: 'record_date >= ? AND record_date < ?',
      whereArgs: rangeArguments,
      orderBy: 'created_at ASC',
    );
    for (final row in calendarRows) {
      final date = _dateOnly(DateTime.parse(row['record_date'] as String));
      final current = days[date] ?? HomeDayData.empty(date);
      final entryType = row['entry_type'] as String;

      switch (entryType) {
        case 'weather':
          days[date] = current.copyWith(hasWeatherRecord: true);
          break;
        case 'outfit':
          days[date] = current.copyWith(hasOutfitRecord: true);
          break;
        case 'text':
          final content = (row['text_content'] as String?)?.trim();
          if (content != null && content.isNotEmpty) {
            days[date] = current.copyWith(
              textEntries: [...current.textEntries, content],
            );
          }
          break;
        case 'image':
          final paths = _decodeImagePaths(row['image_paths'] as String?);
          if (paths.isNotEmpty) {
            days[date] = current.copyWith(
              imagePaths: [...current.imagePaths, ...paths],
            );
          }
          break;
      }
    }

    return days;
  }

  Future<void> saveQuickRecord({
    required DateTime date,
    required String text,
    required List<String> imagePaths,
  }) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty && imagePaths.isEmpty) {
      throw ArgumentError('快捷记录不能同时缺少文字和图片。');
    }

    final database = await _database.database;
    final recordDate = _dateOnly(date).toIso8601String();
    final createdAt = DateTime.now().toIso8601String();

    await database.transaction((transaction) async {
      if (normalizedText.isNotEmpty) {
        await _insertCalendarRecord(
          transaction,
          recordDate: recordDate,
          entryType: 'text',
          textContent: normalizedText,
          imagePaths: const [],
          createdAt: createdAt,
        );
      }
      if (imagePaths.isNotEmpty) {
        await _insertCalendarRecord(
          transaction,
          recordDate: recordDate,
          entryType: 'image',
          imagePaths: imagePaths,
          createdAt: createdAt,
        );
      }
    });
  }

  Future<void> _insertCalendarRecord(
    DatabaseExecutor database, {
    required String recordDate,
    required String entryType,
    String? textContent,
    required List<String> imagePaths,
    required String createdAt,
  }) async {
    await database.insert('calendar_records', {
      'record_date': recordDate,
      'entry_type': entryType,
      'text_content': textContent,
      'image_paths': jsonEncode(imagePaths),
      'created_at': createdAt,
    });
  }

  static List<String> _decodeImagePaths(String? encodedPaths) {
    if (encodedPaths == null || encodedPaths.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(encodedPaths);
      if (decoded is! List) {
        return const [];
      }
      return decoded.whereType<String>().toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
