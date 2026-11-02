import 'dart:convert';

import 'kitchen_models.dart';

class ShoppingListState {
  const ShoppingListState({
    this.recipeIds = const {},
    this.prepared = const {},
    this.servings = const {},
  });

  final Set<int> recipeIds;
  final Set<String> prepared;
  final Map<int, int> servings;
  int portions(int id) => servings[id] ?? 1;

  String encode() => jsonEncode({
    'recipeIds': recipeIds.toList(),
    'prepared': prepared.toList(),
    'servings': servings.map((id, count) => MapEntry('$id', count)),
  });

  factory ShoppingListState.decode(String value) {
    final map = jsonDecode(value) as Map<String, dynamic>;
    return ShoppingListState(
      recipeIds: (map['recipeIds'] as List).cast<int>().toSet(),
      prepared: (map['prepared'] as List).cast<String>().toSet(),
      servings: {
        for (final entry in ((map['servings'] as Map?) ?? {}).entries)
          if (int.tryParse('${entry.key}') != null &&
              entry.value is int &&
              entry.value >= 1 &&
              entry.value <= 99)
            int.parse('${entry.key}'): entry.value as int,
      },
    );
  }
}

class ShoppingListItem {
  const ShoppingListItem({
    required this.name,
    required this.unit,
    required this.seasoning,
    required this.amount,
    required this.missingAmounts,
  });

  final String name, unit;
  final bool seasoning;
  final double? amount;
  final int missingAmounts;

  // Include the total so an old tick never silently covers a changed quantity.
  String get key => jsonEncode([
    seasoning,
    name.trim().toLowerCase(),
    unit,
    amount,
    missingAmounts,
  ]);

  String get quantity {
    final known = RecipeMaterial(
      name: name,
      amount: amount,
      unit: unit,
    ).quantity;
    if (missingAmounts == 0) return known;
    return known.isEmpty ? '用量待补' : '$known + 用量待补';
  }
}

List<ShoppingListItem> buildShoppingList(
  Iterable<Recipe> recipes, {
  Map<int, int> servings = const {},
}) {
  final groups = <String, ShoppingListItem>{};
  final seenIds = <int>{};
  for (final recipe in recipes) {
    if (recipe.id != null && !seenIds.add(recipe.id!)) continue;
    final portions = servings[recipe.id] ?? 1;
    if (portions < 1 || portions > 99) throw ArgumentError('份数应为1到99');
    for (final seasoning in [false, true]) {
      for (final material in seasoning ? recipe.seasonings : recipe.materials) {
        final name = material.name.trim();
        if (name.isEmpty) continue;
        final unit = material.unit.trim();
        final key = jsonEncode([seasoning, name.toLowerCase(), unit]);
        final previous = groups[key];
        final value = material.amount == null
            ? null
            : material.amount! * portions;
        groups[key] = ShoppingListItem(
          name: previous?.name ?? name,
          unit: unit,
          seasoning: seasoning,
          amount: value == null
              ? previous?.amount
              : double.parse(
                  ((previous?.amount ?? 0) + value).toStringAsPrecision(12),
                ),
          missingAmounts:
              (previous?.missingAmounts ?? 0) + (value == null ? 1 : 0),
        );
      }
    }
  }
  return [
    ...groups.values.where((item) => !item.seasoning),
    ...groups.values.where((item) => item.seasoning),
  ];
}
