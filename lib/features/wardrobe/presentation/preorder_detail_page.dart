import 'package:flutter/material.dart';

import '../data/preorder_analysis_service.dart';
import '../data/wardrobe_image_service.dart';
import '../data/wardrobe_repository.dart';
import '../domain/models/preorder_analysis.dart';
import '../domain/models/preorder_item.dart';
import 'preorder_form_page.dart';
import 'preorder_keys.dart';
import 'widgets/local_clothing_image.dart';

class PreorderDetailPage extends StatefulWidget {
  const PreorderDetailPage({
    super.key,
    required this.repository,
    required this.item,
    this.imageService,
    this.analysisService = const UnconfiguredPreorderAnalysisService(),
  });

  final WardrobeRepository repository;
  final PreorderItem item;
  final WardrobeImageService? imageService;
  final PreorderAnalysisService analysisService;

  @override
  State<PreorderDetailPage> createState() => _PreorderDetailPageState();
}

class _PreorderDetailPageState extends State<PreorderDetailPage> {
  late PreorderItem _item;
  List<PreorderAnalysis> _analyses = const [];
  bool _loadingAnalyses = true;
  bool _analysing = false;
  bool _markingPurchased = false;
  Object? _analysisError;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _loadAnalyses();
  }

  @override
  Widget build(BuildContext context) {
    final itemId = _item.id;
    final fields = _detailFields(_item);

    return Scaffold(
      key: PreorderKeys.detail,
      appBar: AppBar(
        title: const Text('心仪衣服详情'),
        actions: [
          IconButton(
            key: PreorderKeys.edit,
            tooltip: '编辑',
            onPressed: _markingPurchased ? null : _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: LocalClothingImage(
                      imagePath: _item.imagePath,
                      semanticLabel: _displayName(_item),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName(_item),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (_item.brand != null || _item.category != null) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (_item.brand != null)
                                Chip(
                                  avatar: const Icon(
                                    Icons.sell_outlined,
                                    size: 18,
                                  ),
                                  label: Text(_item.brand!),
                                ),
                              if (_item.category != null)
                                Chip(
                                  avatar: const Icon(
                                    Icons.category_outlined,
                                    size: 18,
                                  ),
                                  label: Text(_item.category!),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _DetailSection(
              title: '商品信息',
              child: fields.isEmpty
                  ? const Text('暂未填写商品信息')
                  : Column(
                      children: [
                        for (var index = 0; index < fields.length; index++) ...[
                          _DetailRow(
                            label: fields[index].$1,
                            value: fields[index].$2,
                          ),
                          if (index != fields.length - 1)
                            const Divider(height: 24),
                        ],
                      ],
                    ),
            ),
            if (_item.description != null || _item.notes != null) ...[
              const SizedBox(height: 16),
              _DetailSection(
                title: '补充信息',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_item.description != null) ...[
                      Text(
                        '商品描述',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(_item.description!),
                    ],
                    if (_item.description != null && _item.notes != null)
                      const Divider(height: 24),
                    if (_item.notes != null) ...[
                      Text(
                        '我的备注',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(_item.notes!),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            _buildAnalysisSection(context),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              key: PreorderKeys.markPurchased,
              onPressed: itemId == null || _markingPurchased
                  ? null
                  : _markPurchased,
              icon: _markingPurchased
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.shopping_bag_outlined),
              label: Text(_markingPurchased ? '处理中…' : '标记为已购买'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisSection(BuildContext context) {
    final itemId = _item.id;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'AI 购买分析',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  key: itemId == null
                      ? const ValueKey('prepurchase-reanalyse-unsaved')
                      : PreorderKeys.reanalyse(itemId),
                  onPressed: itemId == null || _analysing
                      ? null
                      : () => _runAnalysis(),
                  icon: _analysing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_outlined),
                  label: Text(_analysing ? '分析中…' : '再次分析'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '分析品牌、价格、适穿温度、材质与尺寸，并对比现有衣柜。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (_loadingAnalyses)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_analysisError != null)
              _AnalysisStatus(
                icon: Icons.error_outline,
                message: '分析记录加载失败',
                actionLabel: '重试',
                onAction: _loadAnalyses,
              )
            else if (_analyses.isEmpty)
              _AnalysisStatus(
                icon: Icons.auto_awesome_outlined,
                message: widget.analysisService.isConfigured
                    ? '还没有分析记录，可以开始第一次分析。'
                    : 'AI 服务尚未配置，当前不会生成或保存模拟分析。',
              )
            else ...[
              _AnalysisResultCard(analysis: _analyses.first, latest: true),
              if (_analyses.length > 1) ...[
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text('历史分析（${_analyses.length - 1}）'),
                  children: [
                    for (final analysis in _analyses.skip(1))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AnalysisResultCard(analysis: analysis),
                      ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loadAnalyses() async {
    final itemId = _item.id;
    if (itemId == null) {
      if (mounted) {
        setState(() {
          _loadingAnalyses = false;
          _analyses = const [];
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loadingAnalyses = true;
        _analysisError = null;
      });
    }
    try {
      final analyses = await widget.repository.listPreorderAnalyses(itemId);
      if (!mounted) {
        return;
      }
      setState(() {
        _analyses = analyses;
        _loadingAnalyses = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _analysisError = error;
        _loadingAnalyses = false;
      });
    }
  }

  Future<void> _refresh() async {
    final itemId = _item.id;
    if (itemId != null) {
      final refreshed = await widget.repository.getPreorder(itemId);
      if (mounted && refreshed != null) {
        setState(() => _item = refreshed);
      }
    }
    await _loadAnalyses();
  }

  Future<void> _edit() async {
    final result = await Navigator.of(context).push<PreorderItem>(
      MaterialPageRoute(
        builder: (context) => PreorderFormPage(
          repository: widget.repository,
          imageService: widget.imageService,
          initialItem: _item,
        ),
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    final itemId = result.id;
    final refreshed = itemId == null
        ? result
        : await widget.repository.getPreorder(itemId) ?? result;
    if (mounted) {
      setState(() => _item = refreshed);
    }
  }

  Future<void> _runAnalysis({String? userInstruction}) async {
    final itemId = _item.id;
    if (itemId == null) {
      _showMessage('请先保存这件衣服');
      return;
    }
    if (!widget.analysisService.isConfigured) {
      _showMessage('AI 分析服务尚未配置，不会保存模拟结果');
      return;
    }

    setState(() => _analysing = true);
    try {
      final result = await widget.analysisService.analyze(
        item: _item,
        userInstruction: userInstruction,
      );
      await widget.repository.appendPreorderAnalysis(
        result.toRecord(preorderItemId: itemId),
      );
      await _loadAnalyses();
      if (mounted) {
        _showMessage('分析已保存');
      }
    } catch (error) {
      if (mounted) {
        _showMessage('分析失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _analysing = false);
      }
    }
  }

  Future<void> _markPurchased() async {
    final itemId = _item.id;
    if (itemId == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('标记为已购买？'),
        content: const Text('确认后，这件衣服将不再显示在预购列表中。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _markingPurchased = true);
    try {
      await widget.repository.markPreorderPurchased(itemId);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        _showMessage('操作失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _markingPurchased = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static List<(String, String)> _detailFields(PreorderItem item) {
    final fields = <(String, String)>[];
    void add(String label, Object? value, {String suffix = ''}) {
      if (value == null) {
        return;
      }
      final text = value is double ? _formatNumber(value) : value.toString();
      if (text.trim().isNotEmpty) {
        fields.add((label, '$text$suffix'));
      }
    }

    add('价格', item.price == null ? null : '¥${_formatNumber(item.price!)}');
    add('材质', item.material);
    add('尺码', item.size);
    add('衣长', item.clothingLength, suffix: ' cm');
    add('肩宽', item.shoulderWidth, suffix: ' cm');
    add('胸围', item.chestCircumference, suffix: ' cm');
    add('袖长', item.sleeveLength, suffix: ' cm');
    add('腰围', item.waistCircumference, suffix: ' cm');
    add('臀围', item.hipCircumference, suffix: ' cm');
    add('裤长', item.trouserLength, suffix: ' cm');
    add('商品链接', item.productUrl);
    return fields;
  }

  static String _displayName(PreorderItem item) {
    final name = item.name?.trim();
    return name == null || name.isEmpty ? '未命名心仪衣服' : name;
  }

  static String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value
              .toStringAsFixed(2)
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '');
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: SelectableText(value)),
      ],
    );
  }
}

class _AnalysisStatus extends StatelessWidget {
  const _AnalysisStatus({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
            if (actionLabel != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}

class _AnalysisResultCard extends StatelessWidget {
  const _AnalysisResultCard({required this.analysis, this.latest = false});

  final PreorderAnalysis analysis;
  final bool latest;

  @override
  Widget build(BuildContext context) {
    final id = analysis.id ?? analysis.analyzedAt.microsecondsSinceEpoch;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: PreorderKeys.analysis(id),
      decoration: BoxDecoration(
        color: latest
            ? colorScheme.secondaryContainer
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (latest) ...[
                  Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    latest ? '最新分析' : _formatDateTime(analysis.analyzedAt),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                if (latest)
                  Text(
                    _formatDateTime(analysis.analyzedAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(analysis.resultText),
            const SizedBox(height: 10),
            Text(
              '${analysis.model} · ${analysis.promptVersion}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }
}
