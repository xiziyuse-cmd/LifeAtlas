import 'package:flutter/material.dart';
import '../data/kitchen_repository.dart';
import '../domain/kitchen_models.dart';
import 'kitchen_widgets.dart';
import 'recipe_form_page.dart';
import 'record_form_page.dart';

class RecipeDetailPage extends StatefulWidget {
  const RecipeDetailPage({
    super.key,
    required this.recipe,
    required this.repository,
  });
  final Recipe recipe;
  final KitchenRepository repository;
  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  late Recipe _recipe = widget.recipe;
  bool _busy = false;
  Future<void> _action(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) kitchenError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _recipe;
    final sorted = [...r.seasonings]..sort((a, b) => a.sort.compareTo(b.sort));
    return Scaffold(
      appBar: AppBar(title: Text(r.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          KitchenImage(r.image, height: 220),
          const SizedBox(height: 12),
          Text(r.name, style: Theme.of(context).textTheme.headlineSmall),
          Text('${r.categories.join(' | ')} · ${r.difficulty}'),
          Text('${r.cookTime}分钟 · 制作${r.cookCount}次'),
          if (r.sourceType == 'preset') const Text('预置菜谱 · 编辑后保存为个人版本'),
          Wrap(
            spacing: 8,
            children: [
              if (r.id == null)
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _action(() async {
                          final id = await widget.repository.saveRecipe(r);
                          final recipes = await widget.repository.listRecipes();
                          if (mounted) {
                            setState(
                              () => _recipe = recipes.firstWhere(
                                (e) => e.id == id,
                              ),
                            );
                          }
                        }),
                  child: const Text('一键添加到菜谱库'),
                ),
              if (r.id != null)
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _action(() async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RecordFormPage(
                                repository: widget.repository,
                                recipe: r,
                              ),
                            ),
                          );
                          final list = await widget.repository.listRecipes();
                          if (mounted) {
                            setState(
                              () => _recipe = list.firstWhere(
                                (e) => e.id == r.id,
                              ),
                            );
                          }
                        }),
                  child: const Text('记录制作'),
                ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _action(() async {
                        final id = await Navigator.push<int>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecipeFormPage(
                              repository: widget.repository,
                              recipe: r,
                            ),
                          ),
                        );
                        if (id != null) {
                          final list = await widget.repository.listRecipes();
                          if (mounted) {
                            setState(
                              () =>
                                  _recipe = list.firstWhere((e) => e.id == id),
                            );
                          }
                        }
                      }),
                child: Text(r.sourceType == 'preset' ? '编辑为个人版本' : '编辑'),
              ),
              if (r.id != null && r.sourceType != 'preset')
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          if (!await confirmKitchenDelete(context, '菜谱') ||
                              !mounted) {
                            return;
                          }
                          await _action(() async {
                            await widget.repository.deleteRecipe(r.id!);
                            if (context.mounted) Navigator.pop(context);
                          });
                        },
                  child: const Text('删除'),
                ),
            ],
          ),
          const Divider(),
          Text('食材', style: Theme.of(context).textTheme.titleLarge),
          for (final m in r.materials)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${m.name} ${m.quantity}'),
              subtitle: m.remark.isEmpty ? null : Text(m.remark),
            ),
          Text('调料', style: Theme.of(context).textTheme.titleLarge),
          for (final m in sorted)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${m.name} ${m.quantity}'),
              subtitle: Text(
                '${m.stage} · 顺序 ${m.sort}${m.remark.isEmpty ? '' : ' · ${m.remark}'}',
              ),
            ),
          Text('制作过程', style: Theme.of(context).textTheme.titleLarge),
          for (var i = 0; i < r.steps.length; i++) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${i + 1}. ${r.steps[i].name}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('耗时：${r.steps[i].duration}分钟'),
                    const SizedBox(height: 12),
                    Text(r.steps[i].content),
                    const SizedBox(height: 8),
                    if (r.steps[i].materials.isNotEmpty)
                      Text(
                        '使用食材：${r.materials.where((m) => r.steps[i].materials.contains(m.name)).map((m) => '${m.name} ${m.quantity}').join('、')}',
                      ),
                    for (final m in sorted.where(
                      (m) =>
                          r.steps[i].seasonings.contains(m.name) ||
                          m.stage == r.steps[i].name,
                    ))
                      Text('${m.sort}. ${m.name} ${m.quantity}'),
                    if (r.steps[i].image.isNotEmpty)
                      KitchenImage(r.steps[i].image),
                    if (r.steps[i].video.isNotEmpty)
                      KitchenVideo(
                        r.steps[i].video,
                        key: ValueKey(r.steps[i].video),
                      ),
                  ],
                ),
              ),
            ),
            if (i < r.steps.length - 1)
              const Center(child: Icon(Icons.arrow_downward)),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
