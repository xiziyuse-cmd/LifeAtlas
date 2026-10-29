import 'package:flutter/material.dart';

import '../domain/skincare_models.dart';
import '../domain/skincare_rules.dart';
import '../data/skincare_repository.dart';

class SkinPlanPage extends StatefulWidget {
  const SkinPlanPage({
    super.key,
    required this.plan,
    required this.repository,
    this.preview = false,
  });
  final SkinPlan plan;
  final SkincareRepository repository;
  final bool preview;
  @override
  State<SkinPlanPage> createState() => _SkinPlanPageState();
}

class _SkinPlanPageState extends State<SkinPlanPage> {
  late final morning = [...widget.plan.morning],
      evening = [...widget.plan.evening];
  bool busy = false;
  String? error;
  Future<void> edit(List<SkinStep> list, int i) async {
    final s = list[i];
    final days = [...s.days];
    final amount = TextEditingController(text: s.amount),
        area = TextEditingController(text: s.area);
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: Text(s.name),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amount,
                  decoration: const InputDecoration(labelText: '用量'),
                ),
                TextField(
                  controller: area,
                  decoration: const InputDecoration(labelText: '部位'),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 6,
                  children: List.generate(
                    7,
                    (d) => FilterChip(
                      label: Text('周${['一', '二', '三', '四', '五', '六', '日'][d]}'),
                      selected: days.contains(d + 1),
                      onSelected: (v) => update(() {
                        v ? days.add(d + 1) : days.remove(d + 1);
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (yes == true) {
      setState(
        () => list[i] = SkinStep(
          productId: s.productId,
          name: s.name,
          amount: amount.text.trim(),
          area: area.text.trim(),
          note: s.note,
          days: days,
        ),
      );
    }
    amount.dispose();
    area.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.preview ? '计划预览' : '护理计划与调整')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          widget.plan.name,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(widget.plan.strategy),
        const SizedBox(height: 8),
        Text(
          '来源：${widget.plan.source == 'rules' ? '本地规则' : 'AI 生成，已做规则校验'}\n版本：${widget.plan.id}',
        ),
        for (final period in ['am', 'pm']) ...[
          const SizedBox(height: 24),
          Text(
            period == 'am' ? '早间护理' : '晚间护理',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (var i = 0; i < (period == 'am' ? morning : evening).length; i++)
            Builder(
              builder: (context) {
                final list = period == 'am' ? morning : evening;
                final s = list[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}. ${s.name}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text('${s.amount}\n${s.area}\n${s.note}'),
                        Wrap(
                          spacing: 4,
                          children: [
                            for (final d in s.days)
                              Chip(
                                label: Text(
                                  '周${['一', '二', '三', '四', '五', '六', '日'][d - 1]}',
                                ),
                              ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              tooltip: '上移',
                              onPressed: i == 0
                                  ? null
                                  : () => setState(() {
                                      final item = list.removeAt(i);
                                      list.insert(i - 1, item);
                                    }),
                              icon: const Icon(Icons.arrow_upward),
                            ),
                            IconButton(
                              tooltip: '下移',
                              onPressed: i == list.length - 1
                                  ? null
                                  : () => setState(() {
                                      final item = list.removeAt(i);
                                      list.insert(i + 1, item);
                                    }),
                              icon: const Icon(Icons.arrow_downward),
                            ),
                            TextButton(
                              onPressed: () => edit(list, i),
                              child: const Text('频率与用法'),
                            ),
                            IconButton(
                              tooltip: '移除步骤',
                              onPressed: () => setState(() => list.removeAt(i)),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  setState(() {
                    busy = true;
                    error = null;
                  });
                  try {
                    final profile = await widget.repository.profile();
                    if (profile == null) throw StateError('请先保存档案');
                    final plan = SkinPlan(
                      id: skinId(),
                      name: widget.plan.name,
                      strategy: widget.plan.strategy,
                      start: skinDate(DateTime.now()),
                      source: widget.plan.source,
                      morning: morning,
                      evening: evening,
                    );
                    final errors = SkincareRules.validate(
                      plan,
                      await widget.repository.products(),
                      profile,
                    );
                    if (errors.isNotEmpty) throw StateError(errors.join('\n'));
                    await widget.repository.activate(plan);
                    if (context.mounted) Navigator.pop(context, true);
                  } catch (e) {
                    if (mounted) {
                      setState(() {
                        error = '$e';
                        busy = false;
                      });
                    }
                  }
                },
          child: Text(busy ? '保存中…' : '确认并启用此版本'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('确认后用于未来护理。已开始和历史护理保留当时的步骤快照。'),
        ),
      ],
    ),
  );
}
