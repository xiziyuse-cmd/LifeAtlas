import 'package:flutter/material.dart';
import '../data/kitchen_repository.dart';
import '../domain/kitchen_models.dart';
import 'kitchen_widgets.dart';
import 'recipe_form_page.dart';

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

  Future<void> _edit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RecipeFormPage(repository: widget.repository, recipe: _recipe),
      ),
    );
    if (!mounted) return;
    final recipes = await widget.repository.listRecipes();
    if (_recipe.sourceType != 'preset') {
      final matches = recipes.where((item) => item.id == _recipe.id);
      if (matches.isNotEmpty) setState(() => _recipe = matches.first);
    }
  }

  Future<void> _delete() async {
    if (_recipe.id == null ||
        !await confirmKitchenDelete(context, _recipe.name)) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.repository.deleteRecipe(_recipe.id!);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) kitchenError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = _recipe;
    final theme = Theme.of(context);
    final materials = [...recipe.materials]
      ..sort((a, b) => a.sort.compareTo(b.sort));
    final seasonings = [...recipe.seasonings]
      ..sort((a, b) => a.sort.compareTo(b.sort));
    return Scaffold(
      appBar: AppBar(
        title: const Text('菜谱详情'),
        actions: [
          if (recipe.sourceType != 'preset')
            PopupMenuButton<String>(
              onSelected: (value) => value == 'edit' ? _edit() : _delete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('编辑菜谱')),
                PopupMenuItem(value: 'delete', child: Text('删除菜谱')),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: KitchenImage(recipe.image, height: double.infinity),
          ),
          const SizedBox(height: 20),
          Text(
            recipe.name,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...recipe.categories.map(
                (value) => Chip(
                  label: Text(value),
                  avatar: const Icon(Icons.local_offer_outlined, size: 16),
                ),
              ),
              Chip(
                label: Text(recipe.difficulty),
                avatar: const Icon(Icons.signal_cellular_alt, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.schedule, size: 20),
              const SizedBox(width: 8),
              Text(
                '预计制作 ${recipe.totalDuration} 分钟',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _section(context, '食材与调料', Icons.shopping_basket_outlined, [
            for (final item in materials) _ingredient(context, item),
            if (materials.isNotEmpty && seasonings.isNotEmpty)
              const Divider(
                key: ValueKey('recipe-ingredient-divider'),
                thickness: 1,
                height: 24,
              ),
            for (final item in seasonings) _ingredient(context, item),
          ]),
          const SizedBox(height: 24),
          Text(
            '制作步骤',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ..._stepGroups(context, recipe.steps),
          const SizedBox(height: 16),
          if (recipe.sourceType == 'preset')
            FilledButton.icon(
              onPressed: _busy ? null : _edit,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('保存为个人版本'),
            )
          else
            FilledButton.icon(
              onPressed: _busy ? null : _edit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('编辑菜谱'),
            ),
        ],
      ),
    );
  }

  List<Widget> _stepGroups(BuildContext context, List<RecipeStep> steps) {
    final result = <Widget>[];
    var number = 0;
    for (final group in recipeStepGroups(steps)) {
      final children = <Widget>[
        for (var i = 0; i < group.length; i++)
          _step(context, group[i], ++number, i == group.length - 1),
      ];
      if (group.length == 1) {
        result.add(children.single);
      } else {
        result.add(
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '并行 · ${recipeDuration(group)} 分钟',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ...children,
              ],
            ),
          ),
        );
      }
    }
    return result;
  }

  Widget _section(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );

  Widget _ingredient(BuildContext context, RecipeMaterial item) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            item.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Text(item.quantity, style: Theme.of(context).textTheme.titleSmall),
      ],
    ),
  );

  Widget _step(BuildContext context, RecipeStep step, int number, bool last) =>
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  CircleAvatar(radius: 16, child: Text('$number')),
                  if (!last)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Card(
                margin: const EdgeInsets.only(bottom: 14),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              step.name,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const Icon(Icons.timer_outlined, size: 17),
                          const SizedBox(width: 4),
                          Text('${step.duration}分钟'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(step.content),
                      if (step.materials.isNotEmpty ||
                          step.seasonings.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ...step.materials.map(
                              (name) => Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text(name),
                              ),
                            ),
                            ...step.seasonings.map(
                              (name) => Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text(name),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (step.image.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        KitchenImage(step.image),
                      ],
                      if (step.video.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        KitchenVideo(step.video),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
