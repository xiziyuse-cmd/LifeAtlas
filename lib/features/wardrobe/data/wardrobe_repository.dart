import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/date_key_codec.dart';
import '../../../core/database/wardrobe_schema.dart';
import '../domain/models/clothing_catalog.dart';
import '../domain/models/clothing_item.dart';
import '../domain/models/clothing_parameter.dart';
import '../domain/models/clothing_recommendation.dart';
import '../domain/models/daily_outfit_record.dart';
import '../domain/models/outfit_set.dart';
import '../domain/models/preorder_analysis.dart';
import '../domain/models/preorder_item.dart';
import '../domain/models/season_tags.dart';
import '../domain/models/wardrobe_filter.dart';

class WardrobeRepository {
  WardrobeRepository({AppDatabase? database})
    : _database = database ?? _sharedDatabase;

  static final AppDatabase _sharedDatabase = AppDatabase();

  final AppDatabase _database;

  Future<List<ClothingCategory>> listCategories() async {
    final database = await _database.database;
    final rows = await database.query(
      'clothing_categories',
      orderBy: 'sort_order ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(ClothingCategory.fromMap).toList(growable: false);
  }

  Future<ClothingCategory> createCategory(String name) async {
    final database = await _database.database;
    final row = await database.transaction((transaction) async {
      return _createCatalogEntry(
        transaction,
        table: 'clothing_categories',
        name: name,
      );
    });
    return ClothingCategory.fromMap(row);
  }

  Future<List<ClothingBrand>> listBrands() async {
    final database = await _database.database;
    final rows = await database.query(
      'clothing_brands',
      orderBy: 'sort_order ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(ClothingBrand.fromMap).toList(growable: false);
  }

  Future<ClothingBrand> createBrand(String name) async {
    final database = await _database.database;
    final row = await database.transaction((transaction) async {
      return _createCatalogEntry(
        transaction,
        table: 'clothing_brands',
        name: name,
      );
    });
    return ClothingBrand.fromMap(row);
  }

  Future<List<ClothingItem>> listClothing({
    WardrobeFilter filter = const WardrobeFilter(),
  }) async {
    final normalizedSeasons = WardrobeSeasonTags.normalize(
      filter.seasonTags,
      maxCount: 4,
    );
    final clauses = <String>['is_deleted = 0'];
    final arguments = <Object?>[];
    if (filter.categoryIds.isNotEmpty) {
      clauses.add(
        'category_id IN (${_placeholders(filter.categoryIds.length)})',
      );
      arguments.addAll(filter.categoryIds);
    }
    if (filter.brandIds.isNotEmpty) {
      clauses.add('brand_id IN (${_placeholders(filter.brandIds.length)})');
      arguments.addAll(filter.brandIds);
    }

    final database = await _database.database;
    final rows = await database.query(
      'clothing_items',
      where: clauses.join(' AND '),
      whereArgs: arguments,
      orderBy: 'created_at DESC, id DESC',
    );
    final parameters = await _loadClothingParameters(
      database,
      rows.map((row) => row['id'] as int),
    );
    final items = rows.map(
      (row) => ClothingItem.fromMap(
        row,
        parameterValues: parameters[row['id'] as int] ?? const {},
      ),
    );
    if (normalizedSeasons.isEmpty) {
      return items.toList(growable: false);
    }
    return items
        .where((item) => item.seasonTags.any(normalizedSeasons.contains))
        .toList(growable: false);
  }

  Future<ClothingItem?> getClothing(
    int id, {
    bool includeDeleted = false,
  }) async {
    final database = await _database.database;
    final rows = await database.query(
      'clothing_items',
      where: includeDeleted ? 'id = ?' : 'id = ? AND is_deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final parameters = await _loadClothingParameters(database, [id]);
    return ClothingItem.fromMap(
      rows.first,
      parameterValues: parameters[id] ?? const {},
    );
  }

  Future<int> createClothing(ClothingItem item) async {
    _validateClothing(item);
    final database = await _database.database;
    return database.transaction((transaction) async {
      final category = await _resolveCatalogValue(
        transaction,
        table: 'clothing_categories',
        id: item.categoryId,
        name: item.category,
      );
      final brand = await _resolveCatalogValue(
        transaction,
        table: 'clothing_brands',
        id: item.brandId,
        name: item.brand,
      );
      final values = Map<String, Object?>.from(item.toMap())
        ..remove('id')
        ..['name'] = item.name.trim()
        ..['image_path'] = item.imagePath.trim()
        ..['category_id'] = category?.id
        ..['category'] = category?.name
        ..['brand_id'] = brand?.id
        ..['brand'] = brand?.name
        ..['wear_count'] = 0
        ..['min_worn_temperature'] = null
        ..['max_worn_temperature'] = null
        ..['is_deleted'] = 0;
      final id = await transaction.insert('clothing_items', values);
      await _replaceClothingParameters(
        transaction,
        id,
        item.parameterValues,
        item.updatedAt,
      );
      return id;
    });
  }

  Future<void> updateClothing(ClothingItem item) async {
    final id = item.id;
    if (id == null) {
      throw ArgumentError('更新衣服时必须提供 id。');
    }
    _validateClothing(item);
    final database = await _database.database;
    await database.transaction((transaction) async {
      final existing = await transaction.query(
        'clothing_items',
        columns: const ['id'],
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [id],
        limit: 1,
      );
      if (existing.isEmpty) {
        throw StateError('衣服不存在或已经删除。');
      }
      final category = await _resolveCatalogValue(
        transaction,
        table: 'clothing_categories',
        id: item.categoryId,
        name: item.category,
      );
      final brand = await _resolveCatalogValue(
        transaction,
        table: 'clothing_brands',
        id: item.brandId,
        name: item.brand,
      );
      final values = Map<String, Object?>.from(item.toMap())
        ..remove('id')
        ..remove('wear_count')
        ..remove('min_worn_temperature')
        ..remove('max_worn_temperature')
        ..remove('is_deleted')
        ..remove('created_at')
        ..['name'] = item.name.trim()
        ..['image_path'] = item.imagePath.trim()
        ..['category_id'] = category?.id
        ..['category'] = category?.name
        ..['brand_id'] = brand?.id
        ..['brand'] = brand?.name;
      await transaction.update(
        'clothing_items',
        values,
        where: 'id = ?',
        whereArgs: [id],
      );
      await _replaceClothingParameters(
        transaction,
        id,
        item.parameterValues,
        item.updatedAt,
      );
    });
  }

  Future<void> softDeleteClothing(int id) async {
    final database = await _database.database;
    final count = await database.update(
      'clothing_items',
      {'is_deleted': 1, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    if (count == 0) {
      throw StateError('衣服不存在或已经删除。');
    }
  }

  Future<List<OutfitSet>> listOutfitSets({String? seasonTag}) async {
    final normalizedSeason = seasonTag == null
        ? null
        : WardrobeSeasonTags.normalize([seasonTag], maxCount: 4).single;
    final database = await _database.database;
    final rows = await database.query(
      'outfit_sets',
      orderBy: 'created_at DESC, id DESC',
    );
    final result = <OutfitSet>[];
    for (final row in rows) {
      final outfit = await _outfitSetFromRow(database, row);
      if (normalizedSeason == null ||
          outfit.seasonTags.contains(normalizedSeason)) {
        result.add(outfit);
      }
    }
    return result;
  }

  Future<OutfitSet?> getOutfitSet(int id) async {
    final database = await _database.database;
    final rows = await database.query(
      'outfit_sets',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _outfitSetFromRow(database, rows.first);
  }

  Future<int> createOutfitSet(OutfitSet set) async {
    _validateOutfitSet(set);
    final database = await _database.database;
    return database.transaction((transaction) async {
      await _validateActiveClothingIds(transaction, set.clothingItemIds);
      final values = Map<String, Object?>.from(set.toMap())..remove('id');
      final id = await transaction.insert('outfit_sets', values);
      await _replaceOutfitSetItems(transaction, id, set.clothingItemIds);
      return id;
    });
  }

  Future<void> updateOutfitSet(OutfitSet set) async {
    final id = set.id;
    if (id == null) {
      throw ArgumentError('更新套装时必须提供 id。');
    }
    _validateOutfitSet(set);
    final database = await _database.database;
    await database.transaction((transaction) async {
      await _validateActiveClothingIds(transaction, set.clothingItemIds);
      final values = Map<String, Object?>.from(set.toMap())
        ..remove('id')
        ..remove('created_at');
      final count = await transaction.update(
        'outfit_sets',
        values,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count == 0) {
        throw StateError('套装不存在。');
      }
      await _replaceOutfitSetItems(transaction, id, set.clothingItemIds);
    });
  }

  Future<void> deleteOutfitSet(int id) async {
    final database = await _database.database;
    final count = await database.delete(
      'outfit_sets',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count == 0) {
      throw StateError('套装不存在。');
    }
  }

  Future<DailyOutfitRecord?> getDailyOutfit(DateTime date) async {
    final database = await _database.database;
    final dateKey = DateKeyCodec.encode(date);
    final rows = await _dailyRowsForDate(database, dateKey);
    if (rows.isEmpty) {
      return null;
    }
    final ids = await _dailyClothingIds(
      database,
      rows.map((row) => row['id'] as int),
    );
    final canonicalRow = Map<String, Object?>.from(rows.first)
      ..['record_date'] = dateKey;
    return DailyOutfitRecord.fromMap(
      canonicalRow,
      clothingItemIds: ids.toList(growable: false),
    );
  }

  Future<void> replaceDailyOutfit({
    required DateTime date,
    required Iterable<int> clothingItemIds,
    DateTime? recordedAt,
  }) async {
    final newIds = clothingItemIds.toSet();
    final database = await _database.database;
    final dateKey = DateKeyCodec.encode(date);
    final now = DateTime.now().toUtc();
    await database.transaction((transaction) async {
      if (newIds.isNotEmpty) {
        await _validateActiveClothingIds(transaction, newIds);
      }
      final rows = await _dailyRowsForDate(transaction, dateKey);
      final rowIds = rows.map((row) => row['id'] as int).toList();
      final oldIds = await _dailyClothingIds(transaction, rowIds);

      if (newIds.isEmpty) {
        if (rowIds.isNotEmpty) {
          await transaction.delete(
            'daily_outfit_records',
            where: 'id IN (${_placeholders(rowIds.length)})',
            whereArgs: rowIds,
          );
          await _updateWearCounts(
            transaction,
            added: const {},
            removed: oldIds,
          );
          if (rows.length > 1) {
            await _rebuildWearCounts(transaction, oldIds);
          }
        }
        return;
      }

      final exactRows = rows.where((row) => row['record_date'] == dateKey);
      final targetRow = exactRows.isNotEmpty
          ? exactRows.first
          : (rows.isEmpty ? null : rows.first);
      late final int recordId;
      if (targetRow == null) {
        recordId = await transaction.insert('daily_outfit_records', {
          'record_date': dateKey,
          'recorded_at': (recordedAt ?? now).toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
      } else {
        recordId = targetRow['id'] as int;
        final extraIds = rowIds.where((id) => id != recordId).toList();
        if (extraIds.isNotEmpty) {
          await transaction.delete(
            'daily_outfit_records',
            where: 'id IN (${_placeholders(extraIds.length)})',
            whereArgs: extraIds,
          );
        }
        await transaction.update(
          'daily_outfit_records',
          {'record_date': dateKey, 'updated_at': now.toIso8601String()},
          where: 'id = ?',
          whereArgs: [recordId],
        );
      }

      await transaction.delete(
        'daily_outfit_items',
        where: 'daily_outfit_id = ?',
        whereArgs: [recordId],
      );
      for (final clothingId in newIds) {
        await transaction.insert('daily_outfit_items', {
          'daily_outfit_id': recordId,
          'clothing_item_id': clothingId,
        });
      }
      await _updateWearCounts(
        transaction,
        added: newIds.difference(oldIds),
        removed: oldIds.difference(newIds),
      );
      if (rows.length > 1) {
        await _rebuildWearCounts(transaction, oldIds.union(newIds));
      }

      final storedRecord = targetRow;
      final weather = await _weatherForDate(transaction, dateKey);
      final minTemperature =
          (weather?['min_temperature'] as num?)?.toDouble() ??
          (storedRecord?['min_temperature'] as num?)?.toDouble();
      final maxTemperature =
          (weather?['max_temperature'] as num?)?.toDouble() ??
          (storedRecord?['max_temperature'] as num?)?.toDouble();
      if (minTemperature != null && maxTemperature != null) {
        _validateTemperatureRange(minTemperature, maxTemperature);
        await _expandTemperatureForItems(
          transaction,
          newIds,
          minTemperature,
          maxTemperature,
        );
        await transaction.update(
          'daily_outfit_records',
          {
            'weather_type':
                weather?['weather_type'] ?? storedRecord?['weather_type'],
            'min_temperature': minTemperature,
            'max_temperature': maxTemperature,
            'temperature_applied_at': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [recordId],
        );
      }
    });
  }

  Future<void> deleteDailyOutfit(DateTime date) {
    return replaceDailyOutfit(date: date, clothingItemIds: const []);
  }

  Future<void> applyTemperatureForDate({
    required DateTime date,
    required double minTemperature,
    required double maxTemperature,
    String? weatherType,
    DateTime? appliedAt,
  }) async {
    _validateTemperatureRange(minTemperature, maxTemperature);
    final database = await _database.database;
    final dateKey = DateKeyCodec.encode(date);
    final applied = (appliedAt ?? DateTime.now().toUtc()).toIso8601String();
    await database.transaction((transaction) async {
      final rows = await _dailyRowsForDate(transaction, dateKey);
      if (rows.isEmpty) {
        return;
      }
      final rowIds = rows.map((row) => row['id'] as int).toList();
      final clothingIds = await _dailyClothingIds(transaction, rowIds);
      await _expandTemperatureForItems(
        transaction,
        clothingIds,
        minTemperature,
        maxTemperature,
      );
      final updateValues = <String, Object?>{
        'min_temperature': minTemperature,
        'max_temperature': maxTemperature,
        'temperature_applied_at': applied,
        'updated_at': applied,
      };
      if (weatherType != null) {
        updateValues['weather_type'] = weatherType;
      }
      await transaction.update(
        'daily_outfit_records',
        updateValues,
        where: 'id IN (${_placeholders(rowIds.length)})',
        whereArgs: rowIds,
      );
    });
  }

  Future<int> syncPendingTemperatureMemory() async {
    final database = await _database.database;
    final pendingRows = await database.query(
      'daily_outfit_records',
      where: 'temperature_applied_at IS NULL',
      orderBy: 'record_date ASC',
    );
    final pendingDates = <String>{};
    for (final row in pendingRows) {
      try {
        pendingDates.add(
          DateKeyCodec.normalizeStorageValue(row['record_date']),
        );
      } on FormatException {
        continue;
      }
    }

    var appliedCount = 0;
    for (final dateKey in pendingDates) {
      final rows = await _dailyRowsForDate(database, dateKey);
      if (rows.isEmpty) {
        continue;
      }
      final row = rows.first;
      final weather = await _weatherForDate(database, dateKey);
      final minTemperature =
          (row['min_temperature'] as num?)?.toDouble() ??
          (weather?['min_temperature'] as num?)?.toDouble();
      final maxTemperature =
          (row['max_temperature'] as num?)?.toDouble() ??
          (weather?['max_temperature'] as num?)?.toDouble();
      if (minTemperature == null || maxTemperature == null) {
        continue;
      }
      await applyTemperatureForDate(
        date: DateKeyCodec.decode(dateKey),
        minTemperature: minTemperature,
        maxTemperature: maxTemperature,
        weatherType:
            (row['weather_type'] ?? weather?['weather_type']) as String?,
      );
      appliedCount++;
    }
    return appliedCount;
  }

  Future<List<ClothingRecommendation>> recommendForTemperature({
    required double minTemperature,
    required double maxTemperature,
    String? seasonTag,
    int? limit,
  }) async {
    _validateTemperatureRange(minTemperature, maxTemperature);
    if (limit != null && limit < 0) {
      throw ArgumentError.value(limit, 'limit', '不能小于 0');
    }
    final items = await listClothing(
      filter: WardrobeFilter(
        seasonTags: seasonTag == null ? const {} : {seasonTag},
      ),
    );
    final recommendations = <ClothingRecommendation>[];
    final weatherSpan = maxTemperature - minTemperature;
    for (final item in items) {
      final itemMin = item.minWornTemperature;
      final itemMax = item.maxWornTemperature;
      if (itemMin == null || itemMax == null) {
        continue;
      }
      final fullMatch = itemMin <= minTemperature && itemMax >= maxTemperature;
      final coverage = weatherSpan == 0
          ? (itemMin <= minTemperature && itemMax >= minTemperature ? 1.0 : 0.0)
          : math.max(
                  0.0,
                  math.min(itemMax, maxTemperature) -
                      math.max(itemMin, minTemperature),
                ) /
                weatherSpan;
      recommendations.add(
        ClothingRecommendation(
          item: item,
          isFullMatch: fullMatch,
          coverageRatio: coverage,
        ),
      );
    }
    recommendations.sort((left, right) {
      final matchComparison = (right.isFullMatch ? 1 : 0).compareTo(
        left.isFullMatch ? 1 : 0,
      );
      if (matchComparison != 0) {
        return matchComparison;
      }
      final coverageComparison = right.coverageRatio.compareTo(
        left.coverageRatio,
      );
      if (coverageComparison != 0) {
        return coverageComparison;
      }
      final wearComparison = right.item.wearCount.compareTo(
        left.item.wearCount,
      );
      if (wearComparison != 0) {
        return wearComparison;
      }
      return (left.item.id ?? 0).compareTo(right.item.id ?? 0);
    });
    final selected = recommendations.any((item) => item.isFullMatch)
        ? recommendations.where((item) => item.isFullMatch).toList()
        : recommendations;
    if (limit == null || selected.length <= limit) {
      return selected;
    }
    return selected.take(limit).toList(growable: false);
  }

  Future<List<PreorderItem>> listPreorders({
    bool includePurchased = false,
  }) async {
    final database = await _database.database;
    final rows = await database.query(
      'preorder_items',
      where: includePurchased
          ? 'is_deleted = 0'
          : 'is_deleted = 0 AND is_purchased = 0',
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(PreorderItem.fromMap).toList(growable: false);
  }

  Future<PreorderItem?> getPreorder(
    int id, {
    bool includeDeleted = false,
  }) async {
    final database = await _database.database;
    final rows = await database.query(
      'preorder_items',
      where: includeDeleted ? 'id = ?' : 'id = ? AND is_deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : PreorderItem.fromMap(rows.first);
  }

  Future<int> createPreorder(PreorderItem item) async {
    _validatePreorder(item);
    final database = await _database.database;
    return database.transaction((transaction) async {
      final values = await _preorderValues(transaction, item)
        ..remove('id')
        ..['is_purchased'] = 0
        ..['purchased_at'] = null
        ..['clothing_item_id'] = null
        ..['is_deleted'] = 0;
      return transaction.insert('preorder_items', values);
    });
  }

  Future<void> updatePreorder(PreorderItem item) async {
    final id = item.id;
    if (id == null) {
      throw ArgumentError('更新预购衣服时必须提供 id。');
    }
    _validatePreorder(item);
    final database = await _database.database;
    await database.transaction((transaction) async {
      final existing = await transaction.query(
        'preorder_items',
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [id],
        limit: 1,
      );
      if (existing.isEmpty) {
        throw StateError('预购衣服不存在或已经删除。');
      }
      final values = await _preorderValues(transaction, item)
        ..remove('id')
        ..remove('is_purchased')
        ..remove('purchased_at')
        ..remove('clothing_item_id')
        ..remove('is_deleted')
        ..remove('created_at');
      await transaction.update(
        'preorder_items',
        values,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> softDeletePreorder(int id) async {
    final database = await _database.database;
    final count = await database.update(
      'preorder_items',
      {'is_deleted': 1, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    if (count == 0) {
      throw StateError('预购衣服不存在或已经删除。');
    }
  }

  Future<void> markPreorderPurchased(
    int id, {
    int? clothingItemId,
    DateTime? purchasedAt,
  }) async {
    final database = await _database.database;
    await database.transaction((transaction) async {
      if (clothingItemId != null) {
        await _validateActiveClothingIds(transaction, [clothingItemId]);
      }
      final timestamp = (purchasedAt ?? DateTime.now().toUtc())
          .toIso8601String();
      final count = await transaction.update(
        'preorder_items',
        {
          'is_purchased': 1,
          'purchased_at': timestamp,
          'clothing_item_id': clothingItemId,
          'updated_at': timestamp,
        },
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [id],
      );
      if (count == 0) {
        throw StateError('预购衣服不存在或已经删除。');
      }
    });
  }

  Future<int> appendPreorderAnalysis(PreorderAnalysis analysis) async {
    _validatePreorderAnalysis(analysis);
    final database = await _database.database;
    return database.transaction((transaction) async {
      final itemRows = await transaction.query(
        'preorder_items',
        columns: const ['id'],
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [analysis.preorderItemId],
        limit: 1,
      );
      if (itemRows.isEmpty) {
        throw StateError('预购衣服不存在或已经删除。');
      }
      final values = Map<String, Object?>.from(analysis.toMap())..remove('id');
      return transaction.insert('preorder_analyses', values);
    });
  }

  Future<List<PreorderAnalysis>> listPreorderAnalyses(
    int preorderItemId,
  ) async {
    final database = await _database.database;
    final rows = await database.query(
      'preorder_analyses',
      where: 'preorder_item_id = ?',
      whereArgs: [preorderItemId],
      orderBy: 'analyzed_at DESC, id DESC',
    );
    return rows.map(PreorderAnalysis.fromMap).toList(growable: false);
  }

  Future<Map<String, Object?>> _createCatalogEntry(
    DatabaseExecutor database, {
    required String table,
    required String name,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('目录名称不能为空。');
    }
    final normalized = normalizeWardrobeCatalogName(trimmedName);
    final existing = await database.query(
      table,
      where: 'normalized_name = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return existing.first;
    }
    final id = await database.insert(table, {
      'name': trimmedName,
      'normalized_name': normalized,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    final rows = await database.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.single;
  }

  Future<_CatalogValue?> _resolveCatalogValue(
    DatabaseExecutor database, {
    required String table,
    required int? id,
    required String? name,
  }) async {
    if (id != null) {
      final rows = await database.query(
        table,
        columns: const ['id', 'name'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw ArgumentError('目录项 $id 不存在。');
      }
      return _CatalogValue(id, rows.first['name'] as String);
    }
    final trimmedName = name?.trim();
    if (trimmedName == null || trimmedName.isEmpty) {
      return null;
    }
    final row = await _createCatalogEntry(
      database,
      table: table,
      name: trimmedName,
    );
    return _CatalogValue(row['id'] as int, row['name'] as String);
  }

  Future<OutfitSet> _outfitSetFromRow(
    DatabaseExecutor database,
    Map<String, Object?> row,
  ) async {
    final itemRows = await database.query(
      'outfit_set_items',
      columns: const ['clothing_item_id'],
      where: 'outfit_set_id = ?',
      whereArgs: [row['id']],
      orderBy: 'position ASC, clothing_item_id ASC',
    );
    return OutfitSet.fromMap(
      row,
      clothingItemIds: itemRows
          .map((item) => item['clothing_item_id'] as int)
          .toList(growable: false),
    );
  }

  Future<void> _replaceOutfitSetItems(
    DatabaseExecutor database,
    int outfitSetId,
    Iterable<int> clothingItemIds,
  ) async {
    await database.delete(
      'outfit_set_items',
      where: 'outfit_set_id = ?',
      whereArgs: [outfitSetId],
    );
    var position = 0;
    for (final clothingItemId in clothingItemIds) {
      await database.insert('outfit_set_items', {
        'outfit_set_id': outfitSetId,
        'clothing_item_id': clothingItemId,
        'position': position++,
      });
    }
  }

  Future<void> _validateActiveClothingIds(
    DatabaseExecutor database,
    Iterable<int> ids,
  ) async {
    final uniqueIds = ids.toSet();
    if (uniqueIds.isEmpty) {
      return;
    }
    final rows = await database.query(
      'clothing_items',
      columns: const ['id'],
      where: 'is_deleted = 0 AND id IN (${_placeholders(uniqueIds.length)})',
      whereArgs: uniqueIds.toList(growable: false),
    );
    if (rows.length != uniqueIds.length) {
      throw ArgumentError('包含不存在或已经删除的衣服。');
    }
  }

  Future<List<Map<String, Object?>>> _dailyRowsForDate(
    DatabaseExecutor database,
    String dateKey,
  ) {
    return database.query(
      'daily_outfit_records',
      where: 'substr(record_date, 1, 10) = ?',
      whereArgs: [dateKey],
      orderBy: "CASE WHEN record_date = '$dateKey' THEN 0 ELSE 1 END, id ASC",
    );
  }

  Future<Set<int>> _dailyClothingIds(
    DatabaseExecutor database,
    Iterable<int> dailyRecordIds,
  ) async {
    final ids = dailyRecordIds.toList(growable: false);
    if (ids.isEmpty) {
      return <int>{};
    }
    final rows = await database.query(
      'daily_outfit_items',
      columns: const ['clothing_item_id'],
      where: 'daily_outfit_id IN (${_placeholders(ids.length)})',
      whereArgs: ids,
      orderBy: 'clothing_item_id ASC',
    );
    return rows.map((row) => row['clothing_item_id'] as int).toSet();
  }

  Future<Map<String, Object?>?> _weatherForDate(
    DatabaseExecutor database,
    String dateKey,
  ) async {
    final rows = await database.query(
      'weather_records',
      where: 'substr(record_date, 1, 10) = ?',
      whereArgs: [dateKey],
      orderBy: 'recorded_at DESC, id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> _updateWearCounts(
    DatabaseExecutor database, {
    required Set<int> added,
    required Set<int> removed,
  }) async {
    for (final id in added) {
      await database.rawUpdate(
        '''
        UPDATE clothing_items
        SET wear_count = wear_count + 1
        WHERE id = ?
      ''',
        [id],
      );
    }
    for (final id in removed) {
      await database.rawUpdate(
        '''
        UPDATE clothing_items
        SET wear_count = CASE WHEN wear_count > 0 THEN wear_count - 1 ELSE 0 END
        WHERE id = ?
      ''',
        [id],
      );
    }
  }

  Future<void> _rebuildWearCounts(
    DatabaseExecutor database,
    Iterable<int> clothingItemIds,
  ) async {
    for (final id in clothingItemIds) {
      await database.rawUpdate(
        '''
        UPDATE clothing_items
        SET wear_count = (
          SELECT COUNT(DISTINCT substr(records.record_date, 1, 10))
          FROM daily_outfit_items AS items
          INNER JOIN daily_outfit_records AS records
            ON records.id = items.daily_outfit_id
          WHERE items.clothing_item_id = ?
        )
        WHERE id = ?
      ''',
        [id, id],
      );
    }
  }

  Future<void> _expandTemperatureForItems(
    DatabaseExecutor database,
    Iterable<int> clothingItemIds,
    double minTemperature,
    double maxTemperature,
  ) async {
    final ids = clothingItemIds.toList(growable: false);
    if (ids.isEmpty) {
      return;
    }
    await database.rawUpdate(
      '''
      UPDATE clothing_items
      SET min_worn_temperature = CASE
            WHEN min_worn_temperature IS NULL OR min_worn_temperature > ?
              THEN ?
            ELSE min_worn_temperature
          END,
          max_worn_temperature = CASE
            WHEN max_worn_temperature IS NULL OR max_worn_temperature < ?
              THEN ?
            ELSE max_worn_temperature
          END
      WHERE id IN (${_placeholders(ids.length)})
    ''',
      [minTemperature, minTemperature, maxTemperature, maxTemperature, ...ids],
    );
  }

  Future<Map<String, Object?>> _preorderValues(
    DatabaseExecutor database,
    PreorderItem item,
  ) async {
    final category = await _resolveCatalogValue(
      database,
      table: 'clothing_categories',
      id: item.categoryId,
      name: item.category,
    );
    final brand = await _resolveCatalogValue(
      database,
      table: 'clothing_brands',
      id: item.brandId,
      name: item.brand,
    );
    return Map<String, Object?>.from(item.toMap())
      ..['name'] = _trimmedOrNull(item.name)
      ..['image_path'] = item.imagePath.trim()
      ..['category_id'] = category?.id
      ..['category'] = category?.name
      ..['brand_id'] = brand?.id
      ..['brand'] = brand?.name;
  }

  Future<Map<int, Map<String, ClothingParameterValue>>> _loadClothingParameters(
    DatabaseExecutor database,
    Iterable<int> clothingItemIds,
  ) async {
    final ids = clothingItemIds.toSet().toList(growable: false);
    if (ids.isEmpty) {
      return const {};
    }
    final rows = await database.query(
      'clothing_parameter_values',
      where: 'clothing_item_id IN (${_placeholders(ids.length)})',
      whereArgs: ids,
      orderBy: 'clothing_item_id ASC, parameter_key ASC',
    );
    final result = <int, Map<String, ClothingParameterValue>>{};
    for (final row in rows) {
      final itemId = row['clothing_item_id'] as int;
      final value = ClothingParameterValue.fromMap(row);
      result.putIfAbsent(itemId, () => {})[value.key] = value;
    }
    return result;
  }

  Future<void> _replaceClothingParameters(
    DatabaseExecutor database,
    int clothingItemId,
    Map<String, ClothingParameterValue> values,
    DateTime updatedAt,
  ) async {
    await database.delete(
      'clothing_parameter_values',
      where: 'clothing_item_id = ?',
      whereArgs: [clothingItemId],
    );
    final updatedAtText = updatedAt.toUtc().toIso8601String();
    for (final value in values.values) {
      if (value.isEmpty ||
          !ClothingParameterCatalog.byKey.containsKey(value.key)) {
        continue;
      }
      final number = value.numberValue;
      if (number != null && (!number.isFinite || number < 0)) {
        throw ArgumentError(
          '${ClothingParameterCatalog.byKey[value.key]!.label}必须是非负有限数值。',
        );
      }
      await database.insert(
        'clothing_parameter_values',
        value.toMap(clothingItemId, updatedAtText),
      );
    }
  }

  void _validateClothing(ClothingItem item) {
    if (item.name.trim().isEmpty) {
      throw ArgumentError('衣服名称不能为空。');
    }
    if (item.imagePath.trim().isEmpty) {
      throw ArgumentError('衣服图片不能为空。');
    }
    WardrobeSeasonTags.normalize(item.seasonTags);
    _validateNonNegativeValues({
      '衣长': item.clothingLength,
      '肩宽': item.shoulderWidth,
      '胸围': item.chestCircumference,
      '袖长': item.sleeveLength,
      '腰围': item.waistCircumference,
      '臀围': item.hipCircumference,
      '裤长': item.trouserLength,
      '购买价格': item.purchasePrice,
    });
  }

  void _validateOutfitSet(OutfitSet set) {
    if (set.name.trim().isEmpty) {
      throw ArgumentError('套装名称不能为空。');
    }
    final seasons = WardrobeSeasonTags.normalize(set.seasonTags, maxCount: 4);
    if (seasons.isEmpty) {
      throw ArgumentError('套装至少需要一个季节标签。');
    }
    if (set.clothingItemIds.toSet().length < 2) {
      throw ArgumentError('套装至少需要两件不同的衣服。');
    }
  }

  void _validatePreorder(PreorderItem item) {
    if (item.imagePath.trim().isEmpty) {
      throw ArgumentError('预购衣服图片不能为空。');
    }
    _validateNonNegativeValues({
      '价格': item.price,
      '衣长': item.clothingLength,
      '肩宽': item.shoulderWidth,
      '胸围': item.chestCircumference,
      '袖长': item.sleeveLength,
      '腰围': item.waistCircumference,
      '臀围': item.hipCircumference,
      '裤长': item.trouserLength,
    });
  }

  void _validatePreorderAnalysis(PreorderAnalysis analysis) {
    if (analysis.promptVersion.trim().isEmpty ||
        analysis.model.trim().isEmpty ||
        analysis.resultText.trim().isEmpty) {
      throw ArgumentError('分析版本、模型和结果不能为空。');
    }
    for (final tokens in [
      analysis.inputTokens,
      analysis.outputTokens,
      analysis.totalTokens,
    ]) {
      if (tokens != null && tokens < 0) {
        throw ArgumentError('Token 数量不能小于 0。');
      }
    }
  }

  void _validateNonNegativeValues(Map<String, double?> values) {
    for (final entry in values.entries) {
      final value = entry.value;
      if (value != null && (!value.isFinite || value < 0)) {
        throw ArgumentError('${entry.key}必须是非负有限数值。');
      }
    }
  }

  void _validateTemperatureRange(double minValue, double maxValue) {
    if (!minValue.isFinite || !maxValue.isFinite || minValue > maxValue) {
      throw ArgumentError('温度范围无效。');
    }
  }

  static String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _placeholders(int count) {
    return List.filled(count, '?').join(', ');
  }
}

class _CatalogValue {
  const _CatalogValue(this.id, this.name);

  final int id;
  final String name;
}
