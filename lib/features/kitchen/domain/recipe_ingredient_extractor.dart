import 'kitchen_models.dart';

class ExtractedRecipeItem {
  const ExtractedRecipeItem(this.item, {required this.seasoning});
  final RecipeMaterial item;
  final bool seasoning;
}

const _foods = '''鸡肉 鸡胸肉 鸡腿肉 鸡腿 鸡翅 鸡爪 鸡蛋 鸭蛋 鹌鹑蛋 鸭肉 鸭腿 鹅肉
猪肉 猪里脊 里脊肉 五花肉 肉末 肉馅 排骨 猪蹄 猪肝 牛肉 牛腩 牛排 羊肉 羊排
鱼肉 鲫鱼 鲤鱼 草鱼 鲈鱼 带鱼 三文鱼 鳕鱼 金枪鱼 虾 虾仁 鲜虾 螃蟹 蛤蜊 扇贝 鱿鱼 墨鱼 海参
西红柿 番茄 土豆 马铃薯 红薯 紫薯 山药 芋头 南瓜 冬瓜 丝瓜 黄瓜 苦瓜 茄子 胡萝卜 白萝卜 萝卜
洋葱 青椒 红椒 彩椒 辣椒 小米椒 尖椒 白菜 大白菜 娃娃菜 包菜 卷心菜 生菜 菠菜 油菜 小白菜 空心菜
西兰花 菜花 花菜 芹菜 韭菜 韭黄 蒜苔 蒜苗 豆角 四季豆 荷兰豆 豌豆 玉米 甜玉米 莲藕 竹笋 芦笋 秋葵
香菇 蘑菇 口蘑 金针菇 杏鲍菇 平菇 木耳 银耳 海带 紫菜 豆芽 黄豆芽 绿豆芽
豆腐 嫩豆腐 老豆腐 豆干 腐竹 豆皮 黄豆 绿豆 红豆 黑豆 花生 芝麻 白芝麻 黑芝麻
大米 小米 糯米 燕麦 藜麦 面粉 低筋面粉 高筋面粉 中筋面粉 玉米淀粉 土豆淀粉 淀粉 生粉
米饭 面条 意面 粉丝 米粉 河粉 年糕 饺子皮 馄饨皮 面包 吐司 面包糠
牛奶 酸奶 淡奶油 奶油 黄油 奶酪 芝士 椰奶 椰浆 椰蓉 可可粉 巧克力 酵母
苹果 香蕉 草莓 蓝莓 柠檬 橙子 菠萝 芒果 桃子 葡萄 红枣 枸杞 葡萄干 核桃 杏仁 腰果 莲子
清水 温水 热水 冷水 水 高汤 鸡汤 骨汤
chicken chicken breast beef pork fish shrimp egg eggs potato tomato onion carrot broccoli cabbage
tofu rice noodle noodles flour milk cream butter cheese mushroom mushrooms water quinoa''';
const _spices = '''盐 食盐 海盐 糖 白糖 白砂糖 砂糖 冰糖 红糖 蜂蜜 生抽 老抽 酱油 蚝油 料酒 黄酒 米酒
醋 白醋 陈醋 米醋 香醋 食用油 油 花生油 菜籽油 玉米油 橄榄油 香油 芝麻油 猪油 辣椒油
胡椒粉 黑胡椒粉 白胡椒粉 黑胡椒 白胡椒 花椒粉 辣椒粉 孜然粉 五香粉 十三香 咖喱粉 咖喱块
鸡精 味精 豆瓣酱 郫县豆瓣酱 辣椒酱 番茄酱 甜面酱 黄豆酱 芝麻酱 沙拉酱 辣酱 豆豉 腐乳
葱 小葱 大葱 葱花 姜 生姜 姜片 姜末 蒜 大蒜 蒜瓣 蒜末 蒜蓉 香菜 干辣椒 线椒 小米辣 花椒 八角 桂皮 香叶 草果 丁香
盐水 柠檬汁 白胡椒粒 黑胡椒粒 迷迭香 百里香 罗勒 欧芹 芥末
salt sugar pepper black pepper white pepper oil olive oil soy sauce vinegar garlic ginger cumin paprika''';
const _number = r'(?:\d+\s*/\s*\d+|\d+(?:\.\d+)?|[零〇一二两三四五六七八九十百千半]+)';
const _units =
    r'(?:千克|公斤|毫克|毫升|公升|小勺|大勺|汤勺|茶匙|汤匙|tbsp|tsp|kg|mg|ml|克|斤|两|升|g|l|勺|个|颗|根|片|块|碗|杯|袋|滴|撮)';
