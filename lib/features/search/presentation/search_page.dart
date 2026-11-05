import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../kitchen/domain/kitchen_export.dart';
import '../../kitchen/presentation/kitchen_export_page.dart';
import '../data/search_repository.dart';
import '../domain/search_document.dart';

typedef SearchSourceOpener =
    Future<void> Function(BuildContext context, SearchDocument document);

class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({
    super.key,
    required this.repository,
    required this.openSource,
    required this.enabled,
    this.autofocus = true,
  });
  final SearchRepository repository;
  final SearchSourceOpener openSource;
  final bool Function(SearchCategory) enabled;
  final bool autofocus;
  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage>
    with WidgetsBindingObserver {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  SearchSnapshot _snapshot = SearchSnapshot([], []);
  SearchCategory _category = SearchCategory.all;
  SearchDocument? _answer;
  String _text = '', _error = '';
  bool _loading = true, _answerLoading = false, _hidden = false;
  int _loadEpoch = 0, _answerEpoch = 0;
  ModalRoute<dynamic>? _route;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _query.addListener(_changed);
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route ??= ModalRoute.of(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _query.dispose();
    _scroll.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _hidden = true;
      ++_loadEpoch;
      ++_answerEpoch;
      _debounce?.cancel();
      _query.clear();
      _text = '';
      _answer = null;
      _error = '';
      _snapshot = SearchSnapshot([], []);
      _answerLoading = false;
      _loading = false;
      if (mounted) {
        Navigator.of(
          context,
        ).popUntil((route) => route == _route || route.isFirst);
        setState(() {});
      }
    } else if (_hidden) {
      _hidden = false;
      _load();
    }
  }

  Future<void> _load() async {
    final epoch = ++_loadEpoch;
    setState(() {
      _loading = true;
      _answer = null;
      _error = '';
      ++_answerEpoch;
      _answerLoading = false;
    });
    final result = await widget.repository.load();
    if (!mounted || epoch != _loadEpoch || _hidden) return;
    setState(() {
      _snapshot = result;
      _loading = false;
    });
  }

  void _changed() {
    _debounce?.cancel();
    ++_answerEpoch;
    if (_hidden) return;
    setState(() {
      _answer = null;
      _answerLoading = false;
      _error = '';
    });
    if (_query.value.composing.isValid && !_query.value.composing.isCollapsed) {
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted && !_hidden) {
        setState(() {
          _text = _query.text.trim();
          _answer = null;
          _answerLoading = false;
          _error = '';
        });
      }
    });
  }

  Future<void> _submit() async {
    _debounce?.cancel();
    FocusScope.of(context).unfocus();
    setState(() {
      _text = _query.text.trim();
      _answer = null;
      _error = '';
      _answerLoading = false;
      ++_answerEpoch;
    });
    final exact = exactSearchAnswer(
      rankSearch(
        [
          ..._snapshot.documents,
          ...searchQuestions(
            _snapshot.documents,
            _text,
          ).where((d) => d.kind == SearchKind.record),
        ],
        _text,
        category: _category,
      ),
      _text,
    );
    if (exact != null) await _select(exact);
  }

  Future<void> _select(SearchDocument d) async {
    _debounce?.cancel();
    FocusScope.of(context).unfocus();
    final epoch = ++_answerEpoch;
    setState(() {
      _answer = null;
      _error = '';
      _answerLoading = true;
    });
    try {
      final answer = await widget.repository.resolve(d);
      if (mounted && epoch == _answerEpoch && !_hidden) {
        setState(() => _answer = answer);
      }
    } catch (_) {
      if (mounted && epoch == _answerEpoch) {
        setState(() => _error = '答案暂不可用，原内容可能已变更或网络请求失败。请重试。');
      }
    } finally {
      if (mounted && epoch == _answerEpoch) {
        setState(() => _answerLoading = false);
      }
    }
  }

  Future<void> _detail(SearchDocument d) async {
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchAnswerPage(
          document: d,
          repository: widget.repository,
          openSource: widget.openSource,
        ),
      ),
    );
    if (mounted && !_hidden) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final questions = rankSearch(
      searchQuestions(_snapshot.documents, _text),
      _text,
      category: _category,
      questions: true,
    ).take(3).toList();
    final results = _text.isEmpty
        ? <SearchDocument>[]
        : rankSearch(
            _snapshot.documents,
            _text,
            category: _category,
            questions: false,
          );
    return Scaffold(
      appBar: AppBar(title: const Text('全局搜索')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('global-search-input'),
                      controller: _query,
                      autofocus: widget.autofocus,
                      maxLength: 200,
                      textInputAction: TextInputAction.search,
                      keyboardType: TextInputType.text,
                      autocorrect: true,
                      enableSuggestions: true,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: '搜索内容，或问一个问题',
                        counterText: '',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          tooltip: '清空',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _query.clear();
                            _submit();
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _submit, child: const Text('搜索')),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final c in SearchCategory.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c.label),
                        selected: _category == c,
                        onSelected: (_) {
                          setState(() {
                            _category = c;
                            _answer = null;
                            _error = '';
                            _answerLoading = false;
                            ++_answerEpoch;
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_snapshot.failures.isNotEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_snapshot.failures.join('、')}加载失败，其他内容仍可搜索',
                              ),
                              TextButton(
                                onPressed: _load,
                                child: const Text('重新加载'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Text(
                      _text.isEmpty ? '常见问题' : '你可能想问',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final q in questions)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(q.title),
                        subtitle: Text(
                          '${q.category.label} · ${q.kind.label}${widget.enabled(q.category) ? '' : ' · 板块已关闭'}${q.entityId.isEmpty ? '' : '\n${q.body.split('\n').first}'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _select(q),
                      ),
                    if (_answerLoading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: LinearProgressIndicator(),
                      ),
                    if (_error.isNotEmpty) Text(_error),
                    if (_answer case final answer?)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${answer.category.label} · ${answer.kind.label}',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                answer.title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                answer.body,
                                maxLines: 6,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                answer.source,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              TextButton(
                                onPressed: () => _detail(answer),
                                child: const Text('查看完整答案 / 导出图片'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_text.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        '相关内容（${results.length}）',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (results.isEmpty && questions.isEmpty && !_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text('没有找到相关内容，试试其他关键词或分类。'),
                        ),
                      for (final d in results)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(d.title),
                          subtitle: Text(
                            '${d.category.label} · ${d.kind.label}${widget.enabled(d.category) ? '' : ' · 板块已关闭'}\n${d.body}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _detail(d),
                        ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('搜索菜谱、衣服、护肤计划和日历记录。\n身材数值需到「我的身材」解锁查看。'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchAnswerPage extends StatefulWidget {
  const SearchAnswerPage({
    super.key,
    required this.document,
    required this.repository,
    required this.openSource,
  });
  final SearchDocument document;
  final SearchRepository repository;
  final SearchSourceOpener openSource;
  @override
  State<SearchAnswerPage> createState() => _SearchAnswerPageState();
}

class _SearchAnswerPageState extends State<SearchAnswerPage> {
  SearchDocument? _document;
  String _error = '';
  bool _busy = true;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<SearchDocument?> _refresh() async {
    setState(() {
      _busy = true;
      _error = '';
      _document = null;
    });
    try {
      final d = await widget.repository.resolve(widget.document);
      if (!mounted) return null;
      setState(() => _document = d);
      return d;
    } catch (_) {
      if (mounted) setState(() => _error = '内容已变更或暂不可用，请重试或返回重新搜索。');
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    final d = await _refresh();
    if (d == null || !mounted) return;
    if (d.private) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('导出个人记录'),
          content: const Text('图片包含你的个人记录。请确认后再分享。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('继续'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    final document = searchAnswerExport(d);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => KitchenExportPage(document: document),
      ),
    );
  }

  Future<void> _open() async {
    final d = await _refresh();
    if (d == null || !mounted) return;
    try {
      await widget.openSource(context, d);
      if (mounted) await _refresh();
    } catch (_) {
      if (mounted) setState(() => _error = '原内容无法打开，请返回重新搜索或重试。');
    }
  }

  Future<void> _link(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return;
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('link');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('来源链接暂时无法打开')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('答案详情')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error.isNotEmpty) ...[
            Text(_error),
            TextButton(onPressed: _refresh, child: const Text('重试')),
          ],
          if (_document case final d?) ...[
            Text(
              '${d.category.label} · ${d.kind.label}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            Text(d.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            SelectableText(d.body),
            const SizedBox(height: 24),
            Text('来源：${d.source}'),
            if (d.time.isNotEmpty) Text('数据/更新时间：${d.time}'),
            if (Uri.tryParse(d.sourceUrl)?.scheme == 'https')
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _link(d.sourceUrl),
                  child: const Text('查看来源官网'),
                ),
              ),
            const Divider(height: 32),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _open,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('打开原内容'),
                ),
                FilledButton.icon(
                  key: const ValueKey('search-export-button'),
                  onPressed: _busy ? null : _export,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('导出图片'),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

KitchenExport searchAnswerExport(SearchDocument d) => KitchenExport(
  title: d.title,
  image: d.image,
  label: 'LifeAtlas · 全局搜索',
  pageTitle: d.title,
  pageNote: d.source == '和风天气' ? '和风天气 · qweather.com' : d.kind.label,
  sections: [
    '${d.category.label} · ${d.kind.label}',
    d.body,
    '来源：${d.source}${d.sourceUrl.isEmpty ? '' : '\n${d.sourceUrl}'}${d.time.isEmpty ? '' : '\n数据/更新时间：${d.time}'}',
  ],
);
