enum ClothingParameterType { number, text }

class ClothingParameterDefinition {
  const ClothingParameterDefinition({
    required this.key,
    required this.label,
    required this.group,
    this.type = ClothingParameterType.number,
    this.unit = 'cm',
  });

  final String key;
  final String label;
  final String group;
  final ClothingParameterType type;
  final String? unit;
}

class ClothingParameterValue {
  const ClothingParameterValue({
    required this.key,
    this.numberValue,
    this.textValue,
    this.unit,
    this.source = 'manual',
    this.confidence,
  });

  final String key;
  final double? numberValue;
  final String? textValue;
  final String? unit;
  final String source;
  final double? confidence;

  bool get isEmpty =>
      numberValue == null && (textValue?.trim().isEmpty ?? true);

  String get editableText {
    if (numberValue case final value?) {
      return value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toString();
    }
    return textValue ?? '';
  }

  String displayValue(ClothingParameterDefinition definition) {
    final value = editableText;
    final displayUnit = unit ?? definition.unit;
    return displayUnit == null || displayUnit.isEmpty
        ? value
        : '$value $displayUnit';
  }

  Map<String, Object?> toMap(int clothingItemId, String updatedAt) => {
    'clothing_item_id': clothingItemId,
    'parameter_key': key,
    'number_value': numberValue,
    'text_value': textValue,
    'unit': unit,
    'source': source,
    'confidence': confidence,
    'updated_at': updatedAt,
  };

  factory ClothingParameterValue.fromMap(Map<String, Object?> map) {
    return ClothingParameterValue(
      key: map['parameter_key'] as String,
      numberValue: (map['number_value'] as num?)?.toDouble(),
      textValue: map['text_value'] as String?,
      unit: map['unit'] as String?,
      source: map['source'] as String? ?? 'manual',
      confidence: (map['confidence'] as num?)?.toDouble(),
    );
  }
}

class ClothingParameterCatalog {
  const ClothingParameterCatalog._();

