import 'package:flutter/material.dart';

import '../data/clothing_image_parameter_service.dart';
import '../data/preorder_analysis_service.dart';
import '../data/wardrobe_image_service.dart';
import '../data/wardrobe_repository.dart';
import '../domain/models/clothing_catalog.dart';
import '../domain/models/clothing_item.dart';
import '../domain/models/outfit_set.dart';
import 'pages/clothing_detail_page.dart';
import 'pages/clothing_form_page.dart';
import 'pages/outfit_sets_page.dart';
import 'preorder_page.dart';
import 'wardrobe_keys.dart';
import 'widgets/clothing_card.dart';
import 'widgets/outfit_set_carousel_card.dart';
import 'widgets/wardrobe_filter_bar.dart';

class OutfitPage extends StatefulWidget {
  const OutfitPage({
    super.key,
    this.repository,
    this.imageService,
    this.imageParameterService =
        const UnconfiguredClothingImageParameterService(),
    this.preorderAnalysisService = const UnconfiguredPreorderAnalysisService(),
    this.onDataChanged,
    this.onDailyOutfitSaved,
    this.showFemaleCategories = false,
  });

  final WardrobeRepository? repository;
  final WardrobeImageService? imageService;
  final ClothingImageParameterService imageParameterService;
  final PreorderAnalysisService preorderAnalysisService;
  final VoidCallback? onDataChanged;
  final Future<void> Function()? onDailyOutfitSaved;
  final bool showFemaleCategories;

  @override
  State<OutfitPage> createState() => _OutfitPageState();
}

class _OutfitPageState extends State<OutfitPage> {
  static const _seasons = ['春', '夏', '秋', '冬'];

  late final WardrobeRepository _repository;
  late final WardrobeImageService _imageService;

