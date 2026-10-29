import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/date_key_codec.dart';
import '../domain/home_day_data.dart';

class HomeRepository {
  HomeRepository({AppDatabase? database})
    : _database = database ?? _sharedDatabase;

  static final AppDatabase _sharedDatabase = AppDatabase();

  final AppDatabase _database;

  Future<Map<DateTime, HomeDayData>> loadMonth(DateTime month) async {
    final database = await _database.database;
    final firstDay = DateKeyCodec.encode(DateTime(month.year, month.month));
    final nextMonth = DateKeyCodec.encode(
      DateTime(month.year, month.month + 1),
    );
    final rangeArguments = [firstDay, nextMonth];
    final days = <DateTime, HomeDayData>{};

    final weatherRows = await database.rawQuery('''
      SELECT * FROM weather_records
      WHERE substr(record_date, 1, 10) >= ?
        AND substr(record_date, 1, 10) < ?
      ORDER BY record_date ASC
      ''', rangeArguments);
    for (final row in weatherRows) {
      final date = DateKeyCodec.decode(row['record_date'] as String);
      final current = days[date] ?? HomeDayData.empty(date);
      days[date] = current.copyWith(
        hasWeatherRecord: true,
        weatherType: row['weather_type'] as String?,
        currentTemperature: (row['current_temperature'] as num?)?.toDouble(),
        minTemperature: (row['min_temperature'] as num?)?.toDouble(),
        maxTemperature: (row['max_temperature'] as num?)?.toDouble(),
      );
    }

    final outfitRows = await database.rawQuery('''
      SELECT dor.record_date,
             ci.id AS clothing_item_id,
             ci.name AS clothing_name,
             ci.image_path AS clothing_image_path
      FROM daily_outfit_records dor
      LEFT JOIN daily_outfit_items doi ON doi.daily_outfit_id = dor.id
      LEFT JOIN clothing_items ci ON ci.id = doi.clothing_item_id
      WHERE substr(dor.record_date, 1, 10) >= ?
        AND substr(dor.record_date, 1, 10) < ?
      ORDER BY dor.record_date ASC, doi.clothing_item_id ASC
      ''', rangeArguments);
    for (final row in outfitRows) {
      final date = DateKeyCodec.decode(row['record_date'] as String);
      final current = days[date] ?? HomeDayData.empty(date);
      final clothingItemId = row['clothing_item_id'] as int?;
      final outfitItems = [...current.outfitItems];
      if (clothingItemId != null) {
        outfitItems.add(
          HomeOutfitItem(
            id: clothingItemId,
            name: row['clothing_name'] as String? ?? '已删除衣服',
            imagePath: row['clothing_image_path'] as String? ?? '',
          ),
        );
      }
      days[date] = current.copyWith(
        hasOutfitRecord: true,
        outfitItems: outfitItems,
      );
    }

    final calendarRows = await database.rawQuery('''
      SELECT * FROM calendar_records
      WHERE substr(record_date, 1, 10) >= ?
        AND substr(record_date, 1, 10) < ?
      ORDER BY created_at ASC
      ''', rangeArguments);
    for (final row in calendarRows) {
      final date = DateKeyCodec.decode(row['record_date'] as String);
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
    final recordDate = DateKeyCodec.encode(date);
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
}
