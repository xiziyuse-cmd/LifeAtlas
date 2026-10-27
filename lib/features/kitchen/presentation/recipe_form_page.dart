import 'package:flutter/material.dart';
import '../data/kitchen_repository.dart';
import '../domain/kitchen_models.dart';
import 'kitchen_widgets.dart';
import 'step_form_page.dart';

class RecipeFormPage extends StatefulWidget {
  const RecipeFormPage({super.key, required this.repository, this.recipe});
  final KitchenRepository repository;
  final Recipe? recipe;
  @override
  State<RecipeFormPage> createState() => _RecipeFormPageState();
}

class _RecipeFormPageState extends State<RecipeFormPage> {
  late final _name = TextEditingController(text: widget.recipe?.name ?? '');
  final _customCategory = TextEditingController();
  late String _image = widget.recipe?.image ?? '',
      _difficulty = widget.recipe?.difficulty ?? '简单';
  late final _categories = <String>{...?widget.recipe?.categories};
  late final _materials = [...?widget.recipe?.materials];
  late final _seasonings = [...?widget.recipe?.seasonings];
  late final _steps = [...?widget.recipe?.steps];
  List<_RecipeItemEntry> get _recipeItems => [
    ..._materials.asMap().entries.map(
      (entry) => _RecipeItemEntry(
        item: entry.value,
        index: entry.key,
        seasoning: false,
      ),
    ),
    ..._seasonings.asMap().entries.map(
      (entry) => _RecipeItemEntry(
        item: entry.value,
        index: entry.key,
        seasoning: true,
      ),
    ),
  ];
  bool _saving = false;
  @override
  void dispose() {
    _name.dispose();
    _customCategory.dispose();
    super.dispose();
  }

