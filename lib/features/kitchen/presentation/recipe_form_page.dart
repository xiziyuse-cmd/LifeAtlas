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
  late final _time = TextEditingController(
    text: '${widget.recipe?.cookTime ?? 20}',
  );
  final _customCategory = TextEditingController();
  late String _image = widget.recipe?.image ?? '',
      _difficulty = widget.recipe?.difficulty ?? '简单';
  late final _categories = <String>{...?widget.recipe?.categories};
  late final _materials = [...?widget.recipe?.materials];
  late final _seasonings = [...?widget.recipe?.seasonings];
  late final _steps = [...?widget.recipe?.steps];
  bool _saving = false;
  @override
  void dispose() {
    _name.dispose();
    _time.dispose();
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

  Future<void> _material(bool seasoning, [int? index]) async {
    final list = seasoning ? _seasonings : _materials;
    final item = index == null ? null : list[index];
    final values = await kitchenFields(
      context,
      seasoning ? '调料' : '食材',
      ['名称', '用量', '单位', '备注', if (seasoning) '添加阶段', if (seasoning) '添加顺序'],
      [
        item?.name ?? '',
        '${item?.amount ?? ''}',
        item?.unit ?? 'g',
        item?.remark ?? '',
        if (seasoning) item?.stage ?? '准备阶段',
        if (seasoning) '${item?.sort ?? list.length + 1}',
      ],
      numeric: {1, if (seasoning) 5},
      choices: {if (seasoning) 4: kitchenStages},
      validate: (values) {
        final amount = double.tryParse(values[1]);
        final order = seasoning ? int.tryParse(values[5]) : 1;
        if (values[0].isEmpty ||
            values[2].isEmpty ||
            amount == null ||
            !amount.isFinite ||
            amount <= 0 ||
            order == null ||
            order < 1) {
          return '请填写名称、正数用量、单位和正整数顺序';
        }
        if (list.asMap().entries.any(
          (e) => e.key != index && e.value.name == values[0],
        )) {
          return '名称已存在，请编辑已有条目';
        }
        return null;
      },
    );
    if (values == null || !mounted) return;
    final amount = double.tryParse(values[1]);
    final order = seasoning
        ? int.tryParse(values[5])
        : (index ?? list.length) + 1;
    if (values[0].isEmpty ||
        values[2].isEmpty ||
        amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        order == null ||
        order < 1 ||
        (seasoning && !kitchenStages.contains(values[4]))) {
      kitchenError(context, const FormatException('请填写名称、正数用量、单位、有效阶段及正整数顺序'));
      return;
    }
    if (list.asMap().entries.any(
      (e) => e.key != index && e.value.name == values[0],
    )) {
      kitchenError(context, const FormatException('名称已存在，请编辑已有条目'));
      return;
    }
    setState(() {
      final updated = RecipeMaterial(
        name: values[0],
        amount: amount,
        unit: values[2],
        remark: values[3],
        stage: seasoning ? values[4] : '准备阶段',
        sort: order,
      );
      if (index == null) {
        list.add(updated);
      } else {
        list[index] = updated;
        _renameReferences(item!.name, updated.name, seasoning);
      }
    });
  }

  void _renameReferences(String oldName, String? newName, bool seasoning) {
    for (var i = 0; i < _steps.length; i++) {
      final s = _steps[i];
      List<String> rename(List<String> names) => names
          .where((n) => n != oldName || newName != null)
          .map((n) => n == oldName ? newName! : n)
          .toList();
      _steps[i] = RecipeStep(
        name: s.name,
        content: s.content,
        duration: s.duration,
        image: s.image,
        video: s.video,
        materials: seasoning ? s.materials : rename(s.materials),
        seasonings: seasoning ? rename(s.seasonings) : s.seasonings,
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
          cookTime: int.tryParse(_time.text) ?? 0,
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
                  avatar: SizedBox(
                    width: 18,
                    child: Icon(
                      Icons.check,
                      size: 16,
                      color: _categories.contains(c)
                          ? null
                          : Colors.transparent,
                    ),
                  ),
                  showCheckmark: false,
                  selected: _categories.contains(c),
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
          DropdownButtonFormField<String>(
            initialValue: _difficulty,
            decoration: const InputDecoration(labelText: '难度'),
            items: [
              for (final d in {
                ...['简单', '中等', '困难'],
                _difficulty,
              })
                DropdownMenuItem(value: d, child: Text(d)),
            ],
            onChanged: (v) => setState(() => _difficulty = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _time,
            decoration: const InputDecoration(labelText: '预计制作时间（分钟）'),
            keyboardType: TextInputType.number,
          ),
          for (final seasoning in [false, true]) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    seasoning ? '调料' : '食材',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => _material(seasoning),
                  child: const Text('添加'),
                ),
              ],
            ),
            for (final entry
                in (seasoning ? _seasonings : _materials).asMap().entries)
              Card(
                child: ListTile(
                  title: Text('${entry.value.name} ${entry.value.quantity}'),
                  subtitle: Text(
                    seasoning
                        ? '${entry.value.stage} · 顺序 ${entry.value.sort}'
                        : entry.value.remark,
                  ),
                  onTap: () => _material(seasoning, entry.key),
                  trailing: IconButton(
                    tooltip: '移除',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      (seasoning ? _seasonings : _materials).removeAt(
                        entry.key,
                      );
                      _renameReferences(entry.value.name, null, seasoning);
                    }),
                  ),
                ),
              ),
          ],
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
          if (_steps.isEmpty && _seasonings.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () => setState(
                () => _steps.addAll(stepsFromSeasonings(_seasonings)),
              ),
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('按调料阶段和顺序生成步骤'),
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
