import 'package:flutter/material.dart';

import '../wardrobe_keys.dart';

class WardrobeFilterBar extends StatefulWidget {
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

  @override
  State<WardrobeFilterBar> createState() => _WardrobeFilterBarState();
}

class _WardrobeFilterBarState extends State<WardrobeFilterBar> {
  bool _isExpanded = false;

  int get _activeFilterCount => [
    widget.selectedSeason,
    widget.selectedCategory,
    widget.selectedBrand,
  ].whereType<String>().length;

  @override
  Widget build(BuildContext context) {
    final activeFilterCount = _activeFilterCount;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: WardrobeKeys.filterToggle,
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    icon: Icon(
                      activeFilterCount == 0
                          ? Icons.filter_alt_outlined
                          : Icons.filter_alt,
                    ),
                    label: Text(
                      activeFilterCount == 0 ? '筛选' : '筛选（$activeFilterCount）',
                    ),
                  ),
                ),
                if (activeFilterCount > 0) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    key: WardrobeKeys.clearFilters,
                    tooltip: '清除筛选',
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onClear,
                    icon: const Icon(Icons.filter_alt_off_outlined),
                  ),
                ],
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  semanticLabel: _isExpanded ? '收起筛选条件' : '展开筛选条件',
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: SizedBox(
              key: WardrobeKeys.filterOptions,
              height: 48,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterMenu(
                    key: WardrobeKeys.seasonFilter,
                    label: '季节',
                    value: widget.selectedSeason,
                    options: widget.seasons,
                    onChanged: widget.onSeasonChanged,
                  ),
                  const SizedBox(width: 8),
                  _FilterMenu(
                    key: WardrobeKeys.categoryFilter,
                    label: '品类',
                    value: widget.selectedCategory,
                    options: widget.categories,
                    onChanged: widget.onCategoryChanged,
                  ),
                  const SizedBox(width: 8),
                  _FilterMenu(
                    key: WardrobeKeys.brandFilter,
                    label: '品牌',
                    value: widget.selectedBrand,
                    options: widget.brands,
                    onChanged: widget.onBrandChanged,
                  ),
                ],
              ),
            ),
          ),
        ],
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
