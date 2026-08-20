import 'package:flutter/material.dart';

import '../../domain/models/clothing_item.dart';
import '../wardrobe_keys.dart';
import 'local_clothing_image.dart';

class ClothingCard extends StatelessWidget {
  const ClothingCard({
    super.key,
    required this.item,
    required this.onTap,
    this.isRecording = false,
    this.isSelected = false,
    this.onSelectionChanged,
    this.margin = EdgeInsets.zero,
  });

  final ClothingItem item;
  final VoidCallback onTap;
  final bool isRecording;
  final bool isSelected;
  final ValueChanged<bool>? onSelectionChanged;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final itemId = item.id;
    return Card(
      key: itemId == null ? null : WardrobeKeys.clothingCard(itemId),
      margin: margin,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isRecording
            ? () => onSelectionChanged?.call(!isSelected)
            : onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                LocalClothingImage(
                  imagePath: item.imagePath,
                  width: double.infinity,
                  height: 190,
                ),
                if (isRecording)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Semantics(
                      selected: isSelected,
                      label: '选择${item.name}',
                      child: Checkbox(
                        key: itemId == null
                            ? null
                            : WardrobeKeys.clothingSelection(itemId),
                        value: isSelected,
                        onChanged: (value) {
                          onSelectionChanged?.call(value ?? false);
                        },
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_tags(item).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in _tags(item))
                          Chip(
                            label: Text(tag),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                  ],
                  if (_summary(item).isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Text(
                      _summary(item).join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<String> _tags(ClothingItem item) => [
    ...item.seasonTags,
    if (item.category case final category? when category.isNotEmpty) category,
    if (item.brand case final brand? when brand.isNotEmpty) brand,
  ];

  static List<String> _summary(ClothingItem item) => [
    if (item.material case final material? when material.isNotEmpty)
      '材质 $material',
    if (item.size case final size? when size.isNotEmpty) '尺码 $size',
    if (item.clothingLength case final length?)
      '衣长 ${_formatNumber(length)} cm',
    if (item.trouserLength case final length?) '裤长 ${_formatNumber(length)} cm',
  ];

  static String _formatNumber(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
