import 'dart:convert';
import 'package:flutter/services.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/weather_service.dart';
import '../../kitchen/data/kitchen_repository.dart';
import '../../kitchen/domain/kitchen_export.dart';
import '../../kitchen/domain/shopping_list.dart';
import '../../skincare/data/skincare_repository.dart';
import '../../skincare/domain/skincare_models.dart';
import '../../wardrobe/data/wardrobe_repository.dart';
import '../../wardrobe/domain/models/clothing_parameter.dart';
import '../domain/search_document.dart';

class SearchRepository {
  SearchRepository({
    required this.kitchen,
    required this.wardrobe,
    required this.skincare,
    required this.home,
    QWeatherService? weather,
    DateTime Function()? clock,
  }) : weather = weather ?? QWeatherService(),
       clock = clock ?? DateTime.now;
  final KitchenRepository kitchen;
  final WardrobeRepository wardrobe;
  final SkincareRepository skincare;
  final HomeRepository home;
  final QWeatherService weather;
  final DateTime Function() clock;

  Future<List<SearchDocument>> knowledge() async {
    final data =
        jsonDecode(
              await rootBundle.loadString('assets/data/search_knowledge.json'),
            )
            as Map;
    return (data['entries'] as List).map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      return SearchDocument(
        id: 'help:${m['id']}',
        title: m['title'] as String,
        category: SearchCategory.values.byName(m['category'] as String),
        kind: SearchKind.help,
        target: m['target'] as String,
        body: m['body'] as String,
        keywords: List<String>.from(m['keywords'] as List),
        question: true,
        source: 'LifeAtlas 使用说明 · 知识库 v${data['version']}',
        time: '${data['updated']}',
      );
    }).toList();
  }

  static final templates = <SearchDocument>[
    SearchDocument(
      id: 'current:shopping',
      title: '购物清单还缺什么？',
      category: SearchCategory.kitchen,
      kind: SearchKind.current,
      target: 'shopping',
      question: true,
      keywords: ['购物清单', '还缺什么', '待准备', '买菜还缺什么'],
    ),
    SearchDocument(
      id: 'current:skin-am',
      title: '今天早上的护肤步骤是什么？',
      category: SearchCategory.skincare,
      kind: SearchKind.current,
      target: 'skincare',
      question: true,
      keywords: ['今天早上', '早间护肤', '早上护肤'],
    ),
    SearchDocument(
      id: 'current:skin-pm',
      title: '今晚的护肤步骤是什么？',
      category: SearchCategory.skincare,
      kind: SearchKind.current,
      target: 'skincare',
      question: true,
      keywords: ['今晚', '今晚护肤', '晚间护肤', '晚上护肤'],
    ),
    SearchDocument(
      id: 'current:weather-now',
      title: '今天所选城市的天气怎么样？',
      category: SearchCategory.calendar,
      kind: SearchKind.current,
      target: 'weather',
      question: true,
      keywords: ['今天天气', '当前天气', '现在温度', '天气怎么样'],
    ),
    SearchDocument(
      id: 'current:weather-today',
      title: '今天的逐小时天气怎么样？',
      category: SearchCategory.calendar,
      kind: SearchKind.current,
      target: 'weather',
      question: true,
      keywords: ['今天逐小时', '今天小时天气', '今天上午天气', '今天下午天气'],
    ),
    SearchDocument(
      id: 'current:weather-tomorrow',
      title: '明天的逐小时天气怎么样？',
      category: SearchCategory.calendar,
      kind: SearchKind.current,
      target: 'weather',
      question: true,
      keywords: ['明天天气', '明天上午的天气', '明天上午天气', '明天逐小时', '明天温度'],
    ),
    SearchDocument(
      id: 'current:last-saturday',
      title: '上周六穿了什么？',
      category: SearchCategory.calendar,
      kind: SearchKind.current,
      target: 'day',
      question: true,
      keywords: ['上周六', '上周六穿搭'],
    ),
  ];

  /// Independent adapters fail separately. This is an ephemeral local view,
  /// not a copy of settings, credentials or the encrypted body vault.
  Future<SearchSnapshot> load() async {
    final documents = <SearchDocument>[...templates];
    final failures = <String>[];
    Future<void> collect(
      String name,
      Future<List<SearchDocument>> Function() read,
    ) async {
      try {
        documents.addAll(await read());
      } catch (_) {
        failures.add(name);
      }
    }

    await Future.wait([
      collect('使用说明', knowledge),
      collect('菜谱', _recipes),
      collect('库存', _inventory),
      collect('衣服', _clothes),
      collect('套装', _sets),
      collect('预购', _preorders),
      collect('护肤产品', _products),
      collect('护肤计划', _plan),
      collect('护肤执行记录', _executions),
      collect('日历记录', _days),
    ]);
    return SearchSnapshot(documents, failures);
  }

  SearchDocument _record({
    required String id,
    required String title,
    required SearchCategory category,
    required String target,
    required String entityId,
    required String body,
    String source = 'LifeAtlas 本地记录',
    String time = '',
    String image = '',
    String sourceUrl = '',
    List<String> keywords = const [],
  }) => SearchDocument(
    id: id,
    title: title,
    category: category,
    kind: SearchKind.record,
    target: target,
    entityId: entityId,
    body: body,
    source: source,
    time: time,
    image: image,
    sourceUrl: sourceUrl,
    keywords: keywords,
  );

  Future<List<SearchDocument>> _recipes() async => [
    for (final r in await kitchen.listRecipes())
      _record(
        id: 'recipe:${r.id}',
        title: r.name,
        category: SearchCategory.kitchen,
        target: 'recipe',
        entityId: '${r.id}',
        body: KitchenExport.recipe(r).sections.join('\n\n'),
        image: r.image,
        source: switch (r.sourceType) {
          'personal' => '你的菜谱',
          'public' => '已保存公共菜谱',
          'preset' => '内置菜谱',
          'ai' => '已保存的 AI 菜谱',
          _ => '已保存菜谱',
        },
        keywords: [
          ...r.categories,
          ...r.materials.map((m) => m.name),
          ...r.seasonings.map((m) => m.name),
        ],
      ),
  ];

  Future<List<SearchDocument>> _inventory() async => [
    for (final i in await kitchen.listInventory())
      _record(
        id: 'inventory:${i.id}',
        title: i.name,
        category: SearchCategory.kitchen,
        target: 'inventory',
        entityId: '${i.id}',
        time: i.updatedAt.toIso8601String(),
        keywords: ['库存', '食材库存'],
        body:
            '库存：${i.amount} ${i.unit}\n'
            '${i.expireDate == null ? '未填写到期日期' : '到期日期：${i.expireDate!.toIso8601String().split('T').first}'}\n${i.remark}',
      ),
  ];

  Future<List<SearchDocument>> _clothes() async => [
    for (final i in await wardrobe.listClothing())
      _record(
        id: 'clothing:${i.id}',
        title: i.name,
        category: SearchCategory.wardrobe,
        target: 'clothing',
        entityId: '${i.id}',
        image: i.imagePath,
        time: i.updatedAt.toIso8601String(),
        keywords: [
          '衣服',
          i.category ?? '',
          i.color ?? '',
          i.brand ?? '',
          ...i.seasonTags,
        ],
        body: [
          '品类：${i.category ?? '未填写'} · 颜色：${i.color ?? '未填写'}',
          '品牌：${i.brand ?? '未填写'} · 尺码：${i.size ?? '未填写'}',
          '季节：${i.seasonTags.join('、')} · 材质：${i.material ?? '未填写'}',
          for (final pair in {
            '衣长': i.clothingLength,
            '肩宽': i.shoulderWidth,
            '胸围': i.chestCircumference,
            '袖长': i.sleeveLength,
            '腰围': i.waistCircumference,
            '臀围': i.hipCircumference,
            '裤长': i.trouserLength,
          }.entries)
            if (pair.value != null) '${pair.key}：${pair.value} cm',
          for (final definition in ClothingParameterCatalog.definitions)
            if (i.parameterValues[definition.key] case final value?)
              if (!value.isEmpty)
                '${definition.label}：${value.displayValue(definition)}',
          if (i.notes?.isNotEmpty == true) '备注：${i.notes}',
        ].join('\n'),
      ),
  ];

  Future<List<SearchDocument>> _sets() async {
    final clothes = {
      for (final c in await wardrobe.listClothing()) c.id: c.name,
    };
    return [
      for (final s in await wardrobe.listOutfitSets())
        _record(
          id: 'set:${s.id}',
          title: s.name,
          category: SearchCategory.wardrobe,
          target: 'set',
          entityId: '${s.id}',
          time: s.updatedAt.toIso8601String(),
          keywords: ['套装', ...s.seasonTags],
          body:
              '季节：${s.seasonTags.join('、')}\n搭配衣物：\n${s.clothingItemIds.map((id) => clothes[id] ?? '已删除衣服').join('\n')}',
        ),
    ];
  }

  Future<List<SearchDocument>> _preorders() async => [
    for (final i in await wardrobe.listPreorders(includePurchased: true))
      _record(
        id: 'preorder:${i.id}',
        title: i.name ?? '未命名心仪衣服',
        category: SearchCategory.wardrobe,
        target: 'preorder',
        entityId: '${i.id}',
        image: i.imagePath,
        time: i.updatedAt.toIso8601String(),
        keywords: ['预购', '心仪衣服', i.brand ?? '', i.category ?? ''],
        body: [
          '品牌：${i.brand ?? '未填写'}\n品类：${i.category ?? '未填写'}\n尺码：${i.size ?? '未填写'}',
          '价格：${i.price ?? '未填写'} · 材质：${i.material ?? '未填写'}',
          '状态：${i.isPurchased ? '已购买' : '心仪未购买'}',
          for (final pair in {
            '衣长': i.clothingLength,
            '肩宽': i.shoulderWidth,
            '胸围': i.chestCircumference,
            '袖长': i.sleeveLength,
            '腰围': i.waistCircumference,
            '臀围': i.hipCircumference,
            '裤长': i.trouserLength,
          }.entries)
            if (pair.value != null) '${pair.key}：${pair.value} cm',
          i.description ?? '',
          i.notes ?? '',
        ].where((line) => line.isNotEmpty).join('\n'),
      ),
  ];

  Future<List<SearchDocument>> _products() async => [
    for (final p in await skincare.products())
      _record(
        id: 'product:${p.id}',
        title: p.name,
        category: SearchCategory.skincare,
        target: 'product',
        entityId: p.id,
        image: p.image,
        sourceUrl: p.source,
        time: p.verifiedAt,
        source: '你的护肤柜 · ${p.trusted ? '版本已确认' : '资料待核实'}',
        keywords: [p.brand, p.category, ...p.ingredients],
        body:
            '${p.brand} · ${p.category} · ${p.size}\n状态：${p.status}\n'
            '地区/配方：${p.region} ${p.formula}\n成分：${p.ingredients.join('、')}\n'
            '使用说明：${p.instructions.isEmpty ? '未填写' : p.instructions}\n注意事项：${p.cautions.isEmpty ? '未填写' : p.cautions}\n'
            '来源：${p.source.isEmpty ? '未提供' : p.source}',
      ),
  ];

  String _steps(List<SkinStep> steps) => steps.isEmpty
      ? '没有已安排的步骤'
      : [
          for (var n = 0; n < steps.length; n++)
            '${n + 1}. ${steps[n].name}\n用量：${steps[n].amount} · 部位：${steps[n].area}\n'
                '每周：${steps[n].days.join('、')}\n${steps[n].note}',
        ].join('\n\n');

  Future<List<SearchDocument>> _plan() async {
    final p = await skincare.activePlan();
    if (p == null) return [];
    return [
      _record(
        id: 'plan:${p.id}',
        title: p.name,
        category: SearchCategory.skincare,
        target: 'plan',
        entityId: p.id,
        time: p.start,
        keywords: ['护肤计划', '已启用计划'],
        source: '你的已启用计划 · ${p.source}',
        body:
            '开始日期：${p.start}\n${p.strategy}\n\n早间\n${_steps(p.morning)}\n\n晚间\n${_steps(p.evening)}',
      ),
    ];
  }

  Future<List<SearchDocument>> _executions() async => [
    for (final e in await skincare.history(limit: null))
      _record(
        id: 'execution:${e.date}:${e.period}',
        title: '${e.date} ${e.period == 'am' ? '早间' : '晚间'}护肤记录',
        category: SearchCategory.skincare,
        target: 'execution',
        entityId: '${e.date}|${e.period}',
        time: e.updated,
        keywords: ['护肤历史', e.date],
        body:
            '执行状态：${e.status}\n${[for (var i = 0; i < e.steps.length; i++) '${i + 1}. ${e.steps[i].name} · ${i < e.states.length ? _skinState(e.states[i]) : '未记录'}\n用量：${e.steps[i].amount} · 部位：${e.steps[i].area}'].join('\n')}',
      ),
  ];

  static String _skinState(String state) => switch (state) {
    'done' => '已完成',
    'skipped' => '已跳过',
    _ => '未完成',
  };

  Future<List<SearchDocument>> _days() async => [
    for (final d in await home.searchDays())
      _record(
        id: 'day:${skinDate(d.date)}',
        title: '${skinDate(d.date)} 生活记录',
        category: SearchCategory.calendar,
        target: 'day',
        entityId: skinDate(d.date),
        time: skinDate(d.date),
        keywords: ['日历', '穿搭记录', skinDate(d.date)],
        body:
            '${d.textEntries.join('\n\n')}\n\n${d.hasOutfitRecord ? '当日穿搭：${d.outfitItems.isEmpty ? '未保存衣物明细' : d.outfitItems.map((i) => i.name).join('、')}' : '没有当日穿搭记录'}',
      ),
  ];

  /// Always re-read a selected source. A stale search card is never authority
  /// for exporting or opening an edited/deleted record.
  Future<SearchDocument> resolve(SearchDocument doc) async {
    if (doc.kind == SearchKind.help) return doc;
    if (doc.id == 'current:shopping') return _shopping(doc);
    if (doc.id.startsWith('current:skin-')) return _skin(doc);
    if (doc.id.startsWith('current:weather-')) return _weather(doc);
    if (doc.id == 'current:last-saturday') {
      final now = clock();
      final monday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
      final date = monday.subtract(const Duration(days: 2));
      final days = await home.loadMonth(DateTime(date.year, date.month));
      final day = days[date];
      return _current(
        doc,
        '${skinDate(date)}\n${day?.hasOutfitRecord == true ? (day!.outfitItems.isEmpty ? '有穿搭记录，未保存衣物明细' : day.outfitItems.map((i) => i.name).join('、')) : '没有保存当天的穿搭记录'}',
        entityId: skinDate(date),
      );
    }
    final read = switch (doc.target) {
      'recipe' => _recipes,
      'inventory' => _inventory,
      'clothing' => _clothes,
      'set' => _sets,
      'preorder' => _preorders,
      'product' => _products,
      'plan' => _plan,
      'execution' => _executions,
      'day' => _days,
      _ => null,
    };
    if (read == null) throw StateError('内容暂不可用');
    final matches = (await read()).where((d) => d.id == doc.id);
    if (matches.isEmpty) throw StateError('原记录已删除或已变更，请重新搜索');
    return doc.question ? recordQuestion(matches.single) : matches.single;
  }

  SearchDocument _current(
    SearchDocument d,
    String body, {
    String? entityId,
    String? time,
    String? source,
    String sourceUrl = '',
  }) => SearchDocument(
    id: d.id,
    title: d.title,
    category: d.category,
    kind: d.kind,
    target: d.target,
    entityId: entityId ?? d.entityId,
    body: body,
    source: source ?? 'LifeAtlas 当前已保存数据',
    time: time ?? clock().toIso8601String(),
    sourceUrl: sourceUrl,
    question: true,
    keywords: d.keywords,
  );

  Future<SearchDocument> _shopping(SearchDocument d) async {
    final recipes = await kitchen.listRecipes();
    final state = await kitchen.loadShoppingList();
    final selected = recipes
        .where((r) => state.recipeIds.contains(r.id))
        .toList();
    final missing = buildShoppingList(
      selected,
      servings: state.servings,
    ).where((i) => !state.prepared.contains(i.key)).toList();
    return _current(
      d,
      selected.isEmpty
          ? '还没有选择菜谱。请打开购物清单，选择需要制作的菜谱。'
          : '所选菜谱：${selected.map((r) => '${r.name} × ${state.portions(r.id!)}份').join('、')}\n\n'
                '${missing.isEmpty ? '清单中的用料均已勾选为已准备。' : '待准备：\n${missing.map((i) => '${i.name}  ${i.quantity}').join('\n')}'}\n\n依据清单的勾选状态，不自动扣减库存。',
    );
  }

  Future<SearchDocument> _skin(SearchDocument d) async {
    final now = clock();
    final period = d.id.endsWith('am') ? 'am' : 'pm';
    final execution = await skincare.execution(skinDate(now), period);
    if (execution != null) {
      return _current(
        d,
        '${skinDate(now)} ${period == 'am' ? '早间' : '晚间'} · ${execution.status}\n\n${_steps(execution.steps)}',
        time: execution.updated,
      );
    }
    final p = await skincare.activePlan();
    return _current(
      d,
      p == null
          ? '尚未启用护肤计划，请到护肤板块建立并确认计划。'
          : '${skinDate(now)} ${period == 'am' ? '早间' : '晚间'} · 已启用计划：${p.name}\n\n${_steps(p.steps(now, period))}\n\n尚未保存本次执行记录。',
    );
  }

  Future<SearchDocument> _weather(SearchDocument d) async {
    final city = await weather.selectedCity();
    if (city == null) return _current(d, '尚未选择城市，请打开天气与城市设置。');
    late SearchDocument result;
    if (d.id.endsWith('now')) {
      final value = await weather.getCurrentWeather(citySnapshot: city);
      result = _current(
        d,
        '${value.region} · ${value.date}\n${value.status}\n当前 ${value.currentTemperature}℃\n今日 ${value.minTemperature}～${value.maxTemperature}℃'
        '${value.cached ? '\n使用缓存，实时请求未成功' : ''}\n${value.warning}',
        time: value.fetchedAt,
        source: '和风天气',
        sourceUrl: 'https://www.qweather.com/',
      );
    } else {
      final forecast = await weather.getHourlyWeather(citySnapshot: city);
      final offset = d.id.endsWith('tomorrow') ? 1 : 0;
      final now = clock();
      final local = forecast.local(now);
      final date = DateTime(local.year, local.month, local.day + offset);
      final hours = forecast.day(offset, now);
      result = _current(
        d,
        '${city['name']} · ${skinDate(date)} · 当地时间（${forecast.zone}）\n\n'
        '${hours.isEmpty ? '暂无该日期的有效小时预报' : hours.map((h) {
                final t = forecast.local(h.time);
                return '${t.hour.toString().padLeft(2, '0')}:00  ${h.status}  ${h.temperature}℃';
              }).join('\n')}'
        '${forecast.cached ? '\n\n使用缓存，实时请求未成功' : ''}\n${forecast.warning}',
        time: forecast.fetchedAt.toIso8601String(),
        source: '和风天气',
        sourceUrl: 'https://www.qweather.com/',
      );
    }
    final current = await weather.selectedCity();
    if (current?['id'] != city['id'] || current?['tz'] != city['tz']) {
      throw StateError('城市已切换，请重新查询');
    }
    return result;
  }
}
