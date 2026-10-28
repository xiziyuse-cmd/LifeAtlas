class PreorderAnalysis {
  const PreorderAnalysis({
    this.id,
    required this.preorderItemId,
    required this.promptVersion,
    required this.model,
    required this.resultText,
    this.resultJson,
    this.inputTokens,
    this.outputTokens,
    this.totalTokens,
    required this.analyzedAt,
  });

  final int? id;
  final int preorderItemId;
  final String promptVersion;
  final String model;
  final String resultText;
  final String? resultJson;
  final int? inputTokens;
  final int? outputTokens;
  final int? totalTokens;
  final DateTime analyzedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'preorder_item_id': preorderItemId,
      'prompt_version': promptVersion,
      'model': model,
      'result_text': resultText,
      'result_json': resultJson,
      'input_tokens': inputTokens,
      'output_tokens': outputTokens,
      'total_tokens': totalTokens,
      'analyzed_at': analyzedAt.toIso8601String(),
    };
  }

  factory PreorderAnalysis.fromMap(Map<String, Object?> map) {
    return PreorderAnalysis(
      id: map['id'] as int?,
      preorderItemId: map['preorder_item_id'] as int,
      promptVersion: map['prompt_version'] as String,
      model: map['model'] as String,
      resultText: map['result_text'] as String,
      resultJson: map['result_json'] as String?,
      inputTokens: map['input_tokens'] as int?,
      outputTokens: map['output_tokens'] as int?,
      totalTokens: map['total_tokens'] as int?,
      analyzedAt: DateTime.parse(map['analyzed_at'] as String),
    );
  }

  PreorderAnalysis copyWith({
    int? id,
    int? preorderItemId,
    String? promptVersion,
    String? model,
    String? resultText,
    String? resultJson,
    int? inputTokens,
    int? outputTokens,
    int? totalTokens,
    DateTime? analyzedAt,
  }) {
    return PreorderAnalysis(
      id: id ?? this.id,
      preorderItemId: preorderItemId ?? this.preorderItemId,
      promptVersion: promptVersion ?? this.promptVersion,
      model: model ?? this.model,
      resultText: resultText ?? this.resultText,
      resultJson: resultJson ?? this.resultJson,
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
      totalTokens: totalTokens ?? this.totalTokens,
      analyzedAt: analyzedAt ?? this.analyzedAt,
    );
  }
}
