import '../domain/models/preorder_analysis.dart';
import '../domain/models/preorder_item.dart';

/// Provides AI-backed purchase advice for a single preorder item.
///
/// The default implementation is deliberately unavailable. Applications must
/// inject a configured implementation before an analysis can be produced or
/// persisted.
abstract interface class PreorderAnalysisService {
  bool get isConfigured;

  Future<PreorderAnalysisResult> analyze({
    required PreorderItem item,
    String? userInstruction,
  });
}

class PreorderAnalysisResult {
  const PreorderAnalysisResult({
    required this.promptVersion,
    required this.model,
    required this.resultText,
    this.resultJson,
    this.inputTokens,
    this.outputTokens,
    this.totalTokens,
  });

  final String promptVersion;
  final String model;
  final String resultText;
  final String? resultJson;
  final int? inputTokens;
  final int? outputTokens;
  final int? totalTokens;

  PreorderAnalysis toRecord({
    required int preorderItemId,
    DateTime? analyzedAt,
  }) {
    return PreorderAnalysis(
      preorderItemId: preorderItemId,
      promptVersion: promptVersion,
      model: model,
      resultText: resultText,
      resultJson: resultJson,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      totalTokens: totalTokens,
      analyzedAt: analyzedAt ?? DateTime.now(),
    );
  }
}

class UnconfiguredPreorderAnalysisService implements PreorderAnalysisService {
  const UnconfiguredPreorderAnalysisService();

  @override
  bool get isConfigured => false;

  @override
  Future<PreorderAnalysisResult> analyze({
    required PreorderItem item,
    String? userInstruction,
  }) async {
    throw const PreorderAnalysisUnavailableException();
  }
}

class PreorderAnalysisUnavailableException implements Exception {
  const PreorderAnalysisUnavailableException([this.message = 'AI 分析服务尚未配置']);

  final String message;

  @override
  String toString() => message;
}
