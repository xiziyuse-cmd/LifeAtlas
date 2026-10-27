import 'package:flutter/material.dart';

import '../data/kitchen_repository.dart';
import '../domain/kitchen_models.dart';
import '../domain/shopping_list.dart';
import 'kitchen_widgets.dart';

class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({super.key, required this.repository});
  final KitchenRepository repository;

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  List<Recipe> _recipes = [];
  ShoppingListState _selection = const ShoppingListState();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<ShoppingListItem> _items(Set<int> ids) =>
      buildShoppingList(_recipes.where((recipe) => ids.contains(recipe.id)));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final recipes = await widget.repository.listRecipes();
      final saved = await widget.repository.loadShoppingList();
      if (!mounted) return;
      _recipes = recipes;
      final ids = saved.recipeIds.intersection(
        recipes.map((r) => r.id).whereType<int>().toSet(),
      );
      final validKeys = _items(ids).map((item) => item.key).toSet();
      final selection = ShoppingListState(
        recipeIds: ids,
        prepared: saved.prepared.intersection(validKeys),
      );
      // Persist pruning so removed entries cannot regain stale ticks later.
      await widget.repository.saveShoppingList(selection);
      if (!mounted) return;
      setState(() {
        _selection = selection;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '购物清单加载失败';
      });
    }
  }

  Future<void> _save(ShoppingListState selection) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.repository.saveShoppingList(selection);
      if (mounted) setState(() => _selection = selection);
    } catch (error) {
      if (mounted) kitchenError(context, '购物清单保存失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseRecipes() async {
    final selected = await showDialog<Set<int>>(
      context: context,
      builder: (_) =>
          _RecipePicker(recipes: _recipes, selected: _selection.recipeIds),
    );
    if (selected == null || !mounted) return;
    final keys = _items(selected).map((item) => item.key).toSet();
    await _save(
      ShoppingListState(
        recipeIds: selected,
        prepared: _selection.prepared.intersection(keys),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items(_selection.recipeIds);
    final foods = items.where((item) => !item.seasoning).toList();
    final spices = items.where((item) => item.seasoning).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('购物清单')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: TextButton(onPressed: _load, child: Text('$_error，点击重试')),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                OutlinedButton.icon(
                  onPressed: _saving || _recipes.isEmpty
                      ? null
                      : _chooseRecipes,
                  icon: const Icon(Icons.playlist_add_check),
                  label: Text('选择菜谱（已选${_selection.recipeIds.length}道）'),
                ),
                if (_selection.recipeIds.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _recipes
                        .where((r) => _selection.recipeIds.contains(r.id))
                        .map((r) => r.name)
                        .join('、'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 16),
                if (_recipes.isEmpty)
                  const Center(child: Text('暂无菜谱，先添加菜谱'))
                else if (_selection.recipeIds.isEmpty)
                  const Center(child: Text('选择要做的菜谱，生成购物清单'))
                else if (items.isEmpty)
                  const Center(child: Text('所选菜谱暂无食材或调料'))
                else ...[
                  Text(
                    '已准备 ${items.where((item) => _selection.prepared.contains(item.key)).length}/${items.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          for (final item in foods) _row(item),
                          if (foods.isNotEmpty && spices.isNotEmpty)
                            const Divider(
                              height: 24,
                              thickness: 0.7,
                              indent: 16,
                              endIndent: 16,
                            ),
                          for (final item in spices) _row(item),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_saving) const LinearProgressIndicator(),
              ],
            ),
    );
  }

  Widget _row(ShoppingListItem item) {
    final checked = _selection.prepared.contains(item.key);
    final color = checked
        ? Colors.grey.shade400
        : Theme.of(context).colorScheme.onSurface;
    void toggle() {
      final prepared = {..._selection.prepared};
      checked ? prepared.remove(item.key) : prepared.add(item.key);
      _save(
        ShoppingListState(recipeIds: _selection.recipeIds, prepared: prepared),
      );
    }

    return Semantics(
      label: '${item.name} ${item.quantity}',
      checked: checked,
      child: InkWell(
        onTap: _saving ? null : toggle,
        child: Padding(
          padding: const EdgeInsets.only(right: 16, top: 4, bottom: 4),
          child: Row(
            children: [
              Checkbox(
                value: checked,
                onChanged: _saving ? null : (_) => toggle(),
                semanticLabel: '${item.name}已准备',
              ),
              Expanded(
                flex: 3,
                child: Text(item.name, style: TextStyle(color: color)),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Text(
                  item.quantity,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipePicker extends StatefulWidget {
  const _RecipePicker({required this.recipes, required this.selected});
  final List<Recipe> recipes;
  final Set<int> selected;

  @override
  State<_RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends State<_RecipePicker> {
  late final Set<int> _selected = {...widget.selected};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final recipes = widget.recipes
        .where(
          (r) => r.name.toLowerCase().contains(_query.trim().toLowerCase()),
        )
        .toList();
    return AlertDialog(
      title: const Text('选择菜谱'),
      content: SizedBox(
        width: 420,
        height: 400,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: '搜索菜名',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: recipes.isEmpty
                  ? const Center(child: Text('没有找到相关菜谱'))
                  : ListView(
                      children: [
                        for (final recipe in recipes)
                          CheckboxListTile(
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(recipe.name),
                            value: _selected.contains(recipe.id),
                            onChanged: recipe.id == null
                                ? null
                                : (value) => setState(() {
                                    value!
                                        ? _selected.add(recipe.id!)
                                        : _selected.remove(recipe.id);
                                  }),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: Text('确定（${_selected.length}）'),
        ),
      ],
    );
  }
}