  static const definitions = <ClothingParameterDefinition>[
    ClothingParameterDefinition(
      key: 'sku',
      label: '货号',
      group: '商品信息',
      type: ClothingParameterType.text,
      unit: null,
    ),
    ClothingParameterDefinition(
      key: 'size_system',
      label: '尺码体系',
      group: '商品信息',
      type: ClothingParameterType.text,
      unit: null,
    ),
    ClothingParameterDefinition(
      key: 'pattern',
      label: '图案',
      group: '商品信息',
      type: ClothingParameterType.text,
      unit: null,
    ),
    ClothingParameterDefinition(
      key: 'material_composition',
      label: '材质成分及比例',
      group: '材质与版型',
      type: ClothingParameterType.text,
      unit: null,
    ),
    ClothingParameterDefinition(
      key: 'lining_material',
      label: '里料',
      group: '材质与版型',
      type: ClothingParameterType.text,
      unit: null,
    ),
    ClothingParameterDefinition(
      key: 'elasticity',
      label: '弹性',
      group: '材质与版型',
      type: ClothingParameterType.text,
      unit: null,
    ),
    ClothingParameterDefinition(
      key: 'thickness',
      label: '厚度',
      group: '材质与版型',
      type: ClothingParameterType.text,
      unit: null,
    ),
    ClothingParameterDefinition(
      key: 'fit',
      label: '版型',
      group: '材质与版型',
      type: ClothingParameterType.text,
      unit: null,
    ),
    ClothingParameterDefinition(
      key: 'care_instructions',
      label: '洗护说明',
      group: '材质与版型',
      type: ClothingParameterType.text,
      unit: null,
    ),
    ClothingParameterDefinition(
      key: 'garment_weight',
      label: '衣物重量',
      group: '商品信息',
      unit: 'g',
    ),
    ClothingParameterDefinition(
      key: 'clothing_length',
      label: '衣长／裙长',
      group: '尺寸',
    ),
    ClothingParameterDefinition(key: 'back_length', label: '后衣长', group: '尺寸'),
    ClothingParameterDefinition(
      key: 'shoulder_width',
      label: '肩宽',
      group: '尺寸',
    ),
    ClothingParameterDefinition(
      key: 'chest_circumference',
      label: '胸围',
      group: '尺寸',
    ),
    ClothingParameterDefinition(
      key: 'flat_chest_width',
      label: '平铺胸宽',
      group: '尺寸',
    ),
    ClothingParameterDefinition(
      key: 'upper_bust_circumference',
      label: '上胸围',
      group: '尺寸',
    ),
    ClothingParameterDefinition(
      key: 'under_bust_circumference',
      label: '下胸围',
      group: '尺寸',
    ),
    ClothingParameterDefinition(
      key: 'waist_circumference',
      label: '腰围',
      group: '尺寸',
    ),
    ClothingParameterDefinition(
      key: 'hip_circumference',
      label: '臀围',
      group: '尺寸',
    ),
    ClothingParameterDefinition(
      key: 'hem_circumference',
      label: '下摆围',
      group: '尺寸',
    ),
    ClothingParameterDefinition(key: 'sleeve_length', label: '袖长', group: '尺寸'),
    ClothingParameterDefinition(
      key: 'raglan_sleeve_length',
      label: '插肩袖长',
      group: '尺寸',
    ),
    ClothingParameterDefinition(
      key: 'upper_arm_circumference',
      label: '上臂围',
      group: '尺寸',
    ),
    ClothingParameterDefinition(
      key: 'cuff_circumference',
      label: '袖口围',
      group: '尺寸',
    ),
    ClothingParameterDefinition(key: 'back_width', label: '后背宽', group: '尺寸'),
    ClothingParameterDefinition(
      key: 'collar_circumference',
      label: '领围',
      group: '尺寸',
    ),
    ClothingParameterDefinition(key: 'collar_height', label: '领高', group: '尺寸'),
    ClothingParameterDefinition(key: 'neck_width', label: '领宽', group: '尺寸'),
    ClothingParameterDefinition(
      key: 'front_neck_drop',
      label: '前领深',
      group: '尺寸',
    ),
    ClothingParameterDefinition(
      key: 'back_neck_drop',
      label: '后领深',
      group: '尺寸',
    ),
    ClothingParameterDefinition(key: 'hood_height', label: '帽高', group: '尺寸'),
    ClothingParameterDefinition(key: 'hood_depth', label: '帽深', group: '尺寸'),
    ClothingParameterDefinition(key: 'slit_length', label: '开衩长', group: '尺寸'),
    ClothingParameterDefinition(
      key: 'filling_material',
      label: '填充物',
      group: '填充信息',
      type: ClothingParameterType.text,
      unit: null,
    ),
    ClothingParameterDefinition(
      key: 'fill_weight',
      label: '充绒／填充量',
      group: '填充信息',
      unit: 'g',
    ),
    ClothingParameterDefinition(
      key: 'fill_content_percentage',
      label: '绒子／填充物含量',
      group: '填充信息',
      unit: '%',
    ),
    ClothingParameterDefinition(
      key: 'fill_power',
      label: '蓬松度',
      group: '填充信息',
      type: ClothingParameterType.text,
      unit: null,
    ),
    ClothingParameterDefinition(
      key: 'trouser_length',
      label: '裤长（外长）',
      group: '裤装尺寸',
    ),
    ClothingParameterDefinition(
      key: 'inseam_length',
      label: '内长',
      group: '裤装尺寸',
    ),
    ClothingParameterDefinition(key: 'front_rise', label: '前裆长', group: '裤装尺寸'),
    ClothingParameterDefinition(key: 'back_rise', label: '后裆长', group: '裤装尺寸'),
    ClothingParameterDefinition(
      key: 'crotch_width',
      label: '横裆／裆宽',
      group: '裤装尺寸',
    ),
    ClothingParameterDefinition(
      key: 'thigh_circumference',
      label: '大腿围',
      group: '裤装尺寸',
    ),
    ClothingParameterDefinition(
      key: 'knee_circumference',
      label: '膝围',
      group: '裤装尺寸',
    ),
    ClothingParameterDefinition(
      key: 'calf_circumference',
      label: '小腿围',
      group: '裤装尺寸',
    ),
    ClothingParameterDefinition(
      key: 'leg_opening_circumference',
      label: '脚口围',
      group: '裤装尺寸',
    ),
    ClothingParameterDefinition(
      key: 'waistband_height',
      label: '腰头高',
      group: '裤装尺寸',
    ),
    ClothingParameterDefinition(
      key: 'elastic_waist_min',
      label: '松紧腰最小围',
      group: '裤装尺寸',
    ),
    ClothingParameterDefinition(
      key: 'elastic_waist_max',
      label: '松紧腰最大围',
      group: '裤装尺寸',
    ),
    ClothingParameterDefinition(
      key: 'suggested_height_min',
      label: '建议身高下限',
      group: '适穿范围',
    ),
    ClothingParameterDefinition(
      key: 'suggested_height_max',
      label: '建议身高上限',
      group: '适穿范围',
    ),
    ClothingParameterDefinition(
      key: 'suggested_weight_min',
      label: '建议体重下限',
      group: '适穿范围',
      unit: 'kg',
    ),
    ClothingParameterDefinition(
      key: 'suggested_weight_max',
      label: '建议体重上限',
      group: '适穿范围',
      unit: 'kg',
    ),
    ClothingParameterDefinition(
      key: 'cup_size',
      label: '罩杯',
      group: '内衣尺寸',
      type: ClothingParameterType.text,
      unit: null,
    ),
    ClothingParameterDefinition(
      key: 'strap_length',
      label: '肩带长',
      group: '内衣尺寸',
    ),
    ClothingParameterDefinition(
      key: 'side_wing_height',
      label: '侧翼高',
      group: '内衣尺寸',
    ),
    ClothingParameterDefinition(
      key: 'shoe_inner_length',
      label: '鞋内长',
      group: '鞋履尺寸',
    ),
    ClothingParameterDefinition(
      key: 'suitable_foot_length_min',
      label: '适合脚长下限',
      group: '鞋履尺寸',
    ),
    ClothingParameterDefinition(
      key: 'suitable_foot_length_max',
      label: '适合脚长上限',
      group: '鞋履尺寸',
    ),
    ClothingParameterDefinition(
      key: 'suitable_foot_width',
      label: '适合脚宽',
      group: '鞋履尺寸',
    ),
    ClothingParameterDefinition(key: 'last_width', label: '楦宽', group: '鞋履尺寸'),
    ClothingParameterDefinition(key: 'heel_height', label: '跟高', group: '鞋履尺寸'),
    ClothingParameterDefinition(
      key: 'platform_height',
      label: '防水台高',
      group: '鞋履尺寸',
    ),
    ClothingParameterDefinition(
      key: 'shaft_height',
      label: '靴筒高',
      group: '鞋履尺寸',
    ),
    ClothingParameterDefinition(
      key: 'shaft_circumference',
      label: '靴筒围',
      group: '鞋履尺寸',
    ),
    ClothingParameterDefinition(
      key: 'shoe_opening_circumference',
      label: '鞋口围',
      group: '鞋履尺寸',
    ),
    ClothingParameterDefinition(
      key: 'single_shoe_weight',
      label: '单鞋重量',
      group: '鞋履信息',
      unit: 'g',
    ),
    ClothingParameterDefinition(key: 'bag_length', label: '包长', group: '箱包尺寸'),
    ClothingParameterDefinition(key: 'bag_height', label: '包高', group: '箱包尺寸'),
    ClothingParameterDefinition(
      key: 'bag_depth',
      label: '包厚／底宽',
      group: '箱包尺寸',
    ),
    ClothingParameterDefinition(
      key: 'handle_drop',
      label: '手提高',
      group: '箱包尺寸',
    ),
    ClothingParameterDefinition(
      key: 'strap_length_min',
      label: '肩带最短',
      group: '箱包尺寸',
    ),
    ClothingParameterDefinition(
      key: 'strap_length_max',
      label: '肩带最长',
      group: '箱包尺寸',
    ),
    ClothingParameterDefinition(
      key: 'capacity_liters',
      label: '容量',
      group: '箱包信息',
      unit: 'L',
    ),
    ClothingParameterDefinition(
      key: 'bag_weight',
      label: '包重',
      group: '箱包信息',
      unit: 'g',
    ),
    ClothingParameterDefinition(
      key: 'compartment_count',
      label: '隔层数量',
      group: '箱包信息',
      unit: '个',
    ),
    ClothingParameterDefinition(
      key: 'device_fit',
      label: '可容纳设备',
      group: '箱包信息',
      type: ClothingParameterType.text,
      unit: null,
    ),
    ClothingParameterDefinition(
      key: 'total_length',
      label: '总长',
      group: '配饰尺寸',
    ),
    ClothingParameterDefinition(
      key: 'usable_length',
      label: '可用长度',
      group: '配饰尺寸',
    ),
    ClothingParameterDefinition(
      key: 'accessory_width',
      label: '宽度',
      group: '配饰尺寸',
    ),
    ClothingParameterDefinition(
      key: 'accessory_height',
      label: '高度',
      group: '配饰尺寸',
    ),
    ClothingParameterDefinition(
      key: 'accessory_weight',
      label: '重量',
      group: '配饰信息',
      unit: 'g',
    ),
    ClothingParameterDefinition(
      key: 'buckle_length',
      label: '扣头长',
      group: '配饰尺寸',
    ),
    ClothingParameterDefinition(
      key: 'buckle_width',
      label: '扣头宽',
      group: '配饰尺寸',
    ),
    ClothingParameterDefinition(
      key: 'hole_range_min',
      label: '最小扣眼位置',
      group: '配饰尺寸',
    ),
    ClothingParameterDefinition(
      key: 'hole_range_max',
      label: '最大扣眼位置',
      group: '配饰尺寸',
    ),
    ClothingParameterDefinition(
      key: 'head_circumference_min',
      label: '适合头围下限',
      group: '配饰尺寸',
    ),
    ClothingParameterDefinition(
      key: 'head_circumference_max',
      label: '适合头围上限',
      group: '配饰尺寸',
    ),
    ClothingParameterDefinition(key: 'brim_width', label: '帽檐宽', group: '配饰尺寸'),
    ClothingParameterDefinition(key: 'crown_depth', label: '帽深', group: '配饰尺寸'),
    ClothingParameterDefinition(
      key: 'chain_length',
      label: '链长',
      group: '配饰尺寸',
    ),
    ClothingParameterDefinition(
      key: 'extension_chain_length',
      label: '延长链长',
      group: '配饰尺寸',
    ),
    ClothingParameterDefinition(
      key: 'pendant_length',
      label: '吊坠长',
      group: '配饰尺寸',
    ),
    ClothingParameterDefinition(
      key: 'pendant_width',
      label: '吊坠宽',
      group: '配饰尺寸',
    ),
    ClothingParameterDefinition(
      key: 'ring_size',
      label: '戒圈号',
      group: '配饰尺寸',
      type: ClothingParameterType.text,
      unit: null,
    ),
    ClothingParameterDefinition(
      key: 'inner_diameter',
      label: '内径',
      group: '配饰尺寸',
      unit: 'mm',
    ),
    ClothingParameterDefinition(
      key: 'inner_circumference',
      label: '内周长',
      group: '配饰尺寸',
      unit: 'mm',
    ),
    ClothingParameterDefinition(
      key: 'adjustable_length_min',
      label: '可调长度下限',
      group: '配饰尺寸',
    ),
    ClothingParameterDefinition(
      key: 'adjustable_length_max',
      label: '可调长度上限',
      group: '配饰尺寸',
    ),
    ClothingParameterDefinition(
      key: 'case_diameter',
      label: '表壳直径',
      group: '配饰尺寸',
      unit: 'mm',
    ),
    ClothingParameterDefinition(
      key: 'case_thickness',
      label: '表壳厚度',
      group: '配饰尺寸',
      unit: 'mm',
    ),
    ClothingParameterDefinition(
      key: 'wrist_range_min',
      label: '适合腕围下限',
      group: '配饰尺寸',
    ),
    ClothingParameterDefinition(
      key: 'wrist_range_max',
      label: '适合腕围上限',
      group: '配饰尺寸',
    ),
    ClothingParameterDefinition(
      key: 'frame_width',
      label: '镜框总宽',
      group: '配饰尺寸',
      unit: 'mm',
    ),
    ClothingParameterDefinition(
      key: 'lens_width',
      label: '镜片宽',
      group: '配饰尺寸',
      unit: 'mm',
    ),
    ClothingParameterDefinition(
      key: 'lens_height',
      label: '镜片高',
      group: '配饰尺寸',
      unit: 'mm',
    ),
    ClothingParameterDefinition(
      key: 'bridge_width',
      label: '鼻梁宽',
      group: '配饰尺寸',
      unit: 'mm',
    ),
    ClothingParameterDefinition(
      key: 'temple_length',
      label: '镜腿长',
      group: '配饰尺寸',
      unit: 'mm',
    ),
    ClothingParameterDefinition(
      key: 'sock_tube_height',
      label: '袜筒高',
      group: '配饰尺寸',
    ),
    ClothingParameterDefinition(
      key: 'sock_opening_circumference',
      label: '袜口围',
      group: '配饰尺寸',
    ),
  ];

