import 'package:flutter/material.dart';

import '../../data/wardrobe_repository.dart';
import '../../domain/models/clothing_item.dart';
import '../../domain/models/outfit_set.dart';
import '../wardrobe_keys.dart';
import 'outfit_set_form_page.dart';

class OutfitSetsPage extends StatefulWidget {
  const OutfitSetsPage({
    super.key,
    required this.repository,
    required this.clothingItems,
    this.onDataChanged,
  });

  final WardrobeRepository repository;
  final List<ClothingItem> clothingItems;
  final VoidCallback? onDataChanged;

  @override
  State<OutfitSetsPage> createState() => _OutfitSetsPageState();
}

class _OutfitSetsPageState extends State<OutfitSetsPage> {
  List<OutfitSet> _sets = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final sets = await widget.repository.listOutfitSets();
      if (mounted) {
        setState(() {
          _sets = sets;
          _isLoading = false;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = '套装加载失败';
        });
      }
    }
  }

  Future<void> _openForm([OutfitSet? initialSet]) async {
    final result = await Navigator.of(context).push<OutfitSet>(
      MaterialPageRoute(
        builder: (context) => OutfitSetFormPage(
          clothingItems: widget.clothingItems,
          initialSet: initialSet,
        ),
      ),
    );
    if (!mounted || result == null) {
      return;
    }

    try {
      if (result.id == null) {
        await widget.repository.createOutfitSet(result);
      } else {
        await widget.repository.updateOutfitSet(result);
      }
      widget.onDataChanged?.call();
      await _load();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('套装保存失败，请稍后重试')));
      }
    }
  }

  Future<void> _delete(OutfitSet set) async {
    final id = set.id;
    if (id == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除套装？'),
        content: Text('“${set.name}”会被删除，套装中的衣服仍保留在衣柜。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.repository.deleteOutfitSet(id);
      widget.onDataChanged?.call();
      await _load();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('套装删除失败，请稍后重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('套装管理'),
        actions: [
          IconButton(
            key: WardrobeKeys.outfitSetAdd,
            tooltip: '新增套装',
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: switch ((_isLoading, _error)) {
        (true, _) => const Center(child: CircularProgressIndicator()),
        (false, final error?) => _ErrorState(message: error, onRetry: _load),
        _ when _sets.isEmpty => _EmptyState(onAdd: () => _openForm()),
        _ => ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: _sets.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final set = _sets[index];
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.style_outlined)),
                title: Text(set.name),
                subtitle: Text(
                  '${set.seasonTags.join(' · ')} · ${set.clothingItemIds.length} 件',
                ),
                onTap: () => _openForm(set),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'edit') {
                      _openForm(set);
                    } else if (action == 'delete') {
                      _delete(set);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('编辑')),
                    PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ),
              ),
            );
          },
        ),
      },
      floatingActionButton: _sets.isEmpty || _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('新增套装'),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.style_outlined, size: 52),
            const SizedBox(height: 12),
            const Text('还没有套装'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onAdd, child: const Text('新增套装')),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
