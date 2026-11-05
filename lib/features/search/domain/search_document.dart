enum SearchCategory {
  all('全部'),
  kitchen('厨房'),
  wardrobe('穿搭'),
  skincare('护肤'),
  calendar('天气与日历'),
  profile('我的');

  const SearchCategory(this.label);
  final String label;
}

enum SearchKind {
  help('使用说明'),
  record('来自你的记录'),
  current('当前数据');

  const SearchKind(this.label);
  final String label;
}

class SearchDocument {
  SearchDocument({
    required this.id,
    required this.title,
    required this.category,
    required this.kind,
    required this.target,
    this.entityId = '',
    this.body = '',
    this.keywords = const [],
    this.source = 'LifeAtlas 本地记录',
    this.time = '',
    this.image = '',
    this.sourceUrl = '',
    this.question = false,
  });
  final String id,
      title,
      body,
      target,
      entityId,
      source,
      time,
      image,
      sourceUrl;
  final SearchCategory category;
  final SearchKind kind;
  final List<String> keywords;
  final bool question;
  bool get private => kind != SearchKind.help;
  String get searchable => '$title ${keywords.join(' ')} $body';

  SearchDocument withQuestion(String questionTitle) => SearchDocument(
    id: id,
    title: questionTitle,
    category: category,
    kind: kind,
    target: target,
    entityId: entityId,
    body: body,
    keywords: [title, ...keywords],
    source: source,
    time: time,
    image: image,
    sourceUrl: sourceUrl,
    question: true,
  );
}

List<SearchDocument> searchQuestions(
  Iterable<SearchDocument> documents,
  String query,
) => [
  for (final d in documents)
    if (d.question) d else if (query.trim().isNotEmpty) recordQuestion(d),
];

SearchDocument recordQuestion(SearchDocument d) =>
    d.withQuestion(switch (d.target) {
      'recipe' => '${d.title}怎么做？',
      'clothing' => '${d.title}的尺寸是多少？',
      'product' => '${d.title}的使用说明是什么？',
      'set' => '${d.title}包含哪些衣服？',
      'inventory' => '${d.title}的库存是多少？',
      _ => '查看${d.title}',
    });

String normalizeSearch(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'[\s，。？！、：；,.?!:;「」“”"（）()]'), '')
    .replaceAll('买菜', '购物')
    .replaceAll('衣柜', '衣服')
    .replaceAll('分享', '导出')
    .replaceAll('尺码', '尺寸');

/// Exact questions and entity names outrank aliases; arbitrary bigram overlap
/// alone cannot turn a loose keyword match into a factual answer.
int searchScore(SearchDocument doc, String input) {
  final query = normalizeSearch(input);
  if (query.isEmpty) {
    return doc.question ? (doc.kind == SearchKind.help ? 2 : 1) : 0;
  }
  final title = normalizeSearch(doc.title);
  if (title == query) return 1000;
  if (title.contains(query)) return 650 + query.length;
  if (query.contains(title) && title.length >= 2) return 600 + title.length;
  var score = 0;
  for (final alias in doc.keywords) {
    final key = normalizeSearch(alias);
    if (key.isEmpty) continue;
    if (key == query) {
      score += 450;
    } else if (key.length >= 2 && query.contains(key)) {
      score += 120;
    }
  }
  final words = input
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final content = normalizeSearch(doc.searchable);
  if (words.length > 1 &&
      words.every((w) => content.contains(normalizeSearch(w)))) {
    score += 250;
  } else if (content.contains(query)) {
    score += 80;
  }
  return score > 500 ? 500 : score;
}

List<SearchDocument> rankSearch(
  Iterable<SearchDocument> documents,
  String query, {
  SearchCategory category = SearchCategory.all,
  bool? questions,
}) {
  final scored = [
    for (final doc in documents)
      if ((category == SearchCategory.all || doc.category == category) &&
          (questions == null || doc.question == questions))
        (doc, searchScore(doc, query)),
  ]..removeWhere((e) => e.$2 == 0);
  scored.sort((a, b) {
    final order = b.$2.compareTo(a.$2);
    return order != 0 ? order : a.$1.id.compareTo(b.$1.id);
  });
  return scored.map((e) => e.$1).toList();
}

/// Only a single exact question/entity match may be answered automatically.
SearchDocument? exactSearchAnswer(List<SearchDocument> matches, String query) {
  if (normalizeSearch(query).isEmpty) return null;
  final exact = matches
      .where((d) => normalizeSearch(d.title) == normalizeSearch(query))
      .toList();
  return exact.length == 1 ? exact.single : null;
}

class SearchSnapshot {
  SearchSnapshot(this.documents, this.failures);
  final List<SearchDocument> documents;
  final List<String> failures;
}