  static final Map<String, ClothingParameterDefinition> byKey = {
    for (final definition in definitions) definition.key: definition,
  };

  static const _common = [
    'sku',
    'size_system',
    'pattern',
    'material_composition',
    'lining_material',
    'elasticity',
    'thickness',
    'fit',
    'care_instructions',
    'garment_weight',
  ];
  static const _top = [
    'clothing_length',
    'back_length',
    'shoulder_width',
    'chest_circumference',
    'flat_chest_width',
    'waist_circumference',
    'hem_circumference',
    'sleeve_length',
    'raglan_sleeve_length',
    'upper_arm_circumference',
    'cuff_circumference',
    'back_width',
    'collar_circumference',
    'collar_height',
    'neck_width',
    'front_neck_drop',
    'back_neck_drop',
  ];
  static const _pants = [
    'waist_circumference',
    'hip_circumference',
    'front_rise',
    'back_rise',
    'crotch_width',
    'trouser_length',
    'inseam_length',
    'thigh_circumference',
    'knee_circumference',
    'calf_circumference',
    'leg_opening_circumference',
    'waistband_height',
    'elastic_waist_min',
    'elastic_waist_max',
    'suggested_height_min',
    'suggested_height_max',
    'suggested_weight_min',
    'suggested_weight_max',
  ];
  static const _skirt = [
    'waist_circumference',
    'hip_circumference',
    'clothing_length',
    'hem_circumference',
    'waistband_height',
    'slit_length',
    'elastic_waist_min',
    'elastic_waist_max',
  ];
  static const _accessoryCommon = [
    'sku',
    'material_composition',
    'pattern',
    'care_instructions',
  ];

