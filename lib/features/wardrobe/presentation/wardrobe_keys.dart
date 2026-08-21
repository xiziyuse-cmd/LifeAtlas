import 'package:flutter/foundation.dart';

abstract final class WardrobeKeys {
  static const page = ValueKey('wardrobe-page');
  static const loading = ValueKey('wardrobe-loading');
  static const error = ValueKey('wardrobe-error');
  static const empty = ValueKey('wardrobe-empty');

  static const seasonFilter = ValueKey('wardrobe-filter-season');
  static const categoryFilter = ValueKey('wardrobe-filter-category');
  static const brandFilter = ValueKey('wardrobe-filter-brand');
  static const filterToggle = ValueKey('wardrobe-filter-toggle');
  static const filterOptions = ValueKey('wardrobe-filter-options');
  static const clearFilters = ValueKey('wardrobe-clear-filters');

  static const addClothing = ValueKey('wardrobe-add-clothing');
  static const manageSets = ValueKey('wardrobe-manage-sets');
  static const openPreorders = ValueKey('wardrobe-open-preorders');
  static const startRecording = ValueKey('wardrobe-record-start');
  static const cancelRecording = ValueKey('wardrobe-record-cancel');
  static const confirmRecording = ValueKey('wardrobe-record-confirm');

  static const clothingForm = ValueKey('clothing-form');
  static const clothingImagePicker = ValueKey('clothing-image-picker');
  static const clothingImageAnalyze = ValueKey('clothing-image-analyze');
  static const clothingImageAnalysisStatus = ValueKey(
    'clothing-image-analysis-status',
  );
  static const clothingNameField = ValueKey('clothing-name-field');
  static const clothingCategoryField = ValueKey('clothing-category-field');
  static const clothingBrandField = ValueKey('clothing-brand-field');
  static const clothingLengthField = ValueKey('clothing-length-field');
  static const clothingShoulderWidthField = ValueKey(
    'clothing-shoulder-width-field',
  );
  static const clothingChestField = ValueKey('clothing-chest-field');
  static const clothingSleeveLengthField = ValueKey(
    'clothing-sleeve-length-field',
  );
  static const clothingWaistField = ValueKey('clothing-waist-field');
  static const clothingHipField = ValueKey('clothing-hip-field');
  static const clothingTrouserLengthField = ValueKey(
    'clothing-trouser-length-field',
  );
  static const clothingSubmit = ValueKey('clothing-submit');
  static const clothingEdit = ValueKey('clothing-edit');
  static const clothingDelete = ValueKey('clothing-delete');

  static const outfitSetForm = ValueKey('outfit-set-form');
  static const outfitSetNameField = ValueKey('outfit-set-name-field');
  static const outfitSetSubmit = ValueKey('outfit-set-submit');
  static const outfitSetAdd = ValueKey('outfit-set-add');

  static ValueKey<String> clothingCard(int id) =>
      ValueKey('wardrobe-clothing-$id');

  static ValueKey<String> clothingSelection(int id) =>
      ValueKey('wardrobe-select-$id');

  static ValueKey<String> outfitSetCard(int id) => ValueKey('wardrobe-set-$id');

  static ValueKey<String> outfitSetItem(int setId, int clothingId) =>
      ValueKey('wardrobe-set-$setId-item-$clothingId');

  static ValueKey<String> clothingDetail(int id) =>
      ValueKey('clothing-detail-$id');

  static ValueKey<String> season(String season) =>
      ValueKey('clothing-season-$season');

  static ValueKey<String> outfitSetSeason(String season) =>
      ValueKey('outfit-set-season-$season');

  static ValueKey<String> outfitSetSelection(int clothingId) =>
      ValueKey('outfit-set-select-$clothingId');
}
