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
      sensitivity = widget.profile?.sensitivity ?? '不确定';
  late final states = {...?widget.profile?.states}.isEmpty
      ? <String>{'稳定'}
      : {...widget.profile!.states};
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
                showCheckmark: false,
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
    bool tight = false,
        oily = false,
        dry = false,
        allOily = false,
        comfortable = false;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('肤质参考'),
          content: SingleChildScrollView(
            child: Column(
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
                CheckboxListTile(
                  title: const Text('全脸容易出油，下午油光明显'),
                  value: allOily,
                  onChanged: (v) => update(() => allOily = v!),
                ),
                CheckboxListTile(
                  title: const Text('整体舒适，无明显出油或紧绷'),
                  value: comfortable,
                  onChanged: (v) => update(() => comfortable = v!),
                ),
                const Text('结合最近一段时间的表现选择，可保留“不确定”。季节、清洁与正在使用的产品都可能影响感受。'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, '不确定'),
              child: const Text('保持不确定'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                comfortable && (oily || dry || tight || allOily)
                    ? '不确定'
                    : comfortable
                    ? '中性'
                    : (oily || allOily) && (dry || tight)
                    ? '混合性'
                    : (oily || allOily)
                    ? '油性'
                    : (dry || tight)
                    ? '干性'
                    : '不确定',
              ),
              child: const Text('使用参考结果'),
            ),
          ],
        ),
      ),
    );
    if (result != null) setState(() => type = result);
  }

  Widget section(String number, String title, String hint) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$number  $title', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(hint, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('皮肤档案与目标')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('了解现在的皮肤', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('先记录肤质与状态，再选择需要优先关注的目标。'),
        const SizedBox(height: 20),
        section('01', '基本信息', '肤质与敏感程度可在之后调整'),
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
        if (type == '不确定')
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              '暂时无法判断可以保留“不确定”。可点击上方参考问题，结合T区出油、两颊干燥和洁面后紧绷情况记录；之后随时修改。',
            ),
          ),
        choices(
          '敏感程度',
          ['不敏感', '轻度敏感', '容易敏感', '不确定'],
          sensitivity,
          (v) => sensitivity = v,
        ),
        section('02', '当前状态', '可多选；稳定与其他状态互斥'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final value in ['稳定', '干燥', '爆痘', '泛红', '屏障不稳定'])
              FilterChip(
                label: Text(value),
                showCheckmark: false,
                selected: states.contains(value),
                onSelected: (selected) => setState(() {
                  if (selected) {
                    if (value == '稳定') {
                      states.clear();
                    } else {
                      states.remove('稳定');
                    }
                    states.add(value);
                  } else {
                    states.remove(value);
                    if (states.isEmpty) states.add('稳定');
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('孕期、备孕、哺乳期或需避免维 A 类'),
          subtitle: const Text('开启后仅自动安排基础护理'),
          value: restricted,
          onChanged: (v) => setState(() => restricted = v),
        ),
        const SizedBox(height: 20),
        section('03', '按部位记录问题', '展开对应部位，勾选需要关注的问题'),
        for (final area in ['额头', '鼻子', '脸颊', '下巴', '全脸'])
          ExpansionTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            tilePadding: const EdgeInsets.symmetric(horizontal: 4),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: Text(area),
            subtitle: (areas[area]?.isNotEmpty ?? false)
                ? Text(areas[area]!.join('、'))
                : null,
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
        section('04', '主要目标', '按选择顺序排列优先级，最多三个'),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 330 ? 1 : 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final goal in skinGoals)
                  SizedBox(
                    width: (constraints.maxWidth - (columns - 1) * 8) / columns,
                    child: OutlinedButton(
                      key: ValueKey('goal-$goal'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 56),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                        backgroundColor: goals.contains(goal)
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : null,
                      ),
                      onPressed: () => setState(() {
                        if (goals.contains(goal)) {
                          goals.remove(goal);
                        } else if (goals.length < 3) {
                          goals.add(goal);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('最多选择三个目标')),
                          );
                        }
                      }),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              goals.contains(goal)
                                  ? '${goals.indexOf(goal) + 1}'
                                  : '○',
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(child: Text(goal)),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
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
                states: states.toList(),
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
