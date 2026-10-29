import 'dart:io';
import 'package:lifeatlas/features/skincare/domain/skincare_models.dart';
import 'package:lifeatlas/features/skincare/domain/skincare_rules.dart';

void check(bool value, String label) {
  if (!value) throw StateError(label);
  stdout.writeln('PASS $label');
}

void main() {
  final cream = SkinProduct(
    id: 'cream',
    name: '面霜',
    category: '面霜',
    evidence: 'verified',
    versionConfirmed: true,
    instructions: '按包装',
  );
  final sun = SkinProduct(
    id: 'sun',
    name: '防晒',
    category: '防晒',
    evidence: 'verified',
    versionConfirmed: true,
    instructions: '按包装',
  );
  final ret = SkinProduct(
    id: 'ret',
    name: '视黄醇',
    category: '精华',
    evidence: 'verified',
    versionConfirmed: true,
    instructions: '晚间使用',
    active: 'retinol',
    time: '晚间',
  );
  final profile = SkinProfile(goals: ['保湿补水']);
  final products = [cream, sun, ret];
  final base = SkincareRules.basic(products, profile);
  check(base.morning.last.productId == 'sun', '早间防晒在最后');
  check(
    base.evening.length == 1 && base.evening.first.productId == 'cream',
    '基础方案排除功效品',
  );
  check(SkincareRules.validate(base, products, profile).isEmpty, '基础计划通过校验');
  check(
    SkinPlan.fromJson(
      base.toJson(),
    ).steps(DateTime.now().subtract(Duration(days: 1)), 'am').isEmpty,
    '开始日期之前不生成任务',
  );
  SkinStep step(List<int> days) => SkinStep(
    productId: 'ret',
    name: '视黄醇',
    amount: '按包装',
    area: '面部',
    days: days,
  );
  SkinPlan plan(List<SkinStep> am, List<SkinStep> pm) => SkinPlan(
    id: 'v',
    name: '测试',
    strategy: '说明',
    start: '2026-10-29',
    source: 'ai',
    morning: am,
    evening: pm,
  );
  check(
    SkincareRules.validate(
      plan([
        step([1]),
      ], []),
      products,
      profile,
    ).isNotEmpty,
    '拦截早间视黄醇',
  );
  check(
    SkincareRules.validate(
      plan([], [
        step([1, 2]),
      ]),
      products,
      profile,
    ).isNotEmpty,
    '拦截连续功效护理日',
  );
  check(
    SkincareRules.validate(
      plan([], [
        step([1, 4]),
      ]),
      products,
      profile,
    ).isEmpty,
    '保守夜间间隔安排',
  );
  check(
    SkincareRules.validate(
      plan([], [
        step([1, 4]),
      ]),
      products,
      SkinProfile(state: '泛红'),
    ).isNotEmpty,
    '状态不稳定拦截功效护理',
  );
  check(
    SkincareRules.validate(
      plan([], [
        step([1]),
      ]),
      products,
      SkinProfile(retinoidRestricted: true),
    ).isNotEmpty,
    '限制维A人群采用基础护理',
  );
  check(
    SkincareRules.validate(
      plan([], [
        step([1]),
      ]),
      [],
      profile,
    ).isNotEmpty,
    '拒绝虚构产品ID',
  );
  check(
    SkincareRules.validate(
      plan([], [
        step([8]),
      ]),
      products,
      profile,
    ).isNotEmpty,
    '拒绝无效星期',
  );
  check(
    SkincareRules.validate(
      plan([], [
        step([1]),
      ]),
      [
        ret.copy({'evidence': 'ai'}),
      ],
      profile,
    ).isNotEmpty,
    'AI资料保持待核实',
  );
  final entry = SkinExecution(
    date: '2026-10-29',
    period: 'pm',
    planId: 'v',
    steps: [
      step([1]),
    ],
    states: ['skipped'],
  );
  check(entry.status == '部分完成' && entry.finished, '跳过步骤标为部分完成');
  check(
    SkinExecution.fromJson(entry.toJson()).steps.first.name == '视黄醇',
    '历史快照往返',
  );
}
