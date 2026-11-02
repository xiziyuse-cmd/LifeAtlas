import 'package:flutter/foundation.dart';

abstract final class PreorderKeys {
  static const page = ValueKey('prepurchase-page');
  static const loading = ValueKey('prepurchase-loading');
  static const error = ValueKey('prepurchase-error');
  static const empty = ValueKey('prepurchase-empty');
  static const add = ValueKey('prepurchase-add');
  static const aiInput = ValueKey('prepurchase-ai-input');
  static const aiSend = ValueKey('prepurchase-ai-send');
  static const form = ValueKey('prepurchase-form');
  static const imagePicker = ValueKey('prepurchase-image-picker');
  static const nameField = ValueKey('prepurchase-name-field');
  static const submit = ValueKey('prepurchase-submit');
  static const detail = ValueKey('prepurchase-detail');
  static const edit = ValueKey('prepurchase-edit');
  static const markPurchased = ValueKey('prepurchase-mark-purchased');

  static ValueKey<String> item(int id) => ValueKey('prepurchase-item-$id');

  static ValueKey<String> selectForAnalysis(int id) =>
      ValueKey('prepurchase-select-$id');

  static ValueKey<String> reanalyse(int id) =>
      ValueKey('prepurchase-reanalyse-$id');

  static ValueKey<String> analysis(int id) =>
      ValueKey('prepurchase-analysis-$id');
}
