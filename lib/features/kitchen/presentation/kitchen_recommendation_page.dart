import 'package:flutter/material.dart';
import '../data/kitchen_ai_service.dart';
import '../data/kitchen_repository.dart';
import '../domain/kitchen_models.dart';
import 'kitchen_widgets.dart';
import 'recipe_detail_page.dart';

class KitchenRecommendationPage extends StatefulWidget {
  const KitchenRecommendationPage({
    super.key,
    required this.repository,
    required this.service,
  });
  final KitchenRepository repository;
  final KitchenAiService service;
  @override
  State<KitchenRecommendationPage> createState() =>
      _KitchenRecommendationPageState();
}

class _KitchenRecommendationPageState extends State<KitchenRecommendationPage> {
  final _instruction = TextEditingController();
  List<InventoryItem> _inventory = [];
  List<Recipe> _recipes = [];
  bool _busy = false;
  String? _error;
  final _saved = <int>{};
  @override
  void dispose() {
    _instruction.dispose();
    super.dispose();
  }

  Future<void> _recommend() async {
    setState(() {
      _busy = true;
      _error = null;
      _recipes = [];
      _saved.clear();
    });
    try {
      final inventory = await widget.repository.listInventory();
      final today = DateTime.parse(kitchenDate(DateTime.now()));
      final usable = inventory
          .where(
            (i) =>
                i.amount > 0 &&
                (i.expireDate == null || !i.expireDate!.isBefore(today)),
          )
          .toList();
      if (usable.isEmpty) throw const KitchenAiException('请先添加有剩余数量且未过期的食材');
      final recipes = await widget.service.recommend(
        usable,
        _instruction.text.trim(),
      );
      if (mounted) {
        setState(() {
          _inventory = usable;
          _recipes = recipes;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AI推荐菜谱')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _instruction,
          decoration: const InputDecoration(
            labelText: '口味或调整要求（可选）',
            hintText: '例如：少油，优先使用鸡蛋',
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : _recommend,
          icon: const Icon(Icons.auto_awesome),
          label: Text(_busy ? '推荐中…' : '根据最新库存推荐'),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
        for (final entry in _recipes.asMap().entries)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.value.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${entry.value.totalDuration}分钟 · ${entry.value.categories.join(' | ')}',
                  ),
                  const SizedBox(height: 8),
                  for (final m in [
                    ...entry.value.materials,
                    ...entry.value.seasonings,
                  ])
                    Text(
                      '${m.name} ${m.quantity}  ${inventoryAvailability(m, _inventory)}',
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecipeDetailPage(
                              recipe: entry.value,
                              repository: widget.repository,
                            ),
                          ),
                        ),
                        child: const Text('查看详情'),
                      ),
                      FilledButton(
                        onPressed: _saved.contains(entry.key)
                            ? null
                            : () async {
                                setState(() => _saved.add(entry.key));
                                try {
                                  await widget.repository.saveRecipe(
                                    entry.value,
                                  );
                                } catch (e) {
                                  if (mounted) {
                                    setState(() => _saved.remove(entry.key));
                                    kitchenError(this.context, e);
                                  }
                                }
                              },
                        child: Text(
                          _saved.contains(entry.key) ? '已添加' : '添加到菜谱库',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