  void _addCustomCategory() {
    final value = _customCategory.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _categories.add(value);
      _customCategory.clear();
    });
  }

  Future<void> _material([_RecipeItemEntry? entry]) async {
    final item = entry?.item;
    final oldSeasoning = entry?.seasoning ?? false;
    final values = await kitchenFields(
      context,
      '新增食材或调料',
      ['类型', '名称', '用量', '单位'],
      [
        oldSeasoning ? '调料' : '食材',
        item?.name ?? '',
        '${item?.amount ?? ''}',
        item?.unit ?? 'g',
      ],
      numeric: {2},
      choices: {
        0: ['食材', '调料'],
      },
      validate: (values) {
        final amount = double.tryParse(values[2]);
        if (values[1].isEmpty ||
            values[3].isEmpty ||
            amount == null ||
            !amount.isFinite ||
            amount <= 0) {
          return '请填写名称、正数用量和单位';
        }
        final duplicate = [
          ..._materials,
          ..._seasonings,
        ].any((existing) => existing.name == values[1] && existing != item);
        if (duplicate) {
          return '名称已存在，请编辑已有条目';
        }
        return null;
      },
    );
    if (values == null || !mounted) return;
    final seasoning = values[0] == '调料';
    final amount = double.tryParse(values[2]);
    if (values[1].isEmpty ||
        values[3].isEmpty ||
        amount == null ||
        !amount.isFinite ||
        amount <= 0) {
      kitchenError(context, const FormatException('请填写名称、正数用量和单位'));
      return;
    }
    if ([
      ..._materials,
      ..._seasonings,
    ].any((existing) => existing.name == values[1] && existing != item)) {
      kitchenError(context, const FormatException('名称已存在，请编辑已有条目'));
      return;
    }
    setState(() {
      final updated = RecipeMaterial(
        name: values[1],
        amount: amount,
        unit: values[3],
        sort: (seasoning ? _seasonings : _materials).length + 1,
      );
      if (entry != null) {
        (oldSeasoning ? _seasonings : _materials).removeAt(entry.index);
      }
      (seasoning ? _seasonings : _materials).add(updated);
      if (entry != null &&
          (item!.name != updated.name || oldSeasoning != seasoning)) {
        _renameReferences(item.name, updated.name, oldSeasoning, seasoning);
      }
    });
  }

  void _renameReferences(
    String? oldName,
    String? newName,
    bool oldSeasoning,
    bool newSeasoning,
  ) {
    for (var i = 0; i < _steps.length; i++) {
      final s = _steps[i];
      final materials = [...s.materials];
      final seasonings = [...s.seasonings];
      if (oldName != null) {
        (oldSeasoning ? seasonings : materials).remove(oldName);
      }
      if (newName != null) {
        final target = newSeasoning ? seasonings : materials;
        if (!target.contains(newName)) target.add(newName);
      }
      _steps[i] = RecipeStep(
        name: s.name,
        content: s.content,
        duration: s.duration,
        image: s.image,
        video: s.video,
        materials: materials,
        seasonings: seasonings,
      );
    }
  }

  Future<void> _step([int? index]) async {
    final step = await Navigator.push<RecipeStep>(
      context,
      MaterialPageRoute(
        builder: (_) => StepFormPage(
          step: index == null ? null : _steps[index],
          materials: _materials,
          seasonings: _seasonings,
        ),
      ),
    );
    if (step != null && mounted) {
      setState(() {
        if (index == null) {
          _steps.add(step);
        } else {
          _steps[index] = step;
        }
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final id = await widget.repository.saveRecipe(
        Recipe(
          id: widget.recipe?.id,
          name: _name.text.trim(),
          image: _image,
          categories: _categories.toList(),
          difficulty: _difficulty,
          cookTime: _steps.fold(0, (total, step) => total + step.duration),
          materials: _materials,
          seasonings: _seasonings,
          steps: _steps,
        ),
      );
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) kitchenError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.recipe == null
            ? '新建菜谱'
            : widget.recipe!.sourceType == 'preset'
            ? '编辑为个人版本'
            : '编辑菜谱',
      ),
    ),
    body: AbsorbPointer(
      absorbing: _saving,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          KitchenImage(_image),
          TextButton.icon(
            onPressed: () async {
              try {
                final path = await pickKitchenMedia();
                if (path != null && mounted) setState(() => _image = path);
              } catch (e) {
                if (context.mounted) kitchenError(context, e);
              }
            },
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('选择菜品图片'),
          ),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '菜名'),
          ),
          const SizedBox(height: 16),
          Text('分类', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in {...kitchenCategories, ..._categories})
                FilterChip(
                  label: Text(c),
                  showCheckmark: false,
                  selected: _categories.contains(c),
                  selectedColor: const Color(0xFF26352D),
                  labelStyle: TextStyle(
                    color: _categories.contains(c) ? Colors.white : null,
                  ),
                  side: BorderSide(
                    color: _categories.contains(c)
                        ? const Color(0xFF26352D)
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                  onSelected: (v) => setState(() {
                    v ? _categories.add(c) : _categories.remove(c);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customCategory,
                  decoration: const InputDecoration(
                    labelText: '自定义分类',
                    hintText: '输入分类名称',
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addCustomCategory(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: _addCustomCategory,
                child: const Text('添加'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) => InputDecorator(
              decoration: const InputDecoration(labelText: '难度'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _difficulty,
                  isDense: true,
                  isExpanded: true,
                  menuWidth: constraints.maxWidth,
                  items: [
                    for (final d in {
                      ...['简单', '中等', '困难'],
                      _difficulty,
                    })
                      DropdownMenuItem(value: d, child: Text(d)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _difficulty = value);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  '食材与调料',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(onPressed: _material, child: const Text('新增')),
            ],
          ),
          for (final entry in _recipeItems)
            Card(
              child: ListTile(
                title: Text('${entry.item.name} ${entry.item.quantity}'),
                subtitle: Text(entry.seasoning ? '调料' : '食材'),
                onTap: () => _material(entry),
                trailing: IconButton(
                  tooltip: '移除',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    (entry.seasoning ? _seasonings : _materials).removeAt(
                      entry.index,
                    );
                    _renameReferences(
                      entry.item.name,
                      null,
                      entry.seasoning,
                      false,
                    );
                  }),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Text(
                  '制作步骤',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(onPressed: _step, child: const Text('添加步骤')),
            ],
          ),
          for (final entry in _steps.asMap().entries)
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text('${entry.key + 1}. ${entry.value.name}'),
                    subtitle: Text('耗时：${entry.value.duration}分钟'),
                    onTap: () => _step(entry.key),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: '上移',
                        onPressed: entry.key == 0
                            ? null
                            : () => setState(() {
                                final s = _steps.removeAt(entry.key);
                                _steps.insert(entry.key - 1, s);
                              }),
                        icon: const Icon(Icons.arrow_upward),
                      ),
                      IconButton(
                        tooltip: '下移',
                        onPressed: entry.key == _steps.length - 1
                            ? null
                            : () => setState(() {
                                final s = _steps.removeAt(entry.key);
                                _steps.insert(entry.key + 1, s);
                              }),
                        icon: const Icon(Icons.arrow_downward),
                      ),
                      IconButton(
                        tooltip: '移除步骤',
                        onPressed: () =>
                            setState(() => _steps.removeAt(entry.key)),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中…' : '保存菜谱'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    ),
  );
}

class _RecipeItemEntry {
  const _RecipeItemEntry({
    required this.item,
    required this.index,
    required this.seasoning,
  });

  final RecipeMaterial item;
  final int index;
  final bool seasoning;
}
