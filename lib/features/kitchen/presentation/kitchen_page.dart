import 'package:flutter/material.dart';
import '../data/kitchen_repository.dart';
import '../data/kitchen_ai_service.dart';
import '../domain/kitchen_models.dart';
import 'kitchen_widgets.dart';
import 'recipe_form_page.dart';
import 'recipe_detail_page.dart';
import 'record_form_page.dart';
import 'kitchen_recommendation_page.dart';
import 'inventory_form_dialog.dart';

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
  List<Recipe> _recipes = [];
  List<InventoryItem> _inventory = [];
  List<CookingRecord> _records = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final recipes = await widget.repository.listRecipes();
      final inventory = await widget.repository.listInventory();
      final records = await widget.repository.listRecords();
      if (mounted) {
        setState(() {
          _recipes = recipes;
          _inventory = inventory;
          _records = records;
          _error = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载失败：$e';
          _loading = false;
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
    } catch (e) {
      if (mounted) kitchenError(context, e);
    }
  }

  Future<void> _record() async {
    final recipe = await showDialog<Recipe>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择菜谱'),
        children: [
          for (final r in _recipes)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, r),
              child: Text(r.name),
            ),
        ],
      ),
    );
    if (recipe != null && mounted) {
      await _open(
        RecordFormPage(repository: widget.repository, recipe: recipe),
      );
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Column(
      children: [
        const TabBar(
          tabs: [
            Tab(text: '菜谱'),
            Tab(text: '库存'),
            Tab(text: '制作记录'),
          ],
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      TextButton(onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                )
              : TabBarView(
                  children: [
                    RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: () => _open(
                                RecipeFormPage(repository: widget.repository),
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('新建菜谱'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_recipes.isEmpty) const Text('暂无菜谱，开始记录你的拿手菜'),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final scale =
                                  MediaQuery.textScalerOf(context).scale(14) /
                                  14;
                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _recipes.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                      mainAxisExtent:
                                          constraints.maxWidth / 3 +
                                          112 * scale,
                                    ),
                                itemBuilder: (context, i) {
                                  final r = _recipes[i];
                                  return Card(
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () => _open(
                                        RecipeDetailPage(
                                          recipe: r,
                                          repository: widget.repository,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          KitchenImage(
                                            r.image,
                                            height:
                                                constraints.maxWidth / 3 - 16,
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(6),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  r.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  r.categories.join(' | '),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  '${r.cookTime}分钟',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  '制作${r.cookCount}次',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                    RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Wrap(
                            spacing: 8,
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
                          if (_inventory.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('暂无库存，添加家中已有的食材和调料'),
                            ),
                          if (_inventory.any(
                            (item) =>
                                item.freshness ==
                                    InventoryFreshness.nearExpiry ||
                                item.freshness == InventoryFreshness.today ||
                                item.freshness == InventoryFreshness.expired,
                          )) ...[
                            const SizedBox(height: 16),
                            Text(
                              '即将过期',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '优先处理临期和已过期食物',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                          const SizedBox(height: 12),
                          Text(
                            '全部库存',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          for (final item in _inventory)
                            Card(
                              child: ListTile(
                                title: Text(
                                  '${item.name}  ${item.amount}${item.unit}',
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (item.expireDate != null)
                                        Text(
                                          '预计过期：${kitchenDate(item.expireDate!)} · ${_remainingText(item)}',
                                        ),
                                      Text(
                                        '${kitchenDate(item.updatedAt)}更新${item.remark.isEmpty ? '' : ' · ${item.remark}'}',
                                      ),
                                      const SizedBox(height: 7),
                                      _FreshnessChip(item: item),
                                    ],
                                  ),
                                ),
                                onTap: () => _editInventory(item),
                                trailing: IconButton(
                                  tooltip: '删除库存',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    if (!await confirmKitchenDelete(
                                          context,
                                          '库存',
                                        ) ||
                                        !mounted) {
                                      return;
                                    }
                                    try {
                                      await widget.repository.deleteInventory(
                                        item.id!,
                                      );
                                      await _load();
                                    } catch (e) {
                                      if (context.mounted) {
                                        kitchenError(context, e);
                                      }
                                    }
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: _recipes.isEmpty ? null : _record,
                              icon: const Icon(Icons.add),
                              label: const Text('记录制作'),
                            ),
                          ),
                          if (_records.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('还没有制作记录，试试做一道菜吧'),
                            ),
                          for (final r in _records)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${kitchenDate(r.date)} · ${r.recipeName}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    if (r.image.isNotEmpty)
                                      KitchenImage(r.image),
                                    Text(
                                      '★' * r.score,
                                      style: const TextStyle(
                                        color: Colors.amber,
                                      ),
                                    ),
                                    if (r.remark.isNotEmpty) Text(r.remark),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    ),
  );
}

String _remainingText(InventoryItem item) {
  final days = item.remainingDays();
  if (days == null) return '未设置保质期';
  if (days < 0) return '已过期${-days}天';
  if (days == 0) return '今天到期';
  return '剩余$days天';
}

class _FreshnessChip extends StatelessWidget {
  const _FreshnessChip({required this.item});
  final InventoryItem item;
  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (item.freshness) {
      InventoryFreshness.fresh => ('新鲜', Icons.eco_outlined, Colors.green),
      InventoryFreshness.nearExpiry => ('临期', Icons.schedule, Colors.orange),
      InventoryFreshness.today => (
        '今日到期',
        Icons.notification_important_outlined,
        Colors.deepOrange,
      ),
      InventoryFreshness.expired => (
        '已过期',
        Icons.warning_amber_rounded,
        Colors.red,
      ),
      InventoryFreshness.unknown => (
        '未设置',
        Icons.help_outline,
        Theme.of(context).colorScheme.outline,
      ),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        avatar: Icon(icon, size: 16, color: color),
        label: Text(label),
        labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
        backgroundColor: color.withValues(alpha: .1),
        side: BorderSide(color: color.withValues(alpha: .35)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