  static List<ClothingParameterDefinition> forCategory(String? category) {
    final normalized = category?.trim().toLowerCase() ?? '';
    final keys = <String>{};
    void addAll(Iterable<String> values) => keys.addAll(values);

    if (_matches(normalized, ['外套', '大衣', '夹克', '风衣', '羽绒', '冲锋衣', '西装'])) {
      addAll(_common);
      addAll(_top);
      addAll([
        'hood_height',
        'hood_depth',
        'slit_length',
        'filling_material',
        'fill_weight',
        'fill_content_percentage',
        'fill_power',
      ]);
    } else if (_matches(normalized, ['连体裤', '背带裤'])) {
      addAll(_common);
      addAll(_top);
      addAll(_pants);
    } else if (_matches(normalized, ['长裤', '短裤', '裤', '牛仔裤', '瑜伽裤'])) {
      addAll(_common);
      addAll(_pants);
    } else if (_matches(normalized, ['连衣裙', '连身裙'])) {
      addAll(_common);
      addAll(_top);
      addAll(['hip_circumference', 'slit_length']);
    } else if (_matches(normalized, ['裙装', '半身裙', '裙'])) {
      addAll(_common);
      addAll(_skirt);
    } else if (_matches(normalized, ['内衣', '文胸', '胸罩'])) {
      addAll(_common);
      addAll([
        'upper_bust_circumference',
        'under_bust_circumference',
        'cup_size',
        'strap_length',
        'side_wing_height',
        'waist_circumference',
        'hip_circumference',
        'front_rise',
        'back_rise',
      ]);
    } else if (_matches(normalized, ['家居服', '睡衣'])) {
      addAll(_common);
      addAll(_top);
      addAll(_pants);
    } else if (_matches(normalized, ['鞋', '靴', '凉鞋', '拖鞋'])) {
      addAll(_accessoryCommon);
      addAll([
        'shoe_inner_length',
        'suitable_foot_length_min',
        'suitable_foot_length_max',
        'suitable_foot_width',
        'last_width',
        'heel_height',
        'platform_height',
        'shaft_height',
        'shaft_circumference',
        'shoe_opening_circumference',
        'single_shoe_weight',
      ]);
    } else if (_matches(normalized, ['包', '背包', '箱'])) {
      addAll(_accessoryCommon);
      addAll([
        'bag_length',
        'bag_height',
        'bag_depth',
        'handle_drop',
        'strap_length_min',
        'strap_length_max',
        'capacity_liters',
        'bag_weight',
        'compartment_count',
        'device_fit',
      ]);
    } else if (_matches(normalized, ['腰带', '皮带'])) {
      addAll(_accessoryCommon);
      addAll([
        'total_length',
        'usable_length',
        'accessory_width',
        'buckle_length',
        'buckle_width',
        'hole_range_min',
        'hole_range_max',
      ]);
    } else if (_matches(normalized, ['帽'])) {
      addAll(_accessoryCommon);
      addAll([
        'head_circumference_min',
        'head_circumference_max',
        'brim_width',
        'crown_depth',
        'accessory_height',
      ]);
    } else if (_matches(normalized, ['围巾', '丝巾'])) {
      addAll(_accessoryCommon);
      addAll(['total_length', 'accessory_width', 'accessory_weight']);
    } else if (_matches(normalized, ['项链'])) {
      addAll(_accessoryCommon);
      addAll([
        'chain_length',
        'extension_chain_length',
        'pendant_length',
        'pendant_width',
        'accessory_weight',
      ]);
    } else if (_matches(normalized, ['戒指', '指环'])) {
      addAll(_accessoryCommon);
      addAll([
        'ring_size',
        'inner_diameter',
        'inner_circumference',
        'accessory_width',
        'accessory_weight',
      ]);
    } else if (_matches(normalized, ['手链', '手镯'])) {
      addAll(_accessoryCommon);
      addAll([
        'inner_circumference',
        'adjustable_length_min',
        'adjustable_length_max',
        'accessory_width',
        'accessory_weight',
      ]);
    } else if (_matches(normalized, ['手表', '腕表'])) {
      addAll(_accessoryCommon);
      addAll([
        'case_diameter',
        'case_thickness',
        'accessory_width',
        'total_length',
        'wrist_range_min',
        'wrist_range_max',
        'accessory_weight',
      ]);
    } else if (_matches(normalized, ['眼镜', '镜框'])) {
      addAll(_accessoryCommon);
      addAll([
        'frame_width',
        'lens_width',
        'lens_height',
        'bridge_width',
        'temple_length',
        'accessory_weight',
      ]);
    } else if (_matches(normalized, ['袜'])) {
      addAll(_accessoryCommon);
      addAll([
        'suitable_foot_length_min',
        'suitable_foot_length_max',
        'sock_tube_height',
        'sock_opening_circumference',
      ]);
    } else if (_matches(normalized, ['饰品', '配饰'])) {
      addAll(_accessoryCommon);
      addAll([
        'total_length',
        'accessory_width',
        'accessory_height',
        'accessory_weight',
      ]);
    } else {
      addAll(_common);
      addAll(_top);
    }
    return [
      for (final definition in definitions)
        if (keys.contains(definition.key)) definition,
    ];
  }

  static bool _matches(String value, Iterable<String> keywords) =>
      keywords.any(value.contains);
}
