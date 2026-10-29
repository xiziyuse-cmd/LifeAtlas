import 'package:flutter/material.dart';

import '../../domain/models/clothing_item.dart';
import '../../domain/models/outfit_set.dart';
import '../wardrobe_keys.dart';
import 'local_clothing_image.dart';

class OutfitSetCarouselCard extends StatefulWidget {
  const OutfitSetCarouselCard({
    super.key,
    required this.outfitSet,
    required this.items,
    required this.onItemTap,
    this.isRecording = false,
    this.selectedItemIds = const {},
    this.onSelectionChanged,
  });

  final OutfitSet outfitSet;
  final List<ClothingItem> items;
  final ValueChanged<ClothingItem> onItemTap;
  final bool isRecording;
  final Set<int> selectedItemIds;
  final void Function(int id, bool selected)? onSelectionChanged;

  @override
  State<OutfitSetCarouselCard> createState() => _OutfitSetCarouselCardState();
}

class _OutfitSetCarouselCardState extends State<OutfitSetCarouselCard> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final setId = widget.outfitSet.id;
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      key: setId == null ? null : WardrobeKeys.outfitSetCard(setId),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
            child: Row(
              children: [
                Icon(
                  Icons.style_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.outfitSet.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text('${_currentPage + 1}/${widget.items.length}'),
              ],
            ),
          ),
          SizedBox(
            height: 278,
            child: PageView.builder(
              itemCount: widget.items.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final itemId = item.id;
                final selected =
                    itemId != null && widget.selectedItemIds.contains(itemId);
                return InkWell(
                  key: setId == null || itemId == null
                      ? null
                      : WardrobeKeys.outfitSetItem(setId, itemId),
                  onTap: widget.isRecording && itemId != null
                      ? () => widget.onSelectionChanged?.call(itemId, !selected)
                      : () => widget.onItemTap(item),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          LocalClothingImage(
                            imagePath: item.imagePath,
                            width: double.infinity,
                            height: 196,
                            semanticLabel: item.name,
                          ),
                          if (widget.isRecording && itemId != null)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Checkbox(
                                key: WardrobeKeys.clothingSelection(itemId),
                                value: selected,
                                onChanged: (value) {
                                  widget.onSelectionChanged?.call(
                                    itemId,
                                    value ?? false,
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              [
                                ...item.seasonTags,
                                ?item.category,
                                ?item.brand,
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
