import 'package:flutter/material.dart';

import '../../domain/models/clothing_item.dart';
import '../../domain/models/clothing_parameter.dart';
import '../wardrobe_keys.dart';
import '../widgets/local_clothing_image.dart';

typedef ClothingEditor = Future<ClothingItem?> Function(ClothingItem item);
typedef ClothingDeleter = Future<bool> Function(ClothingItem item);

class ClothingDetailPage extends StatefulWidget {
  const ClothingDetailPage({
    super.key,
    required this.item,
    this.onEdit,
    this.onDelete,
  });

  final ClothingItem item;
  final ClothingEditor? onEdit;
  final ClothingDeleter? onDelete;

  @override
  State<ClothingDetailPage> createState() => _ClothingDetailPageState();
}

class _ClothingDetailPageState extends State<ClothingDetailPage> {
  late ClothingItem _item;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  Future<void> _edit() async {
    final edited = await widget.onEdit?.call(_item);
    if (mounted && edited != null) {
      setState(() => _item = edited);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除衣服？'),
        content: const Text('衣服会从衣柜隐藏，但历史穿搭和穿着记忆仍会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || widget.onDelete == null) {
      return;
    }

    setState(() => _isDeleting = true);
    final deleted = await widget.onDelete!.call(_item);
    if (!mounted) {
      return;
    }
    if (deleted) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _isDeleting = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('删除失败，请稍后重试')));
  }

  @override
  Widget build(BuildContext context) {
    final itemId = _item.id;
    final parameterGroups = _parameterGroups;
    return Scaffold(
      key: itemId == null ? null : WardrobeKeys.clothingDetail(itemId),
      appBar: AppBar(
        title: const Text('衣服详情'),
        actions: [
          if (widget.onEdit != null)
            IconButton(
              key: WardrobeKeys.clothingEdit,
              tooltip: '编辑衣服',
              onPressed: _edit,
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          LocalClothingImage(
            imagePath: _item.imagePath,
            width: double.infinity,
            height: 300,
            borderRadius: BorderRadius.circular(20),
            semanticLabel: _item.name,
          ),
          const SizedBox(height: 18),
          Text(
            _item.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final tag in _tags) Chip(label: Text(tag))],
            ),
          ],
          const SizedBox(height: 16),
          _DetailSection(
            title: '衣服信息',
            rows: [
              ('颜色', _item.color),
              ('材质', _item.material),
              ('尺码', _item.size),
              ('购买价格', _price(_item.purchasePrice)),
              ('购买日期', _date(_item.purchaseDate)),
            ],
          ),
          for (final entry in parameterGroups.entries) ...[
            const SizedBox(height: 12),
            _DetailSection(title: entry.key, rows: entry.value),
          ],
          const SizedBox(height: 12),
          _DetailSection(
            title: '穿着记忆',
            rows: [
              ('穿着次数', '${_item.wearCount} 次'),
              ('最低温度', _temperature(_item.minWornTemperature)),
              ('最高温度', _temperature(_item.maxWornTemperature)),
            ],
          ),
          if (_item.notes case final notes? when notes.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _DetailSection(title: '备注', rows: [('备注', notes)]),
          ],
          if (widget.onDelete != null) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              key: WardrobeKeys.clothingDelete,
              onPressed: _isDeleting ? null : _delete,
              icon: _isDeleting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              label: Text(_isDeleting ? '删除中' : '删除衣服'),
            ),
          ],
        ],
      ),
    );
  }

  List<String> get _tags => [
    ..._item.seasonTags,
    if (_item.category case final category? when category.isNotEmpty) category,
    if (_item.brand case final brand? when brand.isNotEmpty) brand,
  ];

  Map<String, List<(String, String?)>> get _parameterGroups {
    final groups = <String, List<(String, String?)>>{};
    for (final definition in ClothingParameterCatalog.forCategory(
      _item.category,
    )) {
      final dynamicValue = _item.parameterValues[definition.key];
      final legacyValue = _legacyParameterValue(definition.key);
      final display =
          dynamicValue?.displayValue(definition) ??
          (legacyValue == null
              ? null
              : '${_number(legacyValue)} ${definition.unit ?? ''}'.trim());
      if (display == null) {
        continue;
      }
      groups.putIfAbsent(definition.group, () => []).add((
        definition.label,
        display,
      ));
    }
    return groups;
  }

  double? _legacyParameterValue(String key) => switch (key) {
    'clothing_length' => _item.clothingLength,
    'shoulder_width' => _item.shoulderWidth,
    'chest_circumference' => _item.chestCircumference,
    'sleeve_length' => _item.sleeveLength,
    'waist_circumference' => _item.waistCircumference,
    'hip_circumference' => _item.hipCircumference,
    'trouser_length' => _item.trouserLength,
    _ => null,
  };

  static String? _price(double? value) =>
      value == null ? null : '¥${_number(value)}';

  static String? _temperature(double? value) =>
      value == null ? '尚未形成记录' : '${_number(value)}℃';

  static String? _date(DateTime? value) => value == null
      ? null
      : '${value.year}-${value.month.toString().padLeft(2, '0')}-'
            '${value.day.toString().padLeft(2, '0')}';

  static String _number(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.rows});

  final String title;
  final List<(String, String?)> rows;

  @override
  Widget build(BuildContext context) {
    final visibleRows = rows.where((row) => row.$2 != null).toList();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            if (visibleRows.isEmpty)
              Text(
                '暂无数据',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (var index = 0; index < visibleRows.length; index++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 76,
                      child: Text(
                        visibleRows[index].$1,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(child: Text(visibleRows[index].$2!)),
                  ],
                ),
                if (index != visibleRows.length - 1) const Divider(height: 20),
              ],
          ],
        ),
      ),
    );
  }
}
