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
    this.compact = false,
  });

  final ClothingItem item;
  final VoidCallback onTap;
  final bool isRecording;
  final bool isSelected;
  final ValueChanged<bool>? onSelectionChanged;
  final EdgeInsetsGeometry margin;
  final bool compact;

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
        child: compact ? _buildCompact(context) : _buildRegular(context),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              LocalClothingImage(
                imagePath: item.imagePath,
                width: double.infinity,
                height: double.infinity,
              ),
              if (isRecording)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Semantics(
                    selected: isSelected,
                    label: '选择${item.name}',
                    child: Checkbox(
                      key: item.id == null
                          ? null
                          : WardrobeKeys.clothingSelection(item.id!),
                      value: isSelected,
                      onChanged: (value) {
                        onSelectionChanged?.call(value ?? false);
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegular(BuildContext context) {
    final itemId = item.id;
    return Column(
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
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
