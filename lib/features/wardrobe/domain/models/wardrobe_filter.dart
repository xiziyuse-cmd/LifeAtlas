class WardrobeFilter {
  const WardrobeFilter({
    this.seasonTags = const {},
    this.categoryIds = const {},
    this.brandIds = const {},
  });

  final Set<String> seasonTags;
  final Set<int> categoryIds;
  final Set<int> brandIds;

  bool get isEmpty =>
      seasonTags.isEmpty && categoryIds.isEmpty && brandIds.isEmpty;
}
