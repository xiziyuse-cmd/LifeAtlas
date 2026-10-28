import 'package:flutter/material.dart';

import '../data/wardrobe_image_service.dart';
import '../data/wardrobe_repository.dart';
import '../domain/models/preorder_item.dart';
import 'preorder_keys.dart';
import 'widgets/local_clothing_image.dart';

class PreorderFormPage extends StatefulWidget {
  const PreorderFormPage({
    super.key,
    required this.repository,
    this.imageService,
    this.initialItem,
  });

  final WardrobeRepository repository;
  final WardrobeImageService? imageService;
  final PreorderItem? initialItem;

  @override
  State<PreorderFormPage> createState() => _PreorderFormPageState();
}

class _PreorderFormPageState extends State<PreorderFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final WardrobeImageService _imageService;
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _categoryController;
  late final TextEditingController _priceController;
  late final TextEditingController _materialController;
  late final TextEditingController _sizeController;
  late final TextEditingController _clothingLengthController;
  late final TextEditingController _shoulderWidthController;
  late final TextEditingController _chestController;
  late final TextEditingController _sleeveLengthController;
  late final TextEditingController _waistController;
  late final TextEditingController _hipController;
  late final TextEditingController _trouserLengthController;
  late final TextEditingController _productUrlController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _notesController;

  String? _imagePath;
  bool _pickingImage = false;
  bool _submitting = false;
  bool _showValidation = false;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _imageService = widget.imageService ?? DeviceWardrobeImageService();
    _imagePath = item?.imagePath;
    _nameController = TextEditingController(text: item?.name);
    _brandController = TextEditingController(text: item?.brand);
    _categoryController = TextEditingController(text: item?.category);
    _priceController = TextEditingController(text: _numberText(item?.price));
    _materialController = TextEditingController(text: item?.material);
    _sizeController = TextEditingController(text: item?.size);
    _clothingLengthController = TextEditingController(
      text: _numberText(item?.clothingLength),
    );
    _shoulderWidthController = TextEditingController(
      text: _numberText(item?.shoulderWidth),
    );
    _chestController = TextEditingController(
      text: _numberText(item?.chestCircumference),
    );
    _sleeveLengthController = TextEditingController(
      text: _numberText(item?.sleeveLength),
    );
    _waistController = TextEditingController(
      text: _numberText(item?.waistCircumference),
    );
    _hipController = TextEditingController(
      text: _numberText(item?.hipCircumference),
    );
    _trouserLengthController = TextEditingController(
      text: _numberText(item?.trouserLength),
    );
    _productUrlController = TextEditingController(text: item?.productUrl);
    _descriptionController = TextEditingController(text: item?.description);
    _notesController = TextEditingController(text: item?.notes);
    _recoverLostImage();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _materialController.dispose();
    _sizeController.dispose();
    _clothingLengthController.dispose();
    _shoulderWidthController.dispose();
    _chestController.dispose();
    _sleeveLengthController.dispose();
    _waistController.dispose();
    _hipController.dispose();
    _trouserLengthController.dispose();
    _productUrlController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialItem != null;

    return Scaffold(
      key: PreorderKeys.form,
      appBar: AppBar(title: Text(editing ? '编辑心仪衣服' : '添加心仪衣服')),
      body: Form(
        key: _formKey,
        autovalidateMode: _showValidation
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _ImagePickerCard(
              imagePath: _imagePath,
              busy: _pickingImage,
              onPressed: _pickingImage || _submitting ? null : _pickImage,
              showError:
                  _showValidation && (_imagePath?.trim().isEmpty ?? true),
            ),
            const SizedBox(height: 16),
            _FormSection(
              title: '基本信息',
              children: [
                TextFormField(
                  key: PreorderKeys.nameField,
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '名称（可选）',
                    hintText: '例如：米色短款风衣',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _brandController,
                        decoration: const InputDecoration(
                          labelText: '品牌',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _categoryController,
                        decoration: const InputDecoration(
                          labelText: '品类',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(
                          labelText: '价格',
                          prefixText: '¥ ',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: _optionalPositiveNumber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _sizeController,
                        decoration: const InputDecoration(
                          labelText: '尺码',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _materialController,
                  decoration: const InputDecoration(
                    labelText: '材质',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _productUrlController,
                  decoration: const InputDecoration(
                    labelText: '商品链接',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _FormSection(
              title: '衣服数据',
              subtitle: '单位均为厘米，可按商品页面已有数据填写。',
              children: [
                _MeasurementRow(
                  left: _MeasurementField(
                    controller: _clothingLengthController,
                    label: '衣长',
                  ),
                  right: _MeasurementField(
                    controller: _shoulderWidthController,
                    label: '肩宽',
                  ),
                ),
                const SizedBox(height: 12),
                _MeasurementRow(
                  left: _MeasurementField(
                    controller: _chestController,
                    label: '胸围',
                  ),
                  right: _MeasurementField(
                    controller: _sleeveLengthController,
                    label: '袖长',
                  ),
                ),
                const SizedBox(height: 12),
                _MeasurementRow(
                  left: _MeasurementField(
                    controller: _waistController,
                    label: '腰围',
                  ),
                  right: _MeasurementField(
                    controller: _hipController,
                    label: '臀围',
                  ),
                ),
                const SizedBox(height: 12),
                _MeasurementRow(
                  left: _MeasurementField(
                    controller: _trouserLengthController,
                    label: '裤长',
                  ),
                  right: const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _FormSection(
              title: '补充信息',
              children: [
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: '商品描述',
                    hintText: '版型、颜色、商品卖点等',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: '我的备注',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: PreorderKeys.submit,
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_submitting ? '保存中…' : '保存'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    setState(() => _pickingImage = true);
    try {
      final imagePath = await _imageService.pickSingleFromGallery();
      if (!mounted || imagePath == null) {
        return;
      }
      setState(() => _imagePath = imagePath);
    } catch (error) {
      if (mounted) {
        _showMessage('图片选择失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _pickingImage = false);
      }
    }
  }

  Future<void> _recoverLostImage() async {
    try {
      final recoveredPaths = await _imageService.retrieveLostData();
      if (!mounted || recoveredPaths.isEmpty) {
        return;
      }
      setState(() => _imagePath = recoveredPaths.last);
    } on Object {
      // Recovery is best-effort; users can still select the image again.
    }
  }

  Future<void> _submit() async {
    setState(() => _showValidation = true);
    final imagePath = _imagePath?.trim();
    final formValid = _formKey.currentState?.validate() ?? false;
    if (imagePath == null || imagePath.isEmpty || !formValid) {
      if (imagePath == null || imagePath.isEmpty) {
        _showMessage('请先选择一张衣服图片');
      }
      return;
    }

    setState(() => _submitting = true);
    try {
      final original = widget.initialItem;
      final now = DateTime.now();
      final brand = _optionalText(_brandController);
      final category = _optionalText(_categoryController);
      final item = PreorderItem(
        id: original?.id,
        name: _optionalText(_nameController),
        imagePath: imagePath,
        brand: brand,
        category: category,
        brandId: _sameCatalogName(original?.brand, brand)
            ? original?.brandId
            : null,
        categoryId: _sameCatalogName(original?.category, category)
            ? original?.categoryId
            : null,
        price: _optionalDouble(_priceController),
        material: _optionalText(_materialController),
        size: _optionalText(_sizeController),
        clothingLength: _optionalDouble(_clothingLengthController),
        shoulderWidth: _optionalDouble(_shoulderWidthController),
        chestCircumference: _optionalDouble(_chestController),
        sleeveLength: _optionalDouble(_sleeveLengthController),
        waistCircumference: _optionalDouble(_waistController),
        hipCircumference: _optionalDouble(_hipController),
        trouserLength: _optionalDouble(_trouserLengthController),
        productUrl: _optionalText(_productUrlController),
        description: _optionalText(_descriptionController),
        notes: _optionalText(_notesController),
        isPurchased: original?.isPurchased ?? false,
        purchasedAt: original?.purchasedAt,
        clothingItemId: original?.clothingItemId,
        isDeleted: original?.isDeleted ?? false,
        createdAt: original?.createdAt ?? now,
        updatedAt: now,
      );

      late final PreorderItem savedItem;
      if (original?.id == null) {
        final id = await widget.repository.createPreorder(item);
        savedItem = item.copyWith(id: id);
      } else {
        await widget.repository.updatePreorder(item);
        savedItem = item;
      }

      if (mounted) {
        Navigator.of(context).pop(savedItem);
      }
    } catch (error) {
      if (mounted) {
        _showMessage('保存失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static String? _optionalText(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  static double? _optionalDouble(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : double.parse(value);
  }

  static bool _sameCatalogName(String? left, String? right) {
    String normalize(String? value) =>
        value?.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase() ?? '';
    return normalize(left) == normalize(right);
  }

  static String? _optionalPositiveNumber(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    final parsed = double.tryParse(normalized);
    if (parsed == null || !parsed.isFinite) {
      return '请输入数字';
    }
    if (parsed < 0) {
      return '不能小于 0';
    }
    return null;
  }

  static String _numberText(double? value) {
    if (value == null) {
      return '';
    }
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }
}

class _ImagePickerCard extends StatelessWidget {
  const _ImagePickerCard({
    required this.imagePath,
    required this.busy,
    required this.onPressed,
    required this.showError,
  });

  final String? imagePath;
  final bool busy;
  final VoidCallback? onPressed;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: PreorderKeys.imagePicker,
            onTap: onPressed,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LocalClothingImage(
                    imagePath: imagePath,
                    semanticLabel: '心仪衣服图片',
                    placeholder: ColoredBox(
                      color: colorScheme.surfaceContainerHighest,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 48,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(height: 10),
                          const Text('选择一张衣服图片'),
                        ],
                      ),
                    ),
                  ),
                  if (busy)
                    ColoredBox(
                      color: colorScheme.scrim.withValues(alpha: 0.28),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  if (!busy && imagePath != null)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: FilledButton.tonalIcon(
                        onPressed: onPressed,
                        icon: const Icon(Icons.refresh),
                        label: const Text('更换图片'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (showError) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              '请选择一张衣服图片',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ),
        ],
      ],
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _MeasurementRow extends StatelessWidget {
  const _MeasurementRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}

class _MeasurementField extends StatelessWidget {
  const _MeasurementField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'cm',
        border: const OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      validator: _PreorderFormPageState._optionalPositiveNumber,
    );
  }
}
