import 'skincare_models.dart';

class SkincareRules {
  static final order = {'洁面': 0, '化妆水': 1, '精华': 2, '乳液': 3, '面霜': 4, '防晒': 5};
  static bool gentleOnly(SkinProfile profile) =>
      profile.state != '稳定' || profile.sensitivity == '容易敏感';
  static bool isActive(SkinProduct p) =>
      p.active.isNotEmpty ||
      ['精华', '去角质', '面膜', '其他'].contains(p.category) ||
      RegExp(
        r'retin|视黄|维a|水杨|果酸|焕肤|去角质|祛痘',
        caseSensitive: false,
      ).hasMatch('${p.name} ${p.ingredients.join(' ')}');
  static List<String> validate(
    SkinPlan plan,
    List<SkinProduct> products,
    SkinProfile profile,
  ) {
    final errors = <String>[];
    final byId = {for (final p in products) p.id: p};
    if (plan.name.trim().isEmpty ||
        plan.strategy.trim().isEmpty ||
        DateTime.tryParse(plan.start) == null ||
        plan.morning.length > 12 ||
        plan.evening.length > 12 ||
        (plan.morning.isEmpty && plan.evening.isEmpty)) {
      errors.add('计划内容不完整');
    }
    for (final period in ['am', 'pm']) {
      final steps = period == 'am' ? plan.morning : plan.evening;
      for (final step in steps) {
        final p = byId[step.productId];
        if (p == null || !p.usable) {
          errors.add('产品不存在、已停用或已到期：${step.name}');
          continue;
        }
        if (step.days.isEmpty ||
            step.days.toSet().length != step.days.length ||
            step.days.any((d) => d < 1 || d > 7) ||
            step.amount.trim().isEmpty ||
            step.area.trim().isEmpty) {
          errors.add('步骤用量、部位或护理日不完整');
        }
        if (!p.trusted) errors.add('${p.name} 的地区和资料版本需要核实');
        if (isActive(p) &&
            (!p.trusted || p.instructions.isEmpty || p.active.isEmpty)) {
          errors.add('${p.name} 的功效用法尚未核实');
        }
        if (p.time == '晚间' && period == 'am') errors.add('${p.name} 仅安排晚间');
        if (p.category == '防晒' && period == 'pm') errors.add('防晒仅安排早间');
        if (isActive(p) &&
            (gentleOnly(profile) ||
                profile.retinoidRestricted ||
                (profile.age != null && profile.age! < 18))) {
          errors.add('当前档案只安排基础护理');
        }
        if (isActive(p) && step.days.length > 2) errors.add('功效护理初始最多每周两次');
        if (p.active == 'retinol' && period != 'pm') errors.add('视黄醇安排在晚间');
      }
      for (var day = 1; day <= 7; day++) {
        final daily = steps.where((s) => s.days.contains(day)).toList();
        final ids = daily.map((s) => s.productId).toSet();
        if (ids.length != daily.length) errors.add('同一护理中产品重复');
        var previous = -1;
        var activeCount = 0;
        for (final s in daily) {
          final p = byId[s.productId];
          if (p == null) continue;
          final position = order[p.category] ?? 2;
          if (position < previous) errors.add('请按洁面、化妆水、精华、保湿、防晒的顺序安排');
          previous = position;
          if (isActive(p)) activeCount++;
        }
        if (activeCount > 1) errors.add('同一天仅保守安排一种功效产品');
      }
    }
    final activeDays = plan.evening
        .where((s) => byId[s.productId] != null && isActive(byId[s.productId]!))
        .expand((s) => s.days)
        .toSet();
    if (activeDays.any((d) => activeDays.contains(d == 7 ? 1 : d + 1))) {
      errors.add('初始功效护理日之间保留休息日');
    }
    return errors.toSet().toList();
  }

  static SkinPlan basic(List<SkinProduct> products, SkinProfile profile) {
    final valid =
        products
            .where(
              (p) =>
                  p.usable &&
                  p.trusted &&
                  !isActive(p) &&
                  order.containsKey(p.category),
            )
            .toList()
          ..sort((a, b) => order[a.category]!.compareTo(order[b.category]!));
    final seen = <String>{};
    final selected = valid.where((p) => seen.add(p.category)).toList();
    if (selected.isEmpty) throw StateError('请先添加并确认至少一款基础护理产品的资料版本');
    SkinStep step(SkinProduct p) => SkinStep(
      productId: p.id,
      name: p.name,
      amount: '按包装说明，适量使用',
      area: p.category == '洁面' ? '面部，避开眼睛' : '面部，避开眼周及破损处',
      note: p.instructions,
    );
    return SkinPlan(
      id: skinId(),
      name: '基础护理计划',
      strategy:
          '规则生成 · 先做好清洁、保湿与日间防护。功效产品暂不自动安排。${selected.any((p) => p.category == '防晒') ? '' : '\n护肤柜缺少已核实的防晒产品。'}\n资料与包装不同请暂停并重新核实。',
      start: skinDate(DateTime.now()),
      source: 'rules',
      morning: selected.where((p) => p.time != '晚间').map(step).toList(),
      evening: selected
          .where((p) => p.category != '防晒' && p.time != '早间')
          .map(step)
          .toList(),
    );
  }
}
