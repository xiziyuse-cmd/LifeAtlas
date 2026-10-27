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
    final values = await showDialog<List<String>>(
      context: context,
      builder: (_) => _RecipeItemDialog(
        item: item,
        seasoning: oldSeasoning,
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
      ),
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
        parallelWithPrevious: s.parallelWithPrevious,
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
          stepNumber: (index ?? _steps.length) + 1,
          canParallel: (index ?? _steps.length) > 0,
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

  void _removeStep(int index) {
    final removed = _steps.removeAt(index);
    if (!removed.parallelWithPrevious && index < _steps.length) {
      _steps[index] = _steps[index].copyWith(parallelWithPrevious: false);
    }
  }

  void _moveStep(int index, int delta) {
    final memberships = <RecipeStep, int>{};
    final groups = recipeStepGroups(_steps);
    for (var group = 0; group < groups.length; group++) {
      for (final step in groups[group]) {
        memberships[step] = group;
      }
    }
    final moved = _steps.removeAt(index);
    _steps.insert(index + delta, moved);
    final ordered = [..._steps];
    for (var i = 0; i < ordered.length; i++) {
      final linked =
          i > 0 &&
          ordered[i] != moved &&
          ordered[i - 1] != moved &&
          memberships[ordered[i]] == memberships[ordered[i - 1]];
      _steps[i] = ordered[i].copyWith(parallelWithPrevious: linked);
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
          cookTime: recipeDuration(_steps),
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
          Text(
            '预计制作 ${recipeDuration(_steps)} 分钟',
            key: const ValueKey('recipe-total-duration'),
          ),
          for (final entry in _steps.asMap().entries)
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text('${entry.key + 1}. ${entry.value.name}'),
                    subtitle: Text(
                      '${entry.key > 0 && entry.value.parallelWithPrevious ? '并行 · ' : ''}${entry.value.duration}分钟',
                    ),
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
                                _moveStep(entry.key, -1);
                              }),
                        icon: const Icon(Icons.arrow_upward),
                      ),
                      IconButton(
                        tooltip: '下移',
                        onPressed: entry.key == _steps.length - 1
                            ? null
                            : () => setState(() {
                                _moveStep(entry.key, 1);
                              }),
                        icon: const Icon(Icons.arrow_downward),
                      ),
                      IconButton(
                        tooltip: '移除步骤',
                        onPressed: () => setState(() => _removeStep(entry.key)),
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

class _RecipeItemDialog extends StatefulWidget {
  const _RecipeItemDialog({
    required this.item,
    required this.seasoning,
    required this.validate,
  });

  final RecipeMaterial? item;
  final bool seasoning;
  final String? Function(List<String>) validate;

  @override
  State<_RecipeItemDialog> createState() => _RecipeItemDialogState();
}

class _RecipeItemDialogState extends State<_RecipeItemDialog> {
  late bool _seasoning = widget.seasoning;
  late final _name = TextEditingController(text: widget.item?.name ?? '');
  late final _amount = TextEditingController(
    text: '${widget.item?.amount ?? ''}',
  );
  late final _unit = TextEditingController(
    text: widget.item?.unit ?? (_seasoning ? '勺' : 'g'),
  );
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _unit.dispose();
    super.dispose();
  }

  void _selectType(Set<bool> selection) {
    final seasoning = selection.single;
    if (seasoning == _seasoning) return;
    setState(() {
      // Keep custom units while replacing the previous type's default unit.
      if (_unit.text.trim().isEmpty || _unit.text == (_seasoning ? '勺' : 'g')) {
        _unit.text = seasoning ? '勺' : 'g';
      }
      _seasoning = seasoning;
      _error = null;
    });
  }

  void _submit() {
    final values = [
      _seasoning ? '调料' : '食材',
      _name.text.trim(),
      _amount.text.trim(),
      _unit.text.trim(),
    ];
    final error = widget.validate(values);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, values);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.item == null ? '新增食材或调料' : '编辑食材或调料'),
    scrollable: true,
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('类型'),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('食材')),
              ButtonSegment(value: true, label: Text('调料')),
            ],
            selected: {_seasoning},
            onSelectionChanged: _selectType,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '名称'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            decoration: const InputDecoration(labelText: '用量'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _unit,
            decoration: const InputDecoration(labelText: '单位'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _submit, child: const Text('确定')),
    ],
  );
}
