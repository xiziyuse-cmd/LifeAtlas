import 'dart:convert';

String skinDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
List<String> strings(Object? value) => (value as List? ?? []).cast<String>();
Map<String, dynamic> object(Object? value) =>
    Map<String, dynamic>.from(value as Map);
String skinId() => DateTime.now().microsecondsSinceEpoch.toString();
const skinCategories = ['洁面', '化妆水', '精华', '乳液', '面霜', '防晒', '面膜', '去角质', '其他'];
const skinGoals = [
  '保湿补水',
  '控油',
  '改善痘痘与闭口',
  '淡化痘印',
  '提亮肤色',
  '改善毛孔外观',
  '抗氧化',
  '初老护理',
  '舒缓修护',
];
const skinIssues = ['干燥', '出油', '痘痘', '闭口', '痘印', '暗沉', '毛孔明显', '泛红', '敏感'];

class SkinProfile {
  SkinProfile({
    this.age,
    this.type = '不确定',
    this.sensitivity = '不确定',
    this.state = '稳定',
    this.retinoidRestricted = false,
    Map<String, List<String>>? areas,
    List<String>? goals,
  }) : areas = areas ?? {},
       goals = goals ?? [];
  final int? age;
  final String type, sensitivity, state;
  final bool retinoidRestricted;
  final Map<String, List<String>> areas;
  final List<String> goals;
  Map<String, dynamic> toJson() => {
    'age': age,
    'type': type,
    'sensitivity': sensitivity,
    'state': state,
    'retinoidRestricted': retinoidRestricted,
    'areas': areas,
    'goals': goals,
  };
  factory SkinProfile.fromJson(Map<String, dynamic> m) => SkinProfile(
    age: m['age'] as int?,
    type: m['type'] as String,
    sensitivity: m['sensitivity'] as String,
    state: m['state'] as String,
    retinoidRestricted: m['retinoidRestricted'] == true,
    areas: object(m['areas']).map((k, v) => MapEntry(k, strings(v))),
    goals: strings(m['goals']),
  );
}

class SkinProduct {
  SkinProduct({
    required this.id,
    required this.name,
    this.brand = '',
    this.category = '其他',
    this.region = '',
    this.formula = '',
    this.size = '',
    this.barcode = '',
    this.source = '',
    this.verifiedAt = '',
    this.evidence = 'unknown',
    this.versionConfirmed = false,
    this.catalogId = '',
    this.catalogVersion = 0,
    this.instructions = '',
    this.cautions = '',
    this.image = '',
    this.status = '使用中',
    this.opened = '',
    this.expires = '',
    List<String>? ingredients,
    List<String>? claims,
    this.active = '',
    this.concentration,
    this.time = '未知',
  }) : ingredients = ingredients ?? [],
       claims = claims ?? [];
  final String id,
      name,
      brand,
      category,
      region,
      formula,
      size,
      barcode,
      source,
      verifiedAt,
      evidence,
      catalogId,
      instructions,
      cautions,
      image,
      status,
      opened,
      expires,
      active,
      time;
  final int catalogVersion;
  final bool versionConfirmed;
  final String? concentration;
  final List<String> ingredients, claims;
  bool get trusted => evidence == 'verified' && versionConfirmed;
  bool get usable =>
      status == '使用中' &&
      (expires.isEmpty || expires.compareTo(skinDate(DateTime.now())) >= 0);
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'brand': brand,
    'category': category,
    'region': region,
    'formula': formula,
    'size': size,
    'barcode': barcode,
    'source': source,
    'verifiedAt': verifiedAt,
    'evidence': evidence,
    'versionConfirmed': versionConfirmed,
    'catalogId': catalogId,
    'catalogVersion': catalogVersion,
    'instructions': instructions,
    'cautions': cautions,
    'image': image,
    'status': status,
    'opened': opened,
    'expires': expires,
    'ingredients': ingredients,
    'claims': claims,
    'active': active,
    'concentration': concentration,
    'time': time,
  };
  factory SkinProduct.fromJson(Map<String, dynamic> m) => SkinProduct(
    id: m['id'] as String,
    name: m['name'] as String,
    brand: m['brand'] as String? ?? '',
    category: m['category'] as String? ?? '其他',
    region: m['region'] as String? ?? '',
    formula: m['formula'] as String? ?? '',
    size: m['size'] as String? ?? '',
    barcode: m['barcode'] as String? ?? '',
    source: m['source'] as String? ?? '',
    verifiedAt: m['verifiedAt'] as String? ?? '',
    evidence: m['evidence'] as String? ?? 'unknown',
    versionConfirmed: m['versionConfirmed'] == true,
    catalogId: m['catalogId'] as String? ?? '',
    catalogVersion: m['catalogVersion'] as int? ?? 0,
    instructions: m['instructions'] as String? ?? '',
    cautions: m['cautions'] as String? ?? '',
    image: m['image'] as String? ?? '',
    status: m['status'] as String? ?? '使用中',
    opened: m['opened'] as String? ?? '',
    expires: m['expires'] as String? ?? '',
    ingredients: strings(m['ingredients']),
    claims: strings(m['claims']),
    active: m['active'] as String? ?? '',
    concentration: m['concentration'] as String?,
    time: m['time'] as String? ?? '未知',
  );
  SkinProduct copy(Map<String, dynamic> changes) =>
      SkinProduct.fromJson({...toJson(), ...changes});
}

