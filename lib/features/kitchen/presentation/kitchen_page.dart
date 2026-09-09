import 'package:flutter/material.dart';
import '../data/kitchen_ai_service.dart';
import '../data/kitchen_repository.dart';
import '../domain/kitchen_models.dart';
import 'inventory_form_dialog.dart';
import 'kitchen_recommendation_page.dart';
import 'kitchen_widgets.dart';
import 'recipe_detail_page.dart';
import 'recipe_form_page.dart';

class KitchenPage extends StatefulWidget {
  const KitchenPage({
    super.key,
    required this.repository,
    required this.aiService,
  });
  final KitchenRepository repository;
  final KitchenAiService aiService;
  @override
  State<KitchenPage> createState() => _KitchenPageState();
}

class _KitchenPageState extends State<KitchenPage> {
  final _search = TextEditingController();
  List<Recipe> _recipes = [];
  List<InventoryItem> _inventory = [];
  bool _loading = true;
  String? _error;

  List<Recipe> get _visibleRecipes {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _recipes;
    return _recipes
        .where(
          (recipe) => [
            recipe.name,
            ...recipe.categories,
            ...recipe.materials.map((e) => e.name),
            ...recipe.seasonings.map((e) => e.name),
          ].join(' ').toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _search.addListener(_refreshSearch);
    _load();
  }

  void _refreshSearch() => setState(() {});
  @override
  void dispose() {
    _search.removeListener(_refreshSearch);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.repository.listRecipes(),
        widget.repository.listInventory(),
      ]);
      if (!mounted) return;
      setState(() {
        _recipes = results[0] as List<Recipe>;
        _inventory = results[1] as List<InventoryItem>;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '加载失败：$error';
        });
      }
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) await _load();
  }

  Future<void> _editInventory([InventoryItem? item]) async {
    final foods = await widget.repository.listFoodBaseInfo();
    if (!mounted) return;
    final value = await showDialog<InventoryItem>(
      context: context,
      builder: (_) => InventoryFormDialog(item: item, foods: foods),
    );
    if (value == null || !mounted) return;
    try {
      await widget.repository.saveInventory(value);
      await _load();
    } catch (error) {
      if (mounted) kitchenError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Column(
      children: [
        const TabBar(
          tabs: [
            Tab(text: '菜谱'),
            Tab(text: '库存'),
          ],
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: TextButton(
                    onPressed: _load,
                    child: Text('$_error\n点击重试'),
                  ),
                )
              : TabBarView(children: [_recipesView(), _inventoryView()]),
        ),
      ],
    ),
  );

  Widget _recipesView() {
    final recipes = _visibleRecipes;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: '搜索菜名、分类或食材',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: _search.clear,
                            icon: const Icon(Icons.clear),
                            tooltip: '清空',
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () =>
                    _open(RecipeFormPage(repository: widget.repository)),
                icon: const Icon(Icons.add),
                tooltip: '新建菜谱',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recipes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: Column(
                children: [
                  const Icon(Icons.search_off, size: 48),
                  const SizedBox(height: 12),
                  Text(_search.text.trim().isEmpty ? '暂无菜谱' : '没有找到相关菜谱'),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recipes.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    mainAxisExtent: constraints.maxWidth / 3 + 78 * scale,
                  ),
                  itemBuilder: (_, index) {
                    final recipe = recipes[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _open(
                          RecipeDetailPage(
                            recipe: recipe,
                            repository: widget.repository,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            KitchenImage(
                              recipe.image,
                              height: constraints.maxWidth / 3 - 16,
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    recipe.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    recipe.categories.take(2).join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  Text(
                                    '${recipe.cookTime}分钟',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _inventoryView() => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _editInventory,
              icon: const Icon(Icons.add),
              label: const Text('新增库存'),
            ),
            OutlinedButton.icon(
              onPressed: () => _open(
                KitchenRecommendationPage(
                  repository: widget.repository,
                  service: widget.aiService,
                ),
              ),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('AI推荐菜谱'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('全部库存', style: Theme.of(context).textTheme.titleLarge),
        if (_inventory.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('暂无库存，添加家中已有的食材和调料'),
          ),
        for (final item in _inventory)
          Card(
            child: ListTile(
              title: Text(
                '${item.name}  ${item.amount == item.amount.roundToDouble() ? item.amount.toInt() : item.amount}${item.unit}',
              ),
              subtitle: Text(
                item.expireDate == null
                    ? '${kitchenDate(item.updatedAt)}更新'
                    : '预计过期：${kitchenDate(item.expireDate!)} · ${_remainingText(item)}',
              ),
              onTap: () => _editInventory(item),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: '删除库存',
                onPressed: () async {
                  if (!await confirmKitchenDelete(context, item.name)) return;
                  await widget.repository.deleteInventory(item.id!);
                  await _load();
                },
              ),
            ),
          ),
      ],
    ),
  );

  String _remainingText(InventoryItem item) {
    final days = item.remainingDays();
    if (days == null) return '未设置';
    if (days < 0) return '已过期${-days}天';
    if (days == 0) return '今天到期';
    return '剩余$days天';
  }
}