  List<ClothingItem> _items = const [];
  List<OutfitSet> _sets = const [];
  List<ClothingCategory> _categories = const [];
  List<ClothingBrand> _brands = const [];
  String? _selectedSeason;
  int? _selectedCategoryId;
  int? _selectedBrandId;
  bool _isLoading = true;
  bool _isSavingRecord = false;
  String? _loadError;
  bool _isRecording = false;
  Set<int> _selectedItemIds = {};

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? WardrobeRepository();
    _imageService = widget.imageService ?? DeviceWardrobeImageService();
    _load(showLoading: false);
  }

  @override
  void didUpdateWidget(covariant OutfitPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showFemaleCategories != widget.showFemaleCategories) {
      _selectedCategoryId = null;
      _load();
    }
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final results = await Future.wait<Object>([
        _repository.listClothing(),
        _repository.listOutfitSets(),
        _repository.listCategories(
          includeFemaleCategories: widget.showFemaleCategories,
        ),
        _repository.listBrands(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = results[0] as List<ClothingItem>;
        _sets = results[1] as List<OutfitSet>;
        _categories = results[2] as List<ClothingCategory>;
        _brands = results[3] as List<ClothingBrand>;
        _isLoading = false;
        _loadError = null;
      });
    } on Object {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = '衣柜加载失败';
        });
      }
    }
  }

  Future<void> _addClothing() async {
    final item = await Navigator.of(context).push<ClothingItem>(
      MaterialPageRoute(
        builder: (context) => ClothingFormPage(
          imageService: _imageService,
          imageParameterService: widget.imageParameterService,
          categories: _categories.map((category) => category.name).toList(),
          brands: _brands.map((brand) => brand.name).toList(),
        ),
      ),
    );
    if (!mounted || item == null) {
      return;
    }
    try {
      await _repository.createClothing(item);
      widget.onDataChanged?.call();
      await _load();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('衣服保存失败，请稍后重试')));
      }
    }
  }

  Future<ClothingItem?> _editClothing(ClothingItem item) async {
    final edited = await Navigator.of(context).push<ClothingItem>(
      MaterialPageRoute(
        builder: (context) => ClothingFormPage(
          imageService: _imageService,
          imageParameterService: widget.imageParameterService,
          initialItem: item,
          categories: _categories.map((category) => category.name).toList(),
          brands: _brands.map((brand) => brand.name).toList(),
        ),
      ),
    );
    if (!mounted || edited == null) {
      return null;
    }
    try {
      await _repository.updateClothing(edited);
      final refreshed = edited.id == null
          ? edited
          : await _repository.getClothing(edited.id!);
      widget.onDataChanged?.call();
      await _load();
      return refreshed ?? edited;
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('衣服修改失败，请稍后重试')));
      }
      return null;
    }
  }

  Future<bool> _deleteClothing(ClothingItem item) async {
    final id = item.id;
    if (id == null) {
      return false;
    }
    try {
      await _repository.softDeleteClothing(id);
      widget.onDataChanged?.call();
      await _load();
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> _openClothing(ClothingItem item) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ClothingDetailPage(
          item: item,
          onEdit: _editClothing,
          onDelete: _deleteClothing,
        ),
      ),
    );
  }

  Future<void> _openSets() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => OutfitSetsPage(
          repository: _repository,
          clothingItems: _items,
          onDataChanged: widget.onDataChanged,
        ),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  Future<void> _openPreorders() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => PreorderPage(
          repository: _repository,
          imageService: _imageService,
          analysisService: widget.preorderAnalysisService,
          onDataChanged: widget.onDataChanged,
        ),
      ),
    );
    if (mounted) {
      await _load(showLoading: false);
    }
  }

  Future<void> _startRecording() async {
    try {
      final record = await _repository.getDailyOutfit(DateTime.now());
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = true;
        _selectedItemIds = {...?record?.clothingItemIds};
      });
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法读取今天的穿搭记录')));
      }
    }
  }

  void _cancelRecording() {
    setState(() {
      _isRecording = false;
      _selectedItemIds = {};
    });
  }

  void _setSelected(int id, bool selected) {
    setState(() {
      if (selected) {
        _selectedItemIds.add(id);
      } else {
        _selectedItemIds.remove(id);
      }
    });
  }

  Future<void> _saveDailyOutfit() async {
    if (_selectedItemIds.isEmpty || _isSavingRecord) {
      return;
    }
    setState(() => _isSavingRecord = true);
    try {
      await _repository.replaceDailyOutfit(
        date: DateTime.now(),
        clothingItemIds: _selectedItemIds,
      );
      var followUpFailed = false;
      try {
        await widget.onDailyOutfitSaved?.call();
      } on Object {
        followUpFailed = true;
      }
      widget.onDataChanged?.call();
      await _load(showLoading: false);
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = false;
        _isSavingRecord = false;
        _selectedItemIds = {};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(followUpFailed ? '穿搭已保存，天气记忆稍后更新' : '已记录今天的穿搭')),
      );
    } on Object {
      if (mounted) {
        setState(() => _isSavingRecord = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('穿搭记录保存失败，请稍后重试')));
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedSeason = null;
      _selectedCategoryId = null;
      _selectedBrandId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoryName = _categories
        .where((category) => category.id == _selectedCategoryId)
        .map((category) => category.name)
        .firstOrNull;
    final brandName = _brands
        .where((brand) => brand.id == _selectedBrandId)
        .map((brand) => brand.name)
        .firstOrNull;

    return Scaffold(
      key: WardrobeKeys.page,
      body: Column(
        children: [
          WardrobeFilterBar(
            seasons: _seasons,
            categories: _categories.map((category) => category.name).toList(),
            brands: _brands.map((brand) => brand.name).toList(),
            selectedSeason: _selectedSeason,
            selectedCategory: categoryName,
            selectedBrand: brandName,
            onSeasonChanged: (value) {
              setState(() => _selectedSeason = value);
            },
            onCategoryChanged: (value) {
              setState(() {
                _selectedCategoryId = value == null
                    ? null
                    : _categories
                          .where((category) => category.name == value)
                          .map((category) => category.id)
                          .firstOrNull;
              });
            },
            onBrandChanged: (value) {
              setState(() {
                _selectedBrandId = value == null
                    ? null
                    : _brands
                          .where((brand) => brand.name == value)
                          .map((brand) => brand.id)
                          .firstOrNull;
              });
            },
            onClear: _clearFilters,
          ),
          if (_isRecording)
            _RecordingBar(
              selectedCount: _selectedItemIds.length,
              isSaving: _isSavingRecord,
              onCancel: _cancelRecording,
              onConfirm: _selectedItemIds.isEmpty ? null : _saveDailyOutfit,
            )
          else
            _ActionBar(
              onSets: _openSets,
              onPreorders: _openPreorders,
              onRecord: _startRecording,
              onAdd: _addClothing,
            ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        key: WardrobeKeys.loading,
        child: CircularProgressIndicator(),
      );
    }
    if (_loadError case final error?) {
      return Center(
        key: WardrobeKeys.error,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }

    final filteredItems = _items.where(_matchesActiveFilters).toList();
    final itemById = {for (final item in _items) ?item.id: item};
    final matchingSets = <(OutfitSet, List<ClothingItem>)>[];
    final groupedItemIds = <int>{};
    if (_selectedSeason != null) {
      for (final set in _sets) {
        if (!set.seasonTags.contains(_selectedSeason)) {
          continue;
        }
        final members = <ClothingItem>[
          for (final id in set.clothingItemIds)
            if (itemById[id] case final item?
                when _matchesCategoryAndBrand(item))
              item,
        ];
        if (members.isNotEmpty) {
          matchingSets.add((set, members));
          groupedItemIds.addAll(members.map((item) => item.id).nonNulls);
        }
      }
    }
    final standaloneItems = filteredItems
        .where((item) => item.id == null || !groupedItemIds.contains(item.id))
        .toList();

    if (matchingSets.isEmpty && standaloneItems.isEmpty) {
      return _EmptyWardrobe(
        hasFilters:
            _selectedSeason != null ||
            _selectedCategoryId != null ||
            _selectedBrandId != null,
        onClearFilters: _clearFilters,
        onAdd: _addClothing,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
      children: [
        if (matchingSets.isNotEmpty) ...[
          const _SectionLabel(label: '套装'),
          for (final entry in matchingSets) ...[
            OutfitSetCarouselCard(
              outfitSet: entry.$1,
              items: entry.$2,
              isRecording: _isRecording,
              selectedItemIds: _selectedItemIds,
              onSelectionChanged: _setSelected,
              onItemTap: _openClothing,
            ),
            const SizedBox(height: 12),
          ],
        ],
        if (standaloneItems.isNotEmpty) ...[
          if (matchingSets.isNotEmpty) const _SectionLabel(label: '单件'),
          for (final item in standaloneItems) ...[
            ClothingCard(
              item: item,
              isRecording: _isRecording,
              isSelected: item.id != null && _selectedItemIds.contains(item.id),
              onSelectionChanged: item.id == null
                  ? null
                  : (selected) => _setSelected(item.id!, selected),
              onTap: () => _openClothing(item),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }

  bool _matchesActiveFilters(ClothingItem item) {
    return (_selectedSeason == null ||
            item.seasonTags.contains(_selectedSeason)) &&
        _matchesCategoryAndBrand(item);
  }

  bool _matchesCategoryAndBrand(ClothingItem item) {
    return (_selectedCategoryId == null ||
            item.categoryId == _selectedCategoryId) &&
        (_selectedBrandId == null || item.brandId == _selectedBrandId);
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.onSets,
    required this.onPreorders,
    required this.onRecord,
    required this.onAdd,
  });

  final VoidCallback onSets;
  final VoidCallback onPreorders;
  final VoidCallback onRecord;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        scrollDirection: Axis.horizontal,
        children: [
          OutlinedButton.icon(
            key: WardrobeKeys.manageSets,
            onPressed: onSets,
            icon: const Icon(Icons.style_outlined),
            label: const Text('套装'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            key: WardrobeKeys.openPreorders,
            onPressed: onPreorders,
            icon: const Icon(Icons.favorite_border),
            label: const Text('预购'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            key: WardrobeKeys.startRecording,
            onPressed: onRecord,
            icon: const Icon(Icons.today_outlined),
            label: const Text('记录'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            key: WardrobeKeys.addClothing,
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('新增'),
          ),
        ],
      ),
    );
  }
}

class _RecordingBar extends StatelessWidget {
  const _RecordingBar({
    required this.selectedCount,
    required this.isSaving,
    required this.onCancel,
    required this.onConfirm,
  });

  final int selectedCount;
  final bool isSaving;
  final VoidCallback onCancel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
      child: Row(
        children: [
          TextButton(
            key: WardrobeKeys.cancelRecording,
            onPressed: isSaving ? null : onCancel,
            child: const Text('取消'),
          ),
          Expanded(child: Center(child: Text('已选 $selectedCount 件'))),
          FilledButton(
            key: WardrobeKeys.confirmRecording,
            onPressed: isSaving ? null : onConfirm,
            child: isSaving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('确定'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _EmptyWardrobe extends StatelessWidget {
  const _EmptyWardrobe({
    required this.hasFilters,
    required this.onClearFilters,
    required this.onAdd,
  });

  final bool hasFilters;
  final VoidCallback onClearFilters;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: WardrobeKeys.empty,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.checkroom_outlined, size: 56),
            const SizedBox(height: 12),
            Text(hasFilters ? '没有符合筛选条件的衣服' : '衣柜还是空的'),
            const SizedBox(height: 12),
            if (hasFilters)
              OutlinedButton(
                onPressed: onClearFilters,
                child: const Text('清除筛选'),
              )
            else
              FilledButton(onPressed: onAdd, child: const Text('新增第一件衣服')),
          ],
        ),
      ),
    );
  }
}