class SkinStep {
  SkinStep({
    required this.productId,
    required this.name,
    required this.amount,
    required this.area,
    this.note = '',
    List<int>? days,
    this.productSnapshot = const {},
  }) : days = days ?? [1, 2, 3, 4, 5, 6, 7];
  final String productId, name, amount, area, note;
  final Map<String, dynamic> productSnapshot;
  final List<int> days;
  Map<String, dynamic> toJson() => {
    'productSnapshot': productSnapshot,
    'productId': productId,
    'name': name,
    'amount': amount,
    'area': area,
    'note': note,
    'days': days,
  };
  factory SkinStep.fromJson(Map<String, dynamic> m) => SkinStep(
    productSnapshot: m['productSnapshot'] == null
        ? const {}
        : object(m['productSnapshot']),
    productId: m['productId'] as String,
    name: m['name'] as String,
    amount: m['amount'] as String,
    area: m['area'] as String,
    note: m['note'] as String? ?? '',
    days: (m['days'] as List).cast<int>(),
  );
}

class SkinPlan {
  SkinPlan({
    required this.id,
    required this.name,
    required this.strategy,
    required this.start,
    required this.source,
    required this.morning,
    required this.evening,
  });
  final String id, name, strategy, start, source;
  final List<SkinStep> morning, evening;
  List<SkinStep> steps(DateTime date, String period) =>
      skinDate(date).compareTo(start) < 0
      ? []
      : (period == 'am' ? morning : evening)
            .where((s) => s.days.contains(date.weekday))
            .toList();
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'strategy': strategy,
    'start': start,
    'source': source,
    'morning': morning.map((s) => s.toJson()).toList(),
    'evening': evening.map((s) => s.toJson()).toList(),
  };
  factory SkinPlan.fromJson(Map<String, dynamic> m) => SkinPlan(
    id: m['id'] as String,
    name: m['name'] as String,
    strategy: m['strategy'] as String,
    start: m['start'] as String,
    source: m['source'] as String,
    morning: (m['morning'] as List)
        .map((s) => SkinStep.fromJson(object(s)))
        .toList(),
    evening: (m['evening'] as List)
        .map((s) => SkinStep.fromJson(object(s)))
        .toList(),
  );
}

class SkinExecution {
  SkinExecution({
    required this.date,
    required this.period,
    required this.planId,
    required this.steps,
    required this.states,
    this.updated = '',
  });
  final String date, period, planId, updated;
  final List<SkinStep> steps;
  final List<String> states;
  String get status => states.every((s) => s == 'done') && states.isNotEmpty
      ? '已完成'
      : states.every((s) => s == 'pending')
      ? '未开始'
      : states.contains('pending')
      ? '进行中'
      : '部分完成';
  bool get finished => states.isNotEmpty && !states.contains('pending');
  Map<String, dynamic> toJson() => {
    'date': date,
    'period': period,
    'planId': planId,
    'steps': steps.map((s) => s.toJson()).toList(),
    'states': states,
    'updated': updated,
  };
  factory SkinExecution.fromJson(Map<String, dynamic> m) => SkinExecution(
    date: m['date'] as String,
    period: m['period'] as String,
    planId: m['planId'] as String,
    steps: (m['steps'] as List)
        .map((s) => SkinStep.fromJson(object(s)))
        .toList(),
    states: strings(m['states']),
    updated: m['updated'] as String? ?? '',
  );
}

String encodeSkin(Object value) => jsonEncode(value);
