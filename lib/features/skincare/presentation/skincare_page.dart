import 'package:flutter/material.dart';

import '../application/skincare_reminders.dart';
import '../data/skincare_repository.dart';
import '../data/skincare_ai_service.dart';
import '../domain/skincare_models.dart';
import '../domain/skincare_rules.dart';
import 'skin_profile_page.dart';
import 'skin_product_page.dart';
import 'skin_plan_page.dart';
import 'skin_execution_page.dart';

class SkincarePage extends StatefulWidget {
  const SkincarePage({
    super.key,
    required this.repository,
    required this.ai,
    required this.reminders,
  });
  final SkincareRepository repository;
  final SkincareAiService ai;
  final SkincareReminders reminders;
  @override
  State<SkincarePage> createState() => SkincarePageState();
}

class SkincarePageState extends State<SkincarePage>
    with WidgetsBindingObserver {
  SkinProfile? profile;
  SkinPlan? plan;
  List<SkinProduct> products = [];
  List<SkinExecution> history = [];
  DateTime date = DateTime.now();
  bool loading = true, generating = false;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) reload();
  }

  Future<void> reload() async {
    try {
      await widget.repository.importCatalog();
      final p = await widget.repository.profile(),
          active = await widget.repository.activePlan();
      final items = await widget.repository.products(),
          records = await widget.repository.history();
      if (mounted) {
        setState(() {
          profile = p;
          plan = active;
          products = items;
          history = records;
          loading = false;
          error = null;
        });
      }
      if (mounted) await widget.reminders.reschedule();
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = '读取或提醒更新失败：$e';
        });
      }
    }
  }

  Future<void> open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    await reload();
  }

  Future<void> editProfile() async {
    final value = await Navigator.push<SkinProfile>(
      context,
      MaterialPageRoute(builder: (_) => SkinProfilePage(profile: profile)),
    );
    if (value == null) return;
    try {
      await widget.repository.saveSetting('profile', value.toJson());
      await reload();
      if (plan != null && mounted) {
        final regenerate = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('档案已更新'),
            content: const Text('是否重新生成护肤计划？新计划确认后替换当前版本。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('稍后'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('生成新计划'),
              ),
            ],
          ),
        );
        if (regenerate == true) await generate();
      }
    } catch (e) {
      if (mounted) setState(() => error = '档案保存失败：$e');
    }
  }

  Future<void> generate({bool basic = false}) async {
    if (profile == null ||
        profile!.goals.isEmpty ||
        products.where((p) => p.usable).isEmpty) {
      setState(() => error = '请先建立皮肤档案、选择目标并添加使用中的产品');
      return;
    }
    setState(() {
      generating = true;
      error = null;
    });
    try {
      final result = basic
          ? SkincareRules.basic(products, profile!)
          : await widget.ai.generate(profile!, products);
      if (mounted) {
        await open(
          SkinPlanPage(
            plan: result,
            repository: widget.repository,
            preview: true,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  Future<void> startPeriod(String period) async {
    try {
      final entry = await widget.repository.start(DateTime.now(), period);
      if (!mounted) return;
      if (entry.finished) {
        await showHistory(entry);
        return;
      }
      await open(
        SkinExecutionPage(entry: entry, repository: widget.repository),
      );
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> showHistory(SkinExecution entry) => showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(
        '${entry.date} ${entry.period == 'am' ? '早间' : '晚间'} · ${entry.status}',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < entry.steps.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${entry.states[i] == 'done'
                      ? '✓'
                      : entry.states[i] == 'skipped'
                      ? '跳过'
                      : '待完成'} ${entry.steps[i].name}\n${entry.steps[i].amount} · ${entry.steps[i].area}',
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('关闭')),
      ],
    ),
  );
  Future<void> reminders() async {
    final settings = object(await widget.repository.setting('reminders') ?? {});
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('护理提醒', style: Theme.of(c).textTheme.titleLarge),
                for (final period in ['am', 'pm']) ...[
                  SwitchListTile(
                    title: Text(period == 'am' ? '早间提醒' : '晚间提醒'),
                    value: settings['${period}Enabled'] == true,
                    onChanged: (v) =>
                        update(() => settings['${period}Enabled'] = v),
                  ),
                  ListTile(
                    title: const Text('提醒时间'),
                    trailing: Text(
                      TimeOfDay(
                        hour:
                            ((settings['${period}Minute'] as int? ??
                                (period == 'am' ? 480 : 1290)) ~/
                            60),
                        minute:
                            (settings['${period}Minute'] as int? ??
                                (period == 'am' ? 480 : 1290)) %
                            60,
                      ).format(c),
                    ),
                    onTap: () async {
                      final minute =
                          settings['${period}Minute'] as int? ??
                          (period == 'am' ? 480 : 1290);
                      final time = await showTimePicker(
                        context: c,
                        initialTime: TimeOfDay(
                          hour: minute ~/ 60,
                          minute: minute % 60,
                        ),
                      );
                      if (time != null) {
                        update(
                          () => settings['${period}Minute'] =
                              time.hour * 60 + time.minute,
                        );
                      }
                    },
                  ),
                ],
                const Text('使用系统非精确定时，实际送达受省电设置影响；每次打开时更新未来 28 天提醒。'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    try {
                      if ((settings['amEnabled'] == true ||
                              settings['pmEnabled'] == true) &&
                          !await widget.reminders.requestPermission()) {
                        if (mounted) {
                          setState(() => error = '未获得通知权限，请在系统设置中允许通知后重试');
                        }
                        return;
                      }
                      await widget.repository.saveSetting(
                        'reminders',
                        settings,
                      );
                      if (mounted) await widget.reminders.reschedule();
                      if (c.mounted) Navigator.pop(c);
                    } catch (e) {
                      if (mounted) setState(() => error = '提醒设置失败：$e');
                    }
                  },
                  child: const Text('保存提醒'),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget section(String title, Widget trailing) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        trailing,
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final today = DateTime.now();
    final week = DateTime(
      today.year,
      today.month,
      today.day - today.weekday + 1,
    );
    final invalid = plan != null && profile != null
        ? SkincareRules.validate(plan!, products, profile!)
        : <String>[];
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skinDate(today),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      today.hour < 12 ? '早安，照顾好今天的自己' : '给皮肤留一点时间',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '提醒设置',
                onPressed: reminders,
                icon: const Icon(Icons.notifications_none),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [...?profile?.goals.map((g) => Chip(label: Text(g)))],
          ),
          if (error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(error!),
                    TextButton(onPressed: reload, child: const Text('重试')),
                  ],
                ),
              ),
            ),
          if (profile == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '建立你的护理起点',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    const Text('记录皮肤状态、选择目标，添加已有产品。'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: editProfile,
                      child: const Text('建立皮肤档案'),
                    ),
                  ],
                ),
              ),
            ),
          if (invalid.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('档案或产品资料已变更，请调整计划。\n${invalid.join('\n')}'),
              ),
            ),
          if (plan != null) ...[
            section('本周护理', const SizedBox.shrink()),
            SizedBox(
              height: 94,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 7,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final d = DateTime(week.year, week.month, week.day + i),
                      selected =
                          skinDate(date) ==
                          skinDate(
                            DateTime(week.year, week.month, week.day + i),
                          );
                  final records = history.where((e) => e.date == skinDate(d));
                  final special = plan!
                      .steps(d, 'pm')
                      .any((s) => s.days.length < 7);
                  return InkWell(
                    onTap: () => setState(() => date = d),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 52,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: selected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text(['一', '二', '三', '四', '五', '六', '日'][i]),
                          Text(
                            '${d.day}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            records.any((e) => e.finished)
                                ? '✓'
                                : special
                                ? '护理'
                                : '基础',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            section('${skinDate(date)} 的护理', const SizedBox.shrink()),
            for (final period
                in (today.hour < 12 ? ['am', 'pm'] : ['pm', 'am']))
              Builder(
                builder: (context) {
                  final steps = plan!.steps(date, period);
                  final record = history
                      .where(
                        (e) => e.date == skinDate(date) && e.period == period,
                      )
                      .firstOrNull;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                period == 'am'
                                    ? Icons.wb_sunny_outlined
                                    : Icons.nightlight_outlined,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                period == 'am' ? '早间护理' : '晚间护理',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const Spacer(),
                              Text(record?.status ?? '未开始'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            (record?.steps ?? steps)
                                .map((s) => s.name)
                                .join(' → '),
                          ),
                          const SizedBox(height: 16),
                          if (skinDate(date) == skinDate(today))
                            FilledButton(
                              onPressed: steps.isEmpty || invalid.isNotEmpty
                                  ? null
                                  : () => startPeriod(period),
                              child: Text(
                                record?.finished == true
                                    ? '查看完成记录'
                                    : record == null
                                    ? '开始护理'
                                    : '继续护理',
                              ),
                            )
                          else if (record != null)
                            TextButton(
                              onPressed: () => showHistory(record),
                              child: const Text('查看记录'),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
          section(
            '我的护肤柜',
            TextButton.icon(
              onPressed: () => open(
                SkinProductPage(repository: widget.repository, ai: widget.ai),
              ),
              icon: const Icon(Icons.add),
              label: const Text('添加'),
            ),
          ),
          if (products.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('搜索产品或拍摄包装，确认后加入。无需填写成分与功效。'),
              ),
            ),
          for (final category in skinCategories.where(
            (c) => products.any((p) => p.category == c),
          )) ...[
            Text(category, style: Theme.of(context).textTheme.labelLarge),
            for (final p in products.where((p) => p.category == category))
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.spa_outlined)),
                  title: Text(p.name),
                  subtitle: Text(
                    '${p.status} · ${p.trusted ? '资料已确认' : '资料待确认'}${p.expires.isNotEmpty ? ' · 到期 ${p.expires}' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(
                    SkinProductPage(
                      repository: widget.repository,
                      ai: widget.ai,
                      product: p,
                    ),
                  ),
                ),
              ),
          ],
          section(
            '护理规划',
            IconButton(
              onPressed: editProfile,
              tooltip: '编辑档案与目标',
              icon: const Icon(Icons.tune),
            ),
          ),
          if (profile != null)
            Text(
              '${profile!.type} · ${profile!.sensitivity} · ${profile!.state}',
            ),
          if (generating) const LinearProgressIndicator(),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: generating ? null : () => generate(),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('AI 生成计划'),
          ),
          OutlinedButton(
            onPressed: generating ? null : () => generate(basic: true),
            child: const Text('使用基础规则生成'),
          ),
          if (plan != null)
            TextButton(
              onPressed: () => open(
                SkinPlanPage(plan: plan!, repository: widget.repository),
              ),
              child: const Text('完整计划与手动调整'),
            ),
          section(
            '最近护理记录',
            Text(
              '${history.where((e) => e.finished && e.date.compareTo(skinDate(week)) >= 0).length} 次 / 本周',
            ),
          ),
          if (history.isEmpty) const Text('开始护理后，进度会保存在这里。'),
          for (final e in history.take(14))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${e.date} · ${e.period == 'am' ? '早间' : '晚间'}'),
              trailing: Text(e.status),
              onTap: () => showHistory(e),
            ),
        ],
      ),
    );
  }
}