final _beforeAmount = RegExp(
  '($_number)\\s*($_units)\\s*(?:的)?\\s*\$',
  caseSensitive: false,
);
final _afterAmount = RegExp(
  '^\\s*[（(：:]?\\s*(?:约|大约|各)?\\s*($_number)\\s*($_units)',
  caseSensitive: false,
);
final _actions = RegExp(
  r'^(?:(?:先|再|然后|接着|最后|把|将|加入|放入|倒入|撒入|拌入|准备|备好|取出|取|加|放|倒|撒|适量|少许|新鲜|洗净的|切好的)\s*)+',
  caseSensitive: false,
);
final _cookingTail = RegExp(
  r'切成|切块|切片|切丝|切丁|切碎|洗净|清洗|翻炒|炒匀|炒熟|煮熟|蒸熟|焯水|搅拌|拌匀|腌制|备用|下锅|烧开|沥干|炒至|煮至|倒入|加入|放入|撒入|即可|均匀',
);

String _key(String name) =>
    name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

bool _negated(String text, int start) {
  final prefix = text.substring(0, start).split(RegExp(r'[，,。；;\n]')).last;
  return RegExp(
    r'(?:不加入|不放|不加|不要加|不要放|无需|不用|不需要|省略|去掉|避免加入)\s*$',
  ).hasMatch(prefix);
}

double? _readNumber(String text) {
  text = text.replaceAll(' ', '');
  final number = double.tryParse(text);
  if (number != null) return number.isFinite && number > 0 ? number : null;
  if (text.contains('/')) {
    final parts = text.split('/').map(double.tryParse).toList();
    if (parts.length != 2 || parts.any((p) => p == null) || parts[1] == 0) {
      return null;
    }
    final value = parts[0]! / parts[1]!;
    return value.isFinite && value > 0 ? value : null;
  }
  if (text == '半') return .5;
  const digits = {
    '零': 0,
    '〇': 0,
    '一': 1,
    '二': 2,
    '两': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '七': 7,
    '八': 8,
    '九': 9,
  };
  const scales = {'十': 10, '百': 100, '千': 1000};
  var total = 0, current = 0;
  for (final char in text.split('')) {
    if (digits.containsKey(char)) {
      current = digits[char]!;
    } else if (scales.containsKey(char)) {
      total += (current == 0 ? 1 : current) * scales[char]!;
      current = 0;
    } else {
      return null;
    }
  }
  final value = total + current;
  return value > 0 ? value.toDouble() : null;
}

String _unit(String unit) => switch (unit.toLowerCase()) {
  '克' => 'g',
  '千克' || '公斤' => 'kg',
  '毫升' => 'ml',
  '毫克' => 'mg',
  '升' || '公升' => 'l',
  'tsp' || '茶匙' => '小勺',
  'tbsp' || '汤匙' || '汤勺' => '大勺',
  _ => unit.toLowerCase(),
};

({double? amount, String unit}) _quantity(String text, int start, int end) {
  final suffix = _afterAmount.firstMatch(text.substring(end));
  final prefixText = text.substring(0, start);
  final prefix = _beforeAmount.firstMatch(prefixText);
  final match = suffix ?? prefix;
  if (match == null) return (amount: null, unit: '');
  if (suffix == null &&
      prefix != null &&
      prefix.start > 0 &&
      RegExp(r'[-－~～至到]').hasMatch(prefixText[prefix.start - 1])) {
    return (amount: null, unit: '');
  }
  final amount = _readNumber(match.group(1)!);
  return (amount: amount, unit: amount == null ? '' : _unit(match.group(2)!));
}

