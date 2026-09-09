import 'package:flutter/material.dart';
import '../domain/kitchen_models.dart';

class InventoryFormDialog extends StatefulWidget {
  const InventoryFormDialog({super.key, this.item, required this.foods});
  final InventoryItem? item;
  final List<FoodBaseInfo> foods;
  @override
  State<InventoryFormDialog> createState() => _InventoryFormDialogState();
}

class _InventoryFormDialogState extends State<InventoryFormDialog> {
  late final TextEditingController name, amount, unit, shelfLife, remark;
  final _nameFocus = FocusNode();
  late DateTime purchaseDate;
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
    if (picked != null) setState(() => purchaseDate = picked);
  }

  void _save() {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写名称、非负数量、单位及有效保质期')));
      return;
    }
    Navigator.pop(
      context,
      InventoryItem(
        id: widget.item?.id,
        name: name.text,
        amount: parsedAmount,
        unit: unit.text,
        remark: remark.text,
        purchaseDate: purchaseDate,
        shelfLifeDays: days,
        expireDate: expiry,
        updatedAt: DateTime.now(),
      ),
    );
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

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.item == null ? '新增库存' : '编辑库存'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              focusNode: _nameFocus,
              textInputAction: TextInputAction.done,
              onEditingComplete: () {
                _applyDefault();
                _nameFocus.unfocus();
              },
              decoration: const InputDecoration(
                labelText: '食物名称',
                prefixIcon: Icon(Icons.restaurant_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '数量'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: unit,
                    decoration: const InputDecoration(labelText: '单位'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.shopping_bag_outlined),
              title: const Text('购入时间'),
              subtitle: Text(kitchenDate(purchaseDate)),
              trailing: const Icon(Icons.calendar_month),
              onTap: _pickDate,
            ),
            TextField(
              controller: shelfLife,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '保质期（天）',
                prefixIcon: Icon(Icons.hourglass_bottom),
              ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: '预计过期时间',
                prefixIcon: Icon(Icons.event_busy_outlined),
              ),
              child: Text(expiry == null ? '填写保质期后自动计算' : kitchenDate(expiry!)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: remark,
              maxLines: 2,
              decoration: const InputDecoration(labelText: '备注'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _save, child: const Text('保存')),
    ],
  );
}
