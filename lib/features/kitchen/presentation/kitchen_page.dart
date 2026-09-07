import 'package:flutter/material.dart';
import '../data/kitchen_repository.dart';
import '../data/kitchen_ai_service.dart';
import '../domain/kitchen_models.dart';
import 'kitchen_widgets.dart';
import 'recipe_form_page.dart';
import 'recipe_detail_page.dart';
import 'record_form_page.dart';
import 'kitchen_recommendation_page.dart';

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
    final values = await kitchenFields(
      context,
      item == null ? '新增库存' : '编辑库存',
      ['食材名称', '剩余数量', '单位', '备注', '到期日（可选，YYYY-MM-DD）'],
      [
        item?.name ?? '',
        '${item?.amount ?? ''}',
        item?.unit ?? '个',
        item?.remark ?? '',
        item?.expireDate == null ? '' : kitchenDate(item!.expireDate!),
      ],
      numeric: {1},
      validate: (values) {
        final amount = double.tryParse(values[1]);
        if (values[0].isEmpty ||
            values[2].isEmpty ||
            amount == null ||
            !amount.isFinite ||
            amount < 0) {
          return '请填写名称、非负数量和单位';
        }
        final date = DateTime.tryParse(values[4]);
        if (values[4].isNotEmpty &&
            (date == null || kitchenDate(date) != values[4])) {
          return '到期日格式应为 YYYY-MM-DD';
        }
        return null;
      },
    );
    if (values == null || !mounted) return;
    try {
      final amount = double.tryParse(values[1]);
      final expiry = values[4].isEmpty ? null : DateTime.tryParse(values[4]);
      if (amount == null ||
          (values[4].isNotEmpty &&
              (expiry == null || kitchenDate(expiry) != values[4]))) {
        throw const FormatException('请填写有效数量及 YYYY-MM-DD 格式的日期');
      }
      await widget.repository.saveInventory(
        InventoryItem(
          id: item?.id,
          name: values[0],
          amount: amount,
          unit: values[2],
          remark: values[3],
          expireDate: expiry,
          updatedAt: DateTime.now(),
        ),
      );
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
                          for (final item in _inventory)
                            Card(
                              child: ListTile(
                                title: Text(
                                  '${item.name}  ${item.amount}${item.unit}',
                                ),
                                subtitle: Text(
                                  '${kitchenDate(item.updatedAt)}更新${item.expireDate == null ? '' : '\n到期：${kitchenDate(item.expireDate!)}'}${item.remark.isEmpty ? '' : '\n${item.remark}'}',
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
