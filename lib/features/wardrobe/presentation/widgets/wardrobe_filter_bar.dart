import 'package:flutter/material.dart';

import '../wardrobe_keys.dart';

class WardrobeFilterBar extends StatelessWidget {
  const WardrobeFilterBar({
    super.key,
    required this.seasons,
    required this.categories,
    required this.brands,
    required this.selectedSeason,
    required this.selectedCategory,
    required this.selectedBrand,
    required this.onSeasonChanged,
    required this.onCategoryChanged,
    required this.onBrandChanged,
    required this.onClear,
  });

  final List<String> seasons;
  final List<String> categories;
  final List<String> brands;
  final String? selectedSeason;
  final String? selectedCategory;
  final String? selectedBrand;
  final ValueChanged<String?> onSeasonChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onBrandChanged;
  final VoidCallback onClear;

  bool get _hasActiveFilter =>
      selectedSeason != null ||
      selectedCategory != null ||
      selectedBrand != null;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        height: 52,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          scrollDirection: Axis.horizontal,
          children: [
            _FilterMenu(
              key: WardrobeKeys.seasonFilter,
              label: '季节',
              value: selectedSeason,
              options: seasons,
              onChanged: onSeasonChanged,
            ),
            const SizedBox(width: 8),
            _FilterMenu(
              key: WardrobeKeys.categoryFilter,
              label: '品类',
              value: selectedCategory,
              options: categories,
              onChanged: onCategoryChanged,
            ),
            const SizedBox(width: 8),
            _FilterMenu(
              key: WardrobeKeys.brandFilter,
              label: '品牌',
              value: selectedBrand,
              options: brands,
              onChanged: onBrandChanged,
            ),
            if (_hasActiveFilter) ...[
              const SizedBox(width: 4),
              IconButton(
                key: WardrobeKeys.clearFilters,
                tooltip: '清除筛选',
                visualDensity: VisualDensity.compact,
                onPressed: onClear,
                icon: const Icon(Icons.filter_alt_off_outlined),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  static const _allValue = '__all__';

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '$label筛选',
      initialValue: value ?? _allValue,
      onSelected: (selection) {
        onChanged(selection == _allValue ? null : selection);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: _allValue, child: Text('全部')),
        for (final option in options)
          PopupMenuItem(
            value: option,
            child: Text(option, overflow: TextOverflow.ellipsis),
          ),
      ],
      child: InputChip(
        label: Text(value == null ? label : '$label：$value'),
        avatar: Icon(
          value == null ? Icons.filter_alt_outlined : Icons.filter_alt,
          size: 18,
        ),
        onPressed: null,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
