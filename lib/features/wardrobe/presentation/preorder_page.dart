import 'package:flutter/material.dart';

import '../data/preorder_analysis_service.dart';
import '../data/wardrobe_image_service.dart';
import '../data/wardrobe_repository.dart';
import '../domain/models/preorder_item.dart';
import 'preorder_detail_page.dart';
import 'preorder_form_page.dart';
import 'preorder_keys.dart';
import 'widgets/local_clothing_image.dart';

class PreorderPage extends StatefulWidget {
  const PreorderPage({
    super.key,
    required this.repository,
    this.imageService,
    this.analysisService = const UnconfiguredPreorderAnalysisService(),
    this.onDataChanged,
  });

  final WardrobeRepository repository;
  final WardrobeImageService? imageService;
  final PreorderAnalysisService analysisService;
  final VoidCallback? onDataChanged;

  @override
  State<PreorderPage> createState() => _PreorderPageState();
}

class _PreorderPageState extends State<PreorderPage> {
  final _instructionController = TextEditingController();

  List<PreorderItem> _items = const [];
  int? _selectedItemId;
  bool _loading = true;
  bool _analysing = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _instructionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = _selectedItem;

    return Scaffold(
      key: PreorderKeys.page,
      appBar: AppBar(
        title: const Text('预购衣服'),
        actions: [
          IconButton(
            key: PreorderKeys.add,
            tooltip: '添加心仪衣服',
            onPressed: _add,
            icon: const Icon(Icons.add_photo_alternate_outlined),
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildContent()),
          _AnalysisComposer(
            selectedItem: selectedItem,
            controller: _instructionController,
            analysing: _analysing,
            serviceConfigured: widget.analysisService.isConfigured,
            onClearSelection: () => setState(() => _selectedItemId = null),
            onSend: _analysing ? null : _runAnalysis,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        key: PreorderKeys.loading,
        child: CircularProgressIndicator(),
      );
    }
    if (_error != null) {
      return _MessageScrollView(
        key: PreorderKeys.error,
        icon: Icons.error_outline,
        title: '预购衣服加载失败',
        message: _error.toString(),
        actionLabel: '重试',
        onAction: _load,
      );
    }
    if (_items.isEmpty) {
      return const _MessageScrollView(
        key: PreorderKeys.empty,
        icon: Icons.favorite_border,
        title: '还没有心仪衣服',
        message: '上传商品图片和数据后，可在这里持续查看并发起 AI 分析。',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _items[index];
          return _PreorderCard(
            item: item,
            selectedForAnalysis: item.id == _selectedItemId,
            onOpen: () => _openDetail(item),
            onSelectForAnalysis: () {
              setState(() {
                _selectedItemId = item.id == _selectedItemId ? null : item.id;
              });
            },
          );
        },
      ),
    );
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final items = await widget.repository.listPreorders();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _loading = false;
        if (!items.any((item) => item.id == _selectedItemId)) {
          _selectedItemId = null;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    final item = await Navigator.of(context).push<PreorderItem>(
      MaterialPageRoute(
        builder: (context) => PreorderFormPage(
          repository: widget.repository,
          imageService: widget.imageService,
        ),
      ),
    );
    if (!mounted || item == null) {
      return;
    }
    _selectedItemId = item.id;
    widget.onDataChanged?.call();
    await _load();
  }

  Future<void> _openDetail(PreorderItem item) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => PreorderDetailPage(
          repository: widget.repository,
          imageService: widget.imageService,
          analysisService: widget.analysisService,
          item: item,
        ),
      ),
    );
    if (mounted) {
      widget.onDataChanged?.call();
      await _load();
    }
  }

  Future<void> _runAnalysis() async {
    final item = _selectedItem;
    final itemId = item?.id;
    if (item == null || itemId == null) {
      _showMessage('请先选择一件要分析的衣服');
      return;
    }
    if (!widget.analysisService.isConfigured) {
      _showMessage('AI 分析服务尚未配置，不会保存模拟结果');
      return;
    }

    setState(() => _analysing = true);
    try {
      final instruction = _instructionController.text.trim();
      final result = await widget.analysisService.analyze(
        item: item,
        userInstruction: instruction.isEmpty ? null : instruction,
      );
      await widget.repository.appendPreorderAnalysis(
        result.toRecord(preorderItemId: itemId),
      );
      widget.onDataChanged?.call();
      if (!mounted) {
        return;
      }
      _instructionController.clear();
      _showMessage('分析已保存，点击衣服卡片可查看');
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

  PreorderItem? get _selectedItem {
    for (final item in _items) {
      if (item.id == _selectedItemId) {
        return item;
      }
    }
    return null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PreorderCard extends StatelessWidget {
  const _PreorderCard({
    required this.item,
    required this.selectedForAnalysis,
    required this.onOpen,
    required this.onSelectForAnalysis,
  });

  final PreorderItem item;
  final bool selectedForAnalysis;
  final VoidCallback onOpen;
  final VoidCallback onSelectForAnalysis;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final itemId = item.id;
    final displayName = _displayName(item);
    final supporting = <String>[
      if (item.brand?.trim().isNotEmpty ?? false) item.brand!.trim(),
      if (item.category?.trim().isNotEmpty ?? false) item.category!.trim(),
      if (item.material?.trim().isNotEmpty ?? false) item.material!.trim(),
    ];

    return Card(
      key: itemId == null
          ? ValueKey(
              'prepurchase-item-${item.createdAt.microsecondsSinceEpoch}',
            )
          : PreorderKeys.item(itemId),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selectedForAnalysis
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LocalClothingImage(
                    imagePath: item.imagePath,
                    semanticLabel: displayName,
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: FilterChip(
                      key: itemId == null
                          ? null
                          : PreorderKeys.selectForAnalysis(itemId),
                      selected: selectedForAnalysis,
                      onSelected: (_) => onSelectForAnalysis(),
                      avatar: Icon(
                        selectedForAnalysis
                            ? Icons.check_circle
                            : Icons.auto_awesome_outlined,
                        size: 18,
                      ),
                      label: Text(selectedForAnalysis ? '已选分析' : '选择分析'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (supporting.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            supporting.join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (item.price != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      '¥${_formatNumber(item.price!)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

class _AnalysisComposer extends StatelessWidget {
  const _AnalysisComposer({
    required this.selectedItem,
    required this.controller,
    required this.analysing,
    required this.serviceConfigured,
    required this.onClearSelection,
    required this.onSend,
  });

  final PreorderItem? selectedItem;
  final TextEditingController controller;
  final bool analysing;
  final bool serviceConfigured;
  final VoidCallback onClearSelection;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = selectedItem?.name?.trim();
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectedItem != null)
                InputChip(
                  avatar: const Icon(Icons.checkroom_outlined, size: 18),
                  label: Text(
                    name == null || name.isEmpty ? '未命名心仪衣服' : name,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onDeleted: analysing ? null : onClearSelection,
                )
              else
                Text(
                  '先在卡片右上角选择一件衣服',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: PreorderKeys.aiInput,
                      controller: controller,
                      enabled: !analysing,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: serviceConfigured
                            ? '补充你在意的问题（可留空）'
                            : 'AI 服务尚未配置',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    key: PreorderKeys.aiSend,
                    tooltip: '发送分析',
                    onPressed: onSend,
                    icon: analysing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageScrollView extends StatelessWidget {
  const _MessageScrollView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          SizedBox(
            height: (constraints.maxHeight - 48).clamp(240, 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 52, color: colorScheme.onSurfaceVariant),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (actionLabel != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
