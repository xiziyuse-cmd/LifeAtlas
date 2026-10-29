import 'package:flutter/material.dart';

import '../domain/skincare_models.dart';

class SkinProfilePage extends StatefulWidget {
  const SkinProfilePage({super.key, this.profile});
  final SkinProfile? profile;
  @override
  State<SkinProfilePage> createState() => _SkinProfilePageState();
}

class _SkinProfilePageState extends State<SkinProfilePage> {
  late final age = TextEditingController(
    text: widget.profile?.age?.toString() ?? '',
  );
  late String type = widget.profile?.type ?? '不确定',
      sensitivity = widget.profile?.sensitivity ?? '不确定',
      state = widget.profile?.state ?? '稳定';
  late bool restricted = widget.profile?.retinoidRestricted ?? false;
  late final goals = [...?widget.profile?.goals];
  late final areas = <String, List<String>>{
    for (final e in (widget.profile?.areas ?? <String, List<String>>{}).entries)
      e.key: [...e.value],
  };
  @override
  void dispose() {
    age.dispose();
    super.dispose();
  }

  Widget choices(
    String title,
    List<String> values,
    String selected,
    ValueChanged<String> change,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: values
            .map(
              (v) => ChoiceChip(
                label: Text(v),
                selected: selected == v,
                onSelected: (_) => setState(() => change(v)),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 20),
    ],
  );
  Future<void> assist() async {
    bool tight = false, oily = false, dry = false;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('肤质参考'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                title: const Text('洁面后容易紧绷'),
                value: tight,
                onChanged: (v) => update(() => tight = v!),
              ),
              CheckboxListTile(
                title: const Text('T 区容易出油'),
                value: oily,
                onChanged: (v) => update(() => oily = v!),
              ),
              CheckboxListTile(
                title: const Text('两颊容易干燥'),
                value: dry,
                onChanged: (v) => update(() => dry = v!),
              ),
              const Text('结果作为日常护理参考。'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                oily && (dry || tight)
                    ? '混合性'
                    : oily
                    ? '油性'
                    : (dry || tight)
                    ? '干性'
                    : '中性',
              ),
              child: const Text('使用参考结果'),
            ),
          ],
        ),
      ),
    );
    if (result != null) setState(() => type = result);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('皮肤档案与目标')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('了解现在的皮肤', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        TextField(
          controller: age,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '年龄（选填）'),
        ),
        const SizedBox(height: 20),
        choices('肤质', ['干性', '油性', '混合性', '中性', '不确定'], type, (v) => type = v),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: assist, child: const Text('不确定自己的肤质？')),
        ),
        choices(
          '敏感程度',
          ['不敏感', '轻度敏感', '容易敏感', '不确定'],
          sensitivity,
          (v) => sensitivity = v,
        ),
        choices(
          '当前状态',
          ['稳定', '干燥', '爆痘', '泛红', '屏障不稳定'],
          state,
          (v) => state = v,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('孕期、备孕、哺乳期或需避免维 A 类'),
          subtitle: const Text('开启后仅自动安排基础护理'),
          value: restricted,
          onChanged: (v) => setState(() => restricted = v),
        ),
        const SizedBox(height: 20),
        Text('按部位记录问题', style: Theme.of(context).textTheme.titleMedium),
        for (final area in ['额头', '鼻子', '脸颊', '下巴', '全脸'])
          ExpansionTile(
            title: Text(area),
            subtitle: Text((areas[area] ?? []).join('、')),
            children: [
              Wrap(
                spacing: 6,
                children: skinIssues
                    .map(
                      (issue) => FilterChip(
                        label: Text(issue),
                        selected: areas[area]?.contains(issue) ?? false,
                        onSelected: (v) => setState(() {
                          final list = areas.putIfAbsent(area, () => []);
                          v ? list.add(issue) : list.remove(issue);
                        }),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        const SizedBox(height: 20),
        Text(
          '主要目标 · 按选择顺序，最多三个',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Wrap(
          spacing: 8,
          children: skinGoals
              .map(
                (g) => FilterChip(
                  label: Text(
                    '${goals.contains(g) ? '${goals.indexOf(g) + 1}. ' : ''}$g',
                  ),
                  selected: goals.contains(g),
                  onSelected: (v) => setState(() {
                    if (!v) {
                      goals.remove(g);
                    } else if (goals.length < 3) {
                      goals.add(g);
                    }
                  }),
                ),
              )
              .toList(),
        ),
        for (var i = 0; i < goals.length; i++)
          ListTile(
            dense: true,
            title: Text('${i + 1}. ${goals[i]}'),
            trailing: IconButton(
              icon: const Icon(Icons.arrow_upward),
              onPressed: i == 0
                  ? null
                  : () => setState(() {
                      final g = goals.removeAt(i);
                      goals.insert(i - 1, g);
                    }),
            ),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () {
            final number = int.tryParse(age.text);
            if (goals.isEmpty ||
                (age.text.isNotEmpty &&
                    (number == null || number < 1 || number > 120))) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('请选择目标，并检查年龄')));
              return;
            }
            Navigator.pop(
              context,
              SkinProfile(
                age: number,
                type: type,
                sensitivity: sensitivity,
                state: state,
                retinoidRestricted: restricted,
                areas: areas,
                goals: goals,
              ),
            );
          },
          child: const Text('保存档案'),
        ),
        const SizedBox(height: 24),
      ],
    ),
  );
}
