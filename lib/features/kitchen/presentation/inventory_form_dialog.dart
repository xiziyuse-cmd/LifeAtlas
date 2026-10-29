import 'package:flutter/material.dart';
import '../domain/kitchen_models.dart';

class InventoryFormDialog extends StatefulWidget {
  const InventoryFormDialog({
    super.key,
    this.item,
    required this.foods,
    this.onSave,
  });
  final InventoryItem? item;
  final List<FoodBaseInfo> foods;
  final Future<void> Function(InventoryItem)? onSave;
  @override
  State<InventoryFormDialog> createState() => _InventoryFormDialogState();
}

class _InventoryFormDialogState extends State<InventoryFormDialog> {
  late final TextEditingController name, amount, unit, shelfLife, remark;
  final _nameFocus = FocusNode();
  late DateTime purchaseDate;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final item = widget.item;
    name = TextEditingController(text: item?.name ?? '');
    amount = TextEditingController(text: item == null ? '' : '${item.amount}');
    unit = TextEditingController(text: item?.unit ?? '个');
    shelfLife = TextEditingController(
      text: item?.shelfLifeDays?.toString() ?? '',
    );
    remark = TextEditingController(text: item?.remark ?? '');
    purchaseDate = item?.purchaseDate ?? DateTime.now();
    shelfLife.addListener(_refresh);
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) _applyDefault();
    });
  }

  void _refresh() => setState(() {});
  DateTime? get expiry {
    final days = int.tryParse(shelfLife.text);
    return days == null || days <= 0
        ? widget.item?.expireDate
        : DateTime(
            purchaseDate.year,
            purchaseDate.month,
            purchaseDate.day,
          ).add(Duration(days: days));
  }

  void _applyDefault() {
    if (widget.item == null && shelfLife.text.trim().isEmpty) {
      final normalized = name.text.trim();
      final matches = widget.foods.where(
        (food) => food.name.trim() == normalized,
      );
      if (matches.isNotEmpty) {
        shelfLife.text = '${matches.first.defaultShelfLife}';
      }
    }
    setState(() {});
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: purchaseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => purchaseDate = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    _applyDefault();
    final parsedAmount = double.tryParse(amount.text);
    final days = shelfLife.text.trim().isEmpty
        ? null
        : int.tryParse(shelfLife.text);
    if (name.text.trim().isEmpty ||
        unit.text.trim().isEmpty ||
        parsedAmount == null ||
        !parsedAmount.isFinite ||
        parsedAmount < 0 ||
        (shelfLife.text.trim().isNotEmpty && (days == null || days <= 0))) {
      setState(() => _error = '请填写名称、非负数量、单位及有效保质期');
      return;
    }
    final value = InventoryItem(
      id: widget.item?.id,
      name: name.text,
      amount: parsedAmount,
      unit: unit.text,
      remark: remark.text,
      purchaseDate: purchaseDate,
      shelfLifeDays: days,
      expireDate: expiry,
      updatedAt: DateTime.now(),
    );
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave?.call(value);
      if (mounted) Navigator.pop(context, value);
    } catch (_) {
      if (mounted) setState(() => _error = '库存保存失败，请重试，填写内容已保留');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    shelfLife.removeListener(_refresh);
    _nameFocus.dispose();
    for (final c in [name, amount, unit, shelfLife, remark]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _section(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: Text(widget.item == null ? '新增库存' : '编辑库存')),
      body: Column(
        children: [
          Expanded(
            child: AbsorbPointer(
              absorbing: _saving,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(16),
                children: [
                  _section('基本信息', [
                    TextField(
                      controller: name,
                      focusNode: _nameFocus,
                      textInputAction: TextInputAction.next,
                      onEditingComplete: () {
                        _applyDefault();
                        FocusScope.of(context).nextFocus();
                      },
                      decoration: const InputDecoration(
                        labelText: '食物名称',
                        hintText: '例如：鸡蛋、牛奶',
                        prefixIcon: Icon(Icons.restaurant_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: amount,
                            textInputAction: TextInputAction.next,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: '数量',
                              hintText: '支持小数',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: unit,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(labelText: '单位'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final value in [
                          '个',
                          'g',
                          'kg',
                          'ml',
                          '袋',
                          '盒',
                          '瓶',
                        ])
                          ChoiceChip(
                            label: Text(value),
                            selected: unit.text == value,
                            onSelected: (_) =>
                                setState(() => unit.text = value),
                          ),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _section('保质期', [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.shopping_bag_outlined),
                      title: const Text('购入时间'),
                      subtitle: Text(kitchenDate(purchaseDate)),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: shelfLife,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '保质期（天）',
                        helperText: '可留空；填写后自动计算过期日期',
                        prefixIcon: Icon(Icons.hourglass_bottom),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '预计过期时间',
                        prefixIcon: Icon(Icons.event_busy_outlined),
                      ),
                      child: Text(
                        expiry == null ? '填写保质期后自动计算' : kitchenDate(expiry!),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _section('备注（选填）', [
                    TextField(
                      controller: remark,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: '备注',
                        hintText: '例如：放在冰箱冷藏层',
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '保存中…' : '保存库存'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
