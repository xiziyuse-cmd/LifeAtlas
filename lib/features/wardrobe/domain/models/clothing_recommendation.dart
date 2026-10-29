import 'clothing_item.dart';

class ClothingRecommendation {
  const ClothingRecommendation({
    required this.item,
    required this.isFullMatch,
    required this.coverageRatio,
  });

  final ClothingItem item;
  final bool isFullMatch;
  final double coverageRatio;
}
