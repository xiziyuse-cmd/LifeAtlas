import 'package:flutter/material.dart';

import '../../domain/models/clothing_item.dart';
import '../wardrobe_keys.dart';
import 'clothing_card.dart';

class ClothingGrid extends StatelessWidget {
  const ClothingGrid({
    super.key,
    required this.items,
    required this.isRecording,
    required this.selectedItemIds,
    required this.onSelectionChanged,
    required this.onItemTap,
  });

  final List<ClothingItem> items;
  final bool isRecording;
  final Set<int> selectedItemIds;
  final void Function(int id, bool selected) onSelectionChanged;
  final ValueChanged<ClothingItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      key: WardrobeKeys.clothingGrid,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.62,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return ClothingCard(
          item: item,
          compact: true,
          isRecording: isRecording,
          isSelected: item.id != null && selectedItemIds.contains(item.id),
          onSelectionChanged: item.id == null
              ? null
              : (selected) => onSelectionChanged(item.id!, selected),
          onTap: () => onItemTap(item),
        );
      },
    );
  }
}
