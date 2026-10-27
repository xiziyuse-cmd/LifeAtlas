const kitchenCategories = ['家常菜', '早餐', '午餐', '晚餐', '汤类', '小吃', '烘焙'];
const kitchenStages = ['腌制', '准备阶段', '炒制阶段', '炖煮阶段', '出锅前', '装盘'];

class RecipeMaterial {
  const RecipeMaterial({
    required this.name,
    required this.amount,
    required this.unit,
    this.remark = '',
    this.stage = '准备阶段',
    this.sort = 1,
  });
  final String name, unit, remark, stage;
  final double amount;
  final int sort;
  Map<String, Object?> toMap() => {
    'name': name,
    'amount': amount,
    'unit': unit,
    'remark': remark,
    'stage': stage,
    'sort': sort,
  };
  factory RecipeMaterial.fromMap(Map<String, Object?> m) => RecipeMaterial(
    name: m['name'] as String,
    amount: (m['amount'] as num).toDouble(),
    unit: m['unit'] as String,
    remark: m['remark'] as String? ?? '',
    stage: m['stage'] as String? ?? '准备阶段',
    sort: m['sort'] as int? ?? 1,
  );
  String get quantity =>
      '${amount == amount.roundToDouble() ? amount.toInt() : amount}$unit';
}

class RecipeStep {
  const RecipeStep({
    required this.name,
    required this.content,
    required this.duration,
    this.parallelWithPrevious = false,
    this.materials = const [],
    this.seasonings = const [],
    this.image = '',
    this.video = '',
  });
  final String name, content, image, video;
  final int duration;
  final bool parallelWithPrevious;
  final List<String> materials, seasonings;
  Map<String, Object?> toMap() => {
    'name': name,
    'content': content,
    'duration': duration,
    'parallelWithPrevious': parallelWithPrevious,
    'materials': materials,
    'seasonings': seasonings,
    'image': image,
    'video': video,
  };
  factory RecipeStep.fromMap(Map<String, Object?> m) => RecipeStep(
    name: m['name'] as String,
    content: m['content'] as String,
    duration: m['duration'] as int,
    parallelWithPrevious: m['parallelWithPrevious'] == true,
    materials: List<String>.from(m['materials'] as List? ?? []),
    seasonings: List<String>.from(m['seasonings'] as List? ?? []),
    image: m['image'] as String? ?? '',
    video: m['video'] as String? ?? '',
  );

  RecipeStep copyWith({bool? parallelWithPrevious}) => RecipeStep(
    name: name,
    content: content,
    duration: duration,
    parallelWithPrevious: parallelWithPrevious ?? this.parallelWithPrevious,
    materials: materials,
    seasonings: seasonings,
    image: image,
    video: video,
  );
}

List<List<RecipeStep>> recipeStepGroups(List<RecipeStep> steps) {
  final groups = <List<RecipeStep>>[];
  for (final step in steps) {
    if (groups.isEmpty || !step.parallelWithPrevious) {
      groups.add([step]);
    } else {
      groups.last.add(step);
    }
  }
  return groups;
}

int recipeDuration(List<RecipeStep> steps) => recipeStepGroups(steps).fold(
  0,
  (total, group) =>
      total +
      group.fold<int>(
        0,
        (longest, step) => step.duration > longest ? step.duration : longest,
      ),
);

class Recipe {
  const Recipe({
    this.id,
    required this.name,
    this.image = '',
    this.categories = const ['家常菜'],
    this.difficulty = '简单',
    this.cookTime = 20,
    this.sourceType = 'personal',
    this.materials = const [],
    this.seasonings = const [],
    this.steps = const [],
    this.cookCount = 0,
  });
  final int? id;
  final String name, image, difficulty, sourceType;
  final List<String> categories;
  final int cookTime, cookCount;
  final List<RecipeMaterial> materials, seasonings;
  final List<RecipeStep> steps;
  int get totalDuration => recipeDuration(steps);
  Map<String, Object?> toMap() => {
    'name': name,
    'image': image,
    'categories': categories,
    'difficulty': difficulty,
    'cookTime': totalDuration,
    'materials': materials.map((e) => e.toMap()).toList(),
    'seasonings': seasonings.map((e) => e.toMap()).toList(),
    'steps': steps.map((e) => e.toMap()).toList(),
  };
  factory Recipe.fromMap(
    Map<String, Object?> m, {
    int? id,
    String sourceType = 'ai',
    int cookCount = 0,
  }) => Recipe(
    id: id,
    name: m['name'] as String,
    image: m['image'] as String? ?? '',
    categories: List<String>.from(m['categories'] as List? ?? ['家常菜']),
    difficulty: m['difficulty'] as String? ?? '简单',
    cookTime: m['cookTime'] as int,
    sourceType: sourceType,
    cookCount: cookCount,
    materials: (m['materials'] as List)
        .map((e) => RecipeMaterial.fromMap(Map<String, Object?>.from(e as Map)))
        .toList(),
    seasonings: (m['seasonings'] as List)
        .map((e) => RecipeMaterial.fromMap(Map<String, Object?>.from(e as Map)))
        .toList(),
    steps: (m['steps'] as List)
        .map((e) => RecipeStep.fromMap(Map<String, Object?>.from(e as Map)))
        .toList(),
  );
  void validate() {
    if (name.trim().isEmpty ||
        totalDuration <= 0 ||
        categories.isEmpty ||
        categories.any((c) => c.trim().isEmpty) ||
        (materials.isEmpty && seasonings.isEmpty) ||
        steps.isEmpty) {
      throw const FormatException('请填写菜名、分类、至少一项食材或调料，以及一个有效耗时的步骤');
    }
    for (final m in [...materials, ...seasonings]) {
      if (m.name.trim().isEmpty ||
          m.unit.trim().isEmpty ||
          !m.amount.isFinite ||
          m.amount <= 0 ||
          m.sort < 1) {
        throw const FormatException('食材和调料需要名称、正数用量、单位及正整数顺序');
      }
    }
    if (seasonings.any((s) => !kitchenStages.contains(s.stage)) ||
        materials.map((m) => m.name).toSet().length != materials.length ||
        seasonings.map((m) => m.name).toSet().length != seasonings.length) {
      throw const FormatException('请检查调料阶段；食材、调料名称不可重复');
    }
    for (final s in steps) {
      if (s.name.trim().isEmpty ||
          s.content.trim().isEmpty ||
          s.duration < 0 ||
          s.materials.any((n) => !materials.any((m) => m.name == n)) ||
          s.seasonings.any((n) => !seasonings.any((m) => m.name == n))) {
        throw const FormatException('请检查步骤名称、描述、耗时及使用食材/调料');
      }
    }
  }
}

