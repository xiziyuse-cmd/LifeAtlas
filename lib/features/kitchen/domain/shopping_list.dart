import 'dart:convert';

import 'kitchen_models.dart';

class ShoppingListState {
  const ShoppingListState({
    this.recipeIds = const {},
    this.prepared = const {},
  });

  final Set<int> recipeIds;
  final Set<String> prepared;

  String encode() => jsonEncode({
    'recipeIds': recipeIds.toList(),
    'prepared': prepared.toList(),
  });

  factory ShoppingListState.decode(String value) {
    final map = jsonDecode(value) as Map<String, dynamic>;
    return ShoppingListState(
      recipeIds: (map['recipeIds'] as List).cast<int>().toSet(),
      prepared: (map['prepared'] as List).cast<String>().toSet(),
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

List<ShoppingListItem> buildShoppingList(Iterable<Recipe> recipes) {
  final groups = <String, ShoppingListItem>{};
  final seenIds = <int>{};
  for (final recipe in recipes) {
    if (recipe.id != null && !seenIds.add(recipe.id!)) continue;
    for (final seasoning in [false, true]) {
      for (final material in seasoning ? recipe.seasonings : recipe.materials) {
        final name = material.name.trim();
        if (name.isEmpty) continue;
        final unit = material.unit.trim();
        final key = jsonEncode([seasoning, name.toLowerCase(), unit]);
        final previous = groups[key];
        final value = material.amount;
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
