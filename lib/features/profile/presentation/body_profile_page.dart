import 'package:flutter/material.dart';
import '../../../app/app_controller.dart';
import '../../../core/settings/app_settings.dart';
import '../data/body_vault.dart';
import '../../wardrobe/data/wardrobe_repository.dart';
import '../../wardrobe/domain/models/clothing_item.dart';

class BodyProfilePage extends StatefulWidget {
  const BodyProfilePage({super.key, required this.controller, this.vault});
  final AppController controller;
  final BodyVault? vault;
  @override
  State<BodyProfilePage> createState() => _BodyProfileState();
}

class _BodyProfileState extends State<BodyProfilePage>
    with WidgetsBindingObserver {
  late final vault = widget.vault ?? BodyVault();
  final password = TextEditingController(), confirm = TextEditingController();
  bool? configured;
  bool busy = false, recovery = false;
  String? error;
  ModalRoute<dynamic>? route;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    vault.lock();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      vault.lock();
      password.clear();
      confirm.clear();
      if (mounted) {
        Navigator.of(context).popUntil((r) => r == route || r.isFirst);
        setState(() {});
      }
    }
  }

  Future<void> _check() async {
    try {
      final v = await vault.configured();
      if (mounted) setState(() => configured = v);
    } catch (_) {
      if (mounted) setState(() => error = '档案读取失败，请重试');
    }
  }

  Future<void> _run(Future<void> Function() task) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await task();
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e
              .toString()
              .replaceFirst('Bad state: ', '')
              .replaceFirst('FormatException: ', ''),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error!)));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _enter() => _run(() async {
    if (configured == false) {
      if (password.text != confirm.text) throw const FormatException('两次密码不一致');
      final code = await vault.create(password.text);
      configured = true;
      if (mounted && vault.unlocked) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
            title: const Text('请保存恢复码'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('忘记密码时凭此码解锁。请在安全位置保存，不会再次显示。'),
                  SelectableText(code),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('已保存恢复码'),
              ),
            ],
          ),
        );
      }
    } else {
      await vault.unlock(password.text, recovery: recovery);
      if (recovery) {
        if (!mounted) return;
        try {
          await _changePassword();
        } finally {
          vault.lock();
        }
      }
    }
    password.clear();
    confirm.clear();
  });
  Future<void> _changePassword() async {
    final first = TextEditingController(), second = TextEditingController();
    final form = GlobalKey<FormState>();
    try {
      final value = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('设置新密码'),
          content: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: first,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    validator: (v) =>
                        (v?.length ?? 0) < 8 || (v?.length ?? 0) > 128
                        ? '请输入8至128位密码'
                        : null,
                    decoration: const InputDecoration(labelText: '新密码'),
                  ),
                  TextFormField(
                    controller: second,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    validator: (v) => v != first.text ? '两次密码不一致' : null,
                    decoration: const InputDecoration(labelText: '再次输入'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                if (form.currentState!.validate()) Navigator.pop(c, first.text);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      );
      if (value != null) await vault.changePassword(value);
    } finally {
      first.dispose();
      second.dispose();
    }
  }

  Future<void> _edit({BodyRecord? record}) async {
    final seed = record ?? (vault.records.isEmpty ? null : vault.records.first);
    final value = await Navigator.push<BodyRecord>(
      context,
      MaterialPageRoute(
        builder: (_) => BodyRecordForm(seed: seed, editing: record != null),
      ),
    );
    if (value != null && vault.unlocked) await _run(() => vault.save(value));
    if (mounted) setState(() {});
  }

  Future<void> _history() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => StatefulBuilder(
          builder: (c, refresh) => Scaffold(
            appBar: AppBar(title: const Text('历史记录')),
            body: ListView(
              children: [
                for (final r in vault.records)
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(r.date),
                          subtitle: Text(
                            r.values.entries
                                .map(
                                  (e) =>
                                      '${e.key}：${e.value} ${bodyUnit(e.key)}${r.inherited.contains(e.key) ? '（沿用）' : ''}',
                                )
                                .join(' · '),
                          ),
                        ),
                        if (r.note.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(r.note),
                          ),
                        Wrap(
                          children: [
                            TextButton(
                              onPressed: () async {
                                await _edit(record: r);
                                if (c.mounted) refresh(() {});
                              },
                              child: const Text('修正这条记录'),
                            ),
                            TextButton(
                              onPressed: () async {
                                final yes = await showDialog<bool>(
                                  context: c,
                                  builder: (d) => AlertDialog(
                                    title: const Text('删除这条记录？'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(d, false),
                                        child: const Text('取消'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(d, true),
                                        child: const Text('删除'),
                                      ),
                                    ],
                                  ),
                                );
                                if (yes == true) {
                                  await _run(() => vault.delete(r.id));
                                  if (c.mounted) refresh(() {});
                                }
                              },
                              child: const Text('删除'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _compare() => _run(() async {
    final records = vault.records;
    if (records.isEmpty) throw StateError('请先记录身材');
    final body = records.first;
    final clothes = await WardrobeRepository().listClothing();
    if (!mounted || !vault.unlocked) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => Scaffold(
          appBar: AppBar(title: const Text('衣服尺寸对比')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('使用档案：${body.date}；衣服尺寸－身体尺寸，仅展示差值，不代表合身结论。'),
              if (clothes.isEmpty) const Text('衣柜暂无衣服'),
              for (final item in clothes)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: Theme.of(c).textTheme.titleMedium,
                        ),
                        for (final e in <String, double?>{
                          '肩宽': _garment(
                            item,
                            'shoulder_width',
                            item.shoulderWidth,
                          ),
                          '胸围': _garment(
                            item,
                            'chest_circumference',
                            item.chestCircumference,
                          ),
                          if (!item.parameterValues.containsKey(
                                'waist_circumference_min',
                              ) &&
                              !item.parameterValues.containsKey(
                                'waist_circumference_max',
                              ))
                            '腰围': item.waistCircumference,
                          '臀围': _garment(
                            item,
                            'hip_circumference',
                            item.hipCircumference,
                          ),
                        }.entries)
                          Text(_comparison(e.key, body.values[e.key], e.value)),
                        Text(
                          '身体腰围：${body.values['腰围'] ?? '未填'} cm；衣服腰围范围：${item.parameterValues['waist_circumference_min']?.editableText ?? '未填'}－${item.parameterValues['waist_circumference_max']?.editableText ?? '未填'} cm；仅比较同口径数据。',
                        ),
                        const Text('请核对整圈/平铺口径、版型与弹性。裤长不与身体腿长直接比较。'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  });
  double? _garment(ClothingItem item, String key, double? fallback) {
    final p = item.parameterValues[key];
    if (p != null && p.unit != null && !['cm', '厘米'].contains(p.unit)) {
      return null;
    }
    return p?.numberValue ?? fallback;
  }

  String _comparison(String name, String? value, double? garment) {
    final n = double.tryParse(value ?? '');
    if (n == null || garment == null) {
      return '$name：缺少${n == null ? '身体' : '衣服'}数据';
    }
    final d = garment - n;
    return '$name：身体 $n / 衣服 $garment cm · 差值 ${d >= 0 ? '+' : ''}${d.toStringAsFixed(1)} cm';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('我的身材'),
      actions: [
        if (vault.unlocked)
          IconButton(
            tooltip: '历史记录',
            onPressed: busy ? null : _history,
            icon: const Icon(Icons.history),
          ),
        if (vault.unlocked)
          IconButton(
            tooltip: '锁定',
            onPressed: () {
              vault.lock();
              setState(() {});
            },
            icon: const Icon(Icons.lock_outline),
          ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (configured == null) ...[
          const Text('读取档案…'),
          TextButton(onPressed: _check, child: const Text('重试')),
        ] else if (!vault.unlocked) ...[
          Text(
            configured! ? '解锁身材档案' : '建立受密码保护的身材档案',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text('数据仅保存在本机。密码须为8至128位，首次设置会生成恢复码。'),
          TextField(
            key: const ValueKey('body-password'),
            controller: password,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(labelText: recovery ? '恢复码' : '独立密码'),
          ),
          if (!configured!)
            TextField(
              key: const ValueKey('body-confirm'),
              controller: confirm,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(labelText: '确认密码'),
            ),
          FilledButton(
            onPressed: busy ? null : _enter,
            child: Text(configured! ? '解锁' : '设置密码'),
          ),
          if (configured!)
            TextButton(
              onPressed: busy
                  ? null
                  : () {
                      setState(() => recovery = !recovery);
                      password.clear();
                    },
              child: Text(recovery ? '使用密码解锁' : '忘记密码，使用恢复码'),
            ),
        ] else ...[
          if (vault.records.isEmpty)
            const Text('尚未建立身材档案，先填写已知的数据即可。')
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('最新档案 · ${vault.records.first.date}'),
                    for (final e in vault.records.first.values.entries)
                      Text(
                        '${e.key}：${e.value} ${bodyUnit(e.key)}${vault.records.first.inherited.contains(e.key) ? '（沿用）' : ''}',
                      ),
                    if (vault.records.first.note.isNotEmpty)
                      Text(vault.records.first.note),
                  ],
                ),
              ),
            ),
          FilledButton.icon(
            onPressed: busy ? null : () => _edit(),
            icon: const Icon(Icons.add),
            label: const Text('记录身材'),
          ),
          if (vault.records.isNotEmpty)
            OutlinedButton(
              onPressed: busy ? null : () => _edit(record: vault.records.first),
              child: const Text('修正最新记录'),
            ),
          Card(
            child: ListTile(
              title: const Text('已有衣服尺寸对比'),
              trailing: const Icon(Icons.chevron_right),
              onTap: busy ? null : _compare,
            ),
          ),
          TextButton(
            onPressed: busy ? null : () => _run(_changePassword),
            child: const Text('修改独立密码'),
          ),
          const Text('性别 · 沿用现有穿搭默认品类设置'),
          RadioGroup<ProfileGender>(
            groupValue: widget.controller.profileGender,
            onChanged: (v) async {
              if (v != null) {
                await widget.controller.setProfileGender(v);
                if (mounted) setState(() {});
              }
            },
            child: Column(
              children: [
                for (final g in ProfileGender.values)
                  RadioListTile<ProfileGender>(
                    key: ValueKey('profile-gender-${g.name}'),
                    title: Text(g.label),
                    value: g,
                  ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

class BodyRecordForm extends StatefulWidget {
  const BodyRecordForm({super.key, this.seed, this.editing = false});
  final BodyRecord? seed;
  final bool editing;
  @override
  State<BodyRecordForm> createState() => _BodyRecordFormState();
}

class _BodyRecordFormState extends State<BodyRecordForm> {
  late final fields = {
    for (final name in bodyFields.values.expand((v) => v))
      name: TextEditingController(text: widget.seed?.values[name] ?? ''),
  };
  late final note = TextEditingController(
    text: widget.editing ? widget.seed?.note : '',
  );
  late final date = TextEditingController(
    text: widget.editing
        ? widget.seed!.date
        : DateTime.now().toIso8601String().substring(0, 10),
  );
  final inherited = <String>{};
  String? error;
  @override
  void initState() {
    super.initState();
    if (!widget.editing) inherited.addAll(widget.seed?.values.keys ?? []);
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    note.dispose();
    date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.editing ? '修正身材记录' : '记录身材')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: date,
          decoration: const InputDecoration(labelText: '记录日期 YYYY-MM-DD'),
        ),
        const Text('所有字段可留空；沿用上次的数据会标注，重新测量后修改或清空。'),
        for (final group in bodyFields.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 8),
            child: Text(
              group.key,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final name in group.value)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: fields[name],
                keyboardType: numericBodyFields.contains(name)
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
                onChanged: (_) {
                  if (inherited.remove(name)) setState(() {});
                },
                decoration: InputDecoration(
                  labelText: '$name ${bodyUnit(name)}',
                  helperText: inherited.contains(name) ? '沿用上次，尚未重新测量' : null,
                  suffixIcon: measurementHelp.containsKey(name)
                      ? IconButton(
                          icon: const Icon(Icons.help_outline),
                          tooltip: '怎么量$name',
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: Text('怎么量$name'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 160,
                                    height: 200,
                                    child: CustomPaint(
                                      painter: name == '体重'
                                          ? null
                                          : _BodyMeasurePainter(name),
                                      child: name == '体重'
                                          ? const Icon(
                                              Icons.monitor_weight_outlined,
                                              size: 90,
                                            )
                                          : null,
                                    ),
                                  ),
                                  Text(measurementHelp[name]!),
                                  const Text('示意：围度绕身体一周；长度按说明的起止点测量。'),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c),
                                  child: const Text('知道了'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
        ],
        TextField(
          controller: note,
          maxLines: 3,
          decoration: const InputDecoration(labelText: '备注'),
        ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        FilledButton(
          onPressed: () {
            try {
              final r = BodyRecord(
                id: widget.editing
                    ? widget.seed!.id
                    : DateTime.now().microsecondsSinceEpoch.toString(),
                date: date.text.trim(),
                values: {
                  for (final e in fields.entries)
                    if (e.value.text.trim().isNotEmpty)
                      e.key: e.value.text.trim(),
                },
                note: note.text.trim(),
                inherited: inherited.toList(),
              );
              r.validate();
              Navigator.pop(context, r);
            } catch (e) {
              setState(() => error = e.toString());
            }
          },
          child: const Text('保存记录'),
        ),
      ],
    ),
  );
}

class _BodyMeasurePainter extends CustomPainter {
  _BodyMeasurePainter(this.field);
  final String field;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 160, size.height / 200);
    final outline = Paint()
      ..color = const Color(0xff6b7d75)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(const Offset(80, 19), 13, outline);
    final body = Path()
      ..moveTo(54, 43)
      ..lineTo(106, 43)
      ..lineTo(99, 108)
      ..lineTo(104, 130)
      ..lineTo(96, 188)
      ..lineTo(82, 188)
      ..lineTo(80, 133)
      ..lineTo(78, 188)
      ..lineTo(64, 188)
      ..lineTo(56, 130)
      ..lineTo(61, 108)
      ..close();
    canvas.drawPath(body, outline);
    canvas.drawLine(const Offset(54, 44), const Offset(34, 109), outline);
    canvas.drawLine(const Offset(106, 44), const Offset(126, 109), outline);
    final marker = Paint()
      ..color = const Color(0xffb64e47)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    Offset a, b;
    if (field == '身高') {
      a = const Offset(18, 5);
      b = const Offset(18, 190);
    } else if (field == '臂长') {
      a = const Offset(111, 44);
      b = const Offset(132, 112);
    } else if (field == '上身长度') {
      a = const Offset(86, 43);
      b = const Offset(86, 108);
    } else if (field == '腿内长') {
      a = const Offset(80, 133);
      b = const Offset(80, 190);
    } else if (field == '腿外长') {
      a = const Offset(115, 108);
      b = const Offset(115, 190);
    } else {
      final y =
          <String, double>{
            '肩宽': 43,
            '胸围': 65,
            '腰围': 103,
            '臀围': 125,
            '大腿围': 145,
            '小腿围': 172,
          }[field] ??
          103;
      a = Offset(53, y);
      b = Offset(107, y);
    }
    canvas.drawLine(a, b, marker);
    canvas.drawCircle(a, 3, marker);
    canvas.drawCircle(b, 3, marker);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BodyMeasurePainter oldDelegate) =>
      oldDelegate.field != field;
}