class InventoryItem {
  const InventoryItem({
    this.id,
    required this.name,
    required this.amount,
    required this.unit,
    this.remark = '',
    this.expireDate,
    this.purchaseDate,
    this.shelfLifeDays,
    required this.updatedAt,
  });
  final int? id;
  final String name, unit, remark;
  final double amount;
  final DateTime? expireDate, purchaseDate;
  final int? shelfLifeDays;
  final DateTime updatedAt;
  Map<String, Object?> toMap() => {
    'name': name,
    'amount': amount,
    'unit': unit,
    'remark': remark,
    'expire_date': expireDate?.toIso8601String(),
    'purchase_date': purchaseDate?.toIso8601String(),
    'shelf_life_days': shelfLifeDays,
    'update_time': updatedAt.toIso8601String(),
  };
  factory InventoryItem.fromMap(Map<String, Object?> m) => InventoryItem(
    id: m['id'] as int,
    name: m['name'] as String,
    amount: (m['amount'] as num).toDouble(),
    unit: m['unit'] as String,
    remark: m['remark'] as String,
    expireDate: DateTime.tryParse(m['expire_date'] as String? ?? ''),
    purchaseDate: DateTime.tryParse(m['purchase_date'] as String? ?? ''),
    shelfLifeDays: m['shelf_life_days'] as int?,
    updatedAt: DateTime.parse(m['update_time'] as String),
  );

  int? remainingDays([DateTime? now]) {
    if (expireDate == null) return null;
    final today = DateTime.parse(kitchenDate(now ?? DateTime.now()));
    final expiry = DateTime.parse(kitchenDate(expireDate!));
    return expiry.difference(today).inDays;
  }

  InventoryFreshness get freshness {
    final days = remainingDays();
    if (days == null) return InventoryFreshness.unknown;
    if (days < 0) return InventoryFreshness.expired;
    if (days == 0) return InventoryFreshness.today;
    if (days <= 3) return InventoryFreshness.nearExpiry;
    return InventoryFreshness.fresh;
  }
}

enum InventoryFreshness { fresh, nearExpiry, today, expired, unknown }

class FoodBaseInfo {
  const FoodBaseInfo({
    required this.name,
    required this.category,
    required this.defaultShelfLife,
    required this.storageType,
  });
  final String name, category, storageType;
  final int defaultShelfLife;
  factory FoodBaseInfo.fromMap(Map<String, Object?> m) => FoodBaseInfo(
    name: m['name'] as String,
    category: m['category'] as String,
    defaultShelfLife: m['default_shelf_life'] as int,
    storageType: m['storage_type'] as String,
  );
}

class CookingRecord {
  const CookingRecord({
    this.id,
    required this.recipeId,
    required this.recipeName,
    required this.date,
    this.image = '',
    this.score = 5,
    this.remark = '',
  });
  final int? id;
  final int recipeId, score;
  final String recipeName, image, remark;
  final DateTime date;
}

String kitchenDate(DateTime value) => value.toIso8601String().split('T').first;

List<RecipeStep> stepsFromSeasonings(List<RecipeMaterial> seasonings) {
  final sorted = [...seasonings]..sort((a, b) => a.sort.compareTo(b.sort));
  return [
    for (final stage in kitchenStages)
      if (sorted.any((s) => s.stage == stage))
        RecipeStep(
          name: stage,
          duration: 0,
          content: sorted
              .where((s) => s.stage == stage)
              .map((s) => '${s.sort}. 加入${s.name} ${s.quantity}')
              .join('\n'),
          seasonings: sorted
              .where((s) => s.stage == stage)
              .map((s) => s.name)
              .toList(),
        ),
  ];
}