/// Conservative local parsing; names remain editable in the recipe form.
List<ExtractedRecipeItem> extractRecipeIngredients(
  String text, {
  List<RecipeMaterial> materials = const [],
  List<RecipeMaterial> seasonings = const [],
}) {
  text = String.fromCharCodes(
    text.runes.map((c) => c >= 0xFF10 && c <= 0xFF19 ? c - 0xFEE0 : c),
  );
  final names = <String, ({String name, bool seasoning})>{};
  for (final name in _foods.split(RegExp(r'\s+')).where((n) => n.isNotEmpty)) {
    names[_key(name)] = (name: name, seasoning: false);
  }
  for (final name in _spices.split(RegExp(r'\s+')).where((n) => n.isNotEmpty)) {
    names[_key(name)] = (name: name, seasoning: true);
  }
  for (final item in materials) {
    names[_key(item.name)] = (name: item.name, seasoning: false);
  }
  for (final item in seasonings) {
    names[_key(item.name)] = (name: item.name, seasoning: true);
  }
  final sorted = names.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final pattern = RegExp(
    sorted.map(RegExp.escape).join('|'),
    caseSensitive: false,
  );
  final result = <String, ExtractedRecipeItem>{};
  void add(String name, bool seasoning, double? amount, String unit) {
    final key = _key(name);
    final existing = result[key];
    if (existing != null && (existing.item.amount != null || amount == null)) {
      return;
    }
    result[key] = ExtractedRecipeItem(
      RecipeMaterial(name: name, amount: amount, unit: unit),
      seasoning: seasoning,
    );
  }

  for (final match in pattern.allMatches(text)) {
    final raw = match.group(0)!;
    if (_negated(text, match.start)) continue;
    if (RegExp(r'[A-Za-z]').hasMatch(raw)) {
      if (match.start > 0 &&
          RegExp(r'[A-Za-z]').hasMatch(text[match.start - 1])) {
        continue;
      }
      if (match.end < text.length &&
          RegExp(r'[A-Za-z]').hasMatch(text[match.end])) {
        continue;
      }
    }
    if (raw == '水' &&
        match.start > 0 &&
        RegExp(r'[焯沥控脱过]').hasMatch(text[match.start - 1])) {
      continue;
    }
    final entry = names[_key(raw)]!;
    final quantity = _quantity(text, match.start, match.end);
    add(entry.name, entry.seasoning, quantity.amount, quantity.unit);
  }

  // A limited fallback for uncommon names in explicit ingredient phrases.
  for (var clause in text.split(
    RegExp(r'[，,。；;\n、]|\b(?:and|then)\b', caseSensitive: false),
  )) {
    clause = clause.trim();
    if (clause.isEmpty ||
        RegExp(r'不加|不放|不要|无需|不用|不需要|省略|去掉').hasMatch(clause)) {
      continue;
    }
    final hasAction =
        _actions.hasMatch(clause) ||
        RegExp(
          r'^(?:add|put|pour|sprinkle|prepare)\s+',
          caseSensitive: false,
        ).hasMatch(clause);
    clause = clause
        .replaceFirst(_actions, '')
        .replaceFirst(
          RegExp(
            r'^(?:add|put|pour|sprinkle|prepare)\s+',
            caseSensitive: false,
          ),
          '',
        );
    final original = clause;
    clause = clause.split(_cookingTail).first.trim();
    var amountMatch = RegExp(
      '($_number)\\s*($_units)',
      caseSensitive: false,
    ).firstMatch(clause);
    if (!hasAction && amountMatch == null) continue;
    if (amountMatch != null) {
      clause = clause
          .replaceRange(amountMatch.start, amountMatch.end, '')
          .trim();
    }
    clause = clause
        .replaceFirst(RegExp(r'^(?:的|适量|少许)\s*'), '')
        .replaceAll(RegExp(r'[（）：:()]'), '')
        .trim();
    if (clause.length < 2 ||
        clause.length > 16 ||
        !RegExp(
          r'^[\u4e00-\u9fffA-Za-z][\u4e00-\u9fffA-Za-z -]*$',
        ).hasMatch(clause)) {
      continue;
    }
    if (pattern.hasMatch(clause) ||
        RegExp(
          r'锅|碗|盘|刀|筷|铲|烤箱|冰箱|分钟|小时|温度|大火|小火|中火|食材|调料|均匀|沸腾|加热|煮熟|准备好',
        ).hasMatch(clause)) {
      continue;
    }
    if (amountMatch != null && RegExp(r'[-－~～]').hasMatch(original)) continue;
    final amount = amountMatch == null
        ? null
        : _readNumber(amountMatch.group(1)!);
    final seasoning = RegExp(r'酱|醋|油|糖|盐|调味|香料').hasMatch(clause);
    add(
      clause,
      seasoning,
      amount,
      amount == null ? '' : _unit(amountMatch!.group(2)!),
    );
  }
  return result.values.toList();
}

({
  List<RecipeMaterial> materials,
  List<RecipeMaterial> seasonings,
  RecipeStep step,
  int changed,
})
mergeStepIngredients(
  RecipeStep step, {
  required List<RecipeMaterial> materials,
  required List<RecipeMaterial> seasonings,
}) {
  final foods = [...materials], spices = [...seasonings];
  final foodNames = {...step.materials}, spiceNames = {...step.seasonings};
  var changed = 0;
  for (final found in extractRecipeIngredients(
    '${step.name}，${step.content}',
    materials: materials,
    seasonings: seasonings,
  )) {
    final target = found.seasoning ? spices : foods;
    final linked = found.seasoning ? spiceNames : foodNames;
    final index = target.indexWhere(
      (item) => _key(item.name) == _key(found.item.name),
    );
    if (index < 0) {
      target.add(
        RecipeMaterial(
          name: found.item.name,
          amount: found.item.amount,
          unit: found.item.unit,
          sort: target.length + 1,
        ),
      );
      changed++;
      linked.add(found.item.name);
    } else {
      final old = target[index], incoming = found.item;
      linked.add(old.name);
      if (old.amount == null &&
          incoming.amount != null &&
          (old.unit.isEmpty || _unit(old.unit) == incoming.unit)) {
        target[index] = RecipeMaterial(
          name: old.name,
          amount: incoming.amount,
          unit: old.unit.isEmpty ? incoming.unit : old.unit,
          sort: old.sort,
          remark: old.remark,
          stage: old.stage,
        );
        changed++;
      }
    }
  }
  return (
    materials: foods,
    seasonings: spices,
    changed: changed,
    step: RecipeStep(
      name: step.name,
      content: step.content,
      duration: step.duration,
      parallelWithPrevious: step.parallelWithPrevious,
      materials: foodNames.toList(),
      seasonings: spiceNames.toList(),
      image: step.image,
      video: step.video,
    ),
  );
}
