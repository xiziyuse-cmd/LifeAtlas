import 'package:flutter/material.dart';

import '../../data/clothing_image_parameter_service.dart';
import '../../data/wardrobe_image_service.dart';
import '../../domain/models/clothing_image_parameters.dart';
import '../../domain/models/clothing_item.dart';
import '../../domain/models/clothing_parameter_profile.dart';
import '../wardrobe_keys.dart';
import '../widgets/local_clothing_image.dart';

class ClothingFormPage extends StatefulWidget {
  const ClothingFormPage({
    super.key,
    required this.imageService,
    this.imageParameterService =
        const UnconfiguredClothingImageParameterService(),
    this.initialItem,
    this.categories = const [],
    this.brands = const [],
    this.now,
  });

  final WardrobeImageService imageService;
  final ClothingImageParameterService imageParameterService;
  final ClothingItem? initialItem;
  final List<String> categories;
  final List<String> brands;
  final DateTime Function()? now;

  @override
  State<ClothingFormPage> createState() => _ClothingFormPageState();
}

class _ClothingFormPageState extends State<ClothingFormPage> {
  static const _seasons = ['春', '夏', '秋', '冬'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _categoryController;
  late final TextEditingController _colorController;
  late final TextEditingController _materialController;
  late final TextEditingController _sizeController;
  late final TextEditingController _clothingLengthController;
  late final TextEditingController _shoulderWidthController;
  late final TextEditingController _chestController;
  late final TextEditingController _sleeveLengthController;
  late final TextEditingController _waistController;
  late final TextEditingController _hipController;
  late final TextEditingController _trouserLengthController;
  late final TextEditingController _priceController;
  late final TextEditingController _notesController;

  late final Set<String> _selectedSeasons;
  String? _imagePath;
  DateTime? _purchaseDate;
  bool _isPickingImage = false;
  bool _isAnalyzingImage = false;
  String? _imageAnalysisStatus;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _nameController = TextEditingController(text: item?.name);
    _brandController = TextEditingController(text: item?.brand);
    _categoryController = TextEditingController(text: item?.category);
    _colorController = TextEditingController(text: item?.color);
    _materialController = TextEditingController(text: item?.material);
    _sizeController = TextEditingController(text: item?.size);
    _clothingLengthController = _numberController(item?.clothingLength);
    _shoulderWidthController = _numberController(item?.shoulderWidth);
    _chestController = _numberController(item?.chestCircumference);
    _sleeveLengthController = _numberController(item?.sleeveLength);
    _waistController = _numberController(item?.waistCircumference);
    _hipController = _numberController(item?.hipCircumference);
    _trouserLengthController = _numberController(item?.trouserLength);
    _priceController = _numberController(item?.purchasePrice);
    _notesController = TextEditingController(text: item?.notes);
    _selectedSeasons = {...?item?.seasonTags};
    _imagePath = item?.imagePath;
    _purchaseDate = item?.purchaseDate;
    _categoryController.addListener(_onCategoryChanged);
    _recoverLostImage();
  }

  @override
  void dispose() {
    _categoryController.removeListener(_onCategoryChanged);
    for (final controller in [
      _nameController,
      _brandController,
      _categoryController,
      _colorController,
      _materialController,
      _sizeController,
      _clothingLengthController,
      _shoulderWidthController,
      _chestController,
      _sleeveLengthController,
      _waistController,
      _hipController,
      _trouserLengthController,
      _priceController,
      _notesController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _recoverLostImage() async {
    try {
      final recovered = await widget.imageService.retrieveLostData();
      if (!mounted || recovered.isEmpty) {
        return;
      }
      final imagePath = recovered.last;
      setState(() => _imagePath = imagePath);
      await _analyzeImage(imagePath);
    } on Object {
      // A failed recovery must not prevent manual editing or another pick.
    }
  }

  Future<void> _pickImage() async {
    setState(() => _isPickingImage = true);
    String? selectedImagePath;
    try {
      selectedImagePath = await widget.imageService.pickSingleFromGallery();
      if (mounted && selectedImagePath != null) {
        setState(() {
          _imagePath = selectedImagePath;
          _imageAnalysisStatus = null;
        });
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法读取图片，请稍后重试')));
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
    if (selectedImagePath != null && mounted) {
      await _analyzeImage(selectedImagePath);
    }
  }

  void _onCategoryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _analyzeImage(String imagePath) async {
    if (!widget.imageParameterService.isConfigured) {
      if (mounted) {
        setState(() {
          _imageAnalysisStatus = '图片参数识别服务尚未配置，可先手动填写';
        });
      }
      return;
    }

    setState(() {
      _isAnalyzingImage = true;
      _imageAnalysisStatus = '正在读取图片参数…';
    });
    try {
      final parameters = await widget.imageParameterService.analyze(imagePath);
      if (!mounted || _imagePath != imagePath) {
        return;
      }
      _applyImageParameters(parameters);
      setState(() => _imageAnalysisStatus = '已读取图片参数，请核对后保存');
    } on Object {
      if (mounted) {
        setState(() => _imageAnalysisStatus = '图片参数读取失败，可再次尝试或手动填写');
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzingImage = false);
      }
    }
  }

  void _applyImageParameters(ClothingImageParameters parameters) {
    _fillTextIfEmpty(_nameController, parameters.name);
    _fillTextIfEmpty(_categoryController, parameters.category);
    _fillTextIfEmpty(_brandController, parameters.brand);
    _fillTextIfEmpty(_colorController, parameters.color);
    _fillTextIfEmpty(_materialController, parameters.material);
    _fillTextIfEmpty(_sizeController, parameters.size);
    _fillNumberIfEmpty(_clothingLengthController, parameters.clothingLength);
    _fillNumberIfEmpty(_shoulderWidthController, parameters.shoulderWidth);
    _fillNumberIfEmpty(_chestController, parameters.chestCircumference);
    _fillNumberIfEmpty(_sleeveLengthController, parameters.sleeveLength);
    _fillNumberIfEmpty(_waistController, parameters.waistCircumference);
    _fillNumberIfEmpty(_hipController, parameters.hipCircumference);
    _fillNumberIfEmpty(_trouserLengthController, parameters.trouserLength);
    if (_selectedSeasons.isEmpty && parameters.seasonTags.isNotEmpty) {
      _selectedSeasons.addAll(parameters.seasonTags);
    }
  }

  static void _fillTextIfEmpty(
    TextEditingController controller,
    String? value,
  ) {
    final normalized = value?.trim() ?? '';
    if (controller.text.trim().isEmpty && normalized.isNotEmpty) {
      controller.text = normalized;
    }
  }

  static void _fillNumberIfEmpty(
    TextEditingController controller,
    double? value,
  ) {
    if (controller.text.trim().isEmpty && value != null) {
      controller.text = value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toString();
    }
  }

  Future<void> _selectPurchaseDate() async {
    final now = (widget.now ?? DateTime.now)();
    final selected = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? now,
      firstDate: DateTime(1970),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (selected != null && mounted) {
      setState(() => _purchaseDate = selected);
    }
  }

  void _toggleSeason(String season, bool selected) {
    if (selected && _selectedSeasons.length >= 3) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('一件衣服最多选择三个季节')));
      return;
    }
    setState(() {
      if (selected) {
        _selectedSeasons.add(season);
      } else {
        _selectedSeasons.remove(season);
      }
    });
  }

  void _submit() {
    final imagePath = _imagePath?.trim() ?? '';
    final formIsValid = _formKey.currentState?.validate() ?? false;
    if (imagePath.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择一张衣服图片')));
    }
    if (!formIsValid || imagePath.isEmpty) {
      return;
    }

    final initialItem = widget.initialItem;
    final now = (widget.now ?? DateTime.now)();
    final parameterProfile = ClothingParameterProfile.forCategory(
      _categoryController.text,
    );
    final item = ClothingItem(
      id: initialItem?.id,
      name: _nameController.text.trim(),
      imagePath: imagePath,
      brand: _optionalText(_brandController),
      category: _optionalText(_categoryController),
      seasonTags: [
        for (final season in _seasons)
          if (_selectedSeasons.contains(season)) season,
      ],
      color: _optionalText(_colorController),
      material: _optionalText(_materialController),
      size: _optionalText(_sizeController),
      clothingLength:
          parameterProfile.includes(ClothingMeasurementField.clothingLength)
          ? _number(_clothingLengthController)
          : null,
      shoulderWidth:
          parameterProfile.includes(ClothingMeasurementField.shoulderWidth)
          ? _number(_shoulderWidthController)
          : null,
      chestCircumference:
          parameterProfile.includes(ClothingMeasurementField.chestCircumference)
          ? _number(_chestController)
          : null,
      sleeveLength:
          parameterProfile.includes(ClothingMeasurementField.sleeveLength)
          ? _number(_sleeveLengthController)
          : null,
      waistCircumference:
          parameterProfile.includes(ClothingMeasurementField.waistCircumference)
          ? _number(_waistController)
          : null,
      hipCircumference:
          parameterProfile.includes(ClothingMeasurementField.hipCircumference)
          ? _number(_hipController)
          : null,
      trouserLength:
          parameterProfile.includes(ClothingMeasurementField.trouserLength)
          ? _number(_trouserLengthController)
          : null,
      purchasePrice: _number(_priceController),
      purchaseDate: _purchaseDate,
      notes: _optionalText(_notesController),
      isDeleted: initialItem?.isDeleted ?? false,
      wearCount: initialItem?.wearCount ?? 0,
      minWornTemperature: initialItem?.minWornTemperature,
      maxWornTemperature: initialItem?.maxWornTemperature,
      createdAt: initialItem?.createdAt ?? now,
      updatedAt: now,
    );
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialItem != null;
    final parameterProfile = ClothingParameterProfile.forCategory(
      _categoryController.text,
    );
    return Scaffold(
      key: WardrobeKeys.clothingForm,
      appBar: AppBar(title: Text(isEditing ? '编辑衣服' : '新增衣服')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            InkWell(
              key: WardrobeKeys.clothingImagePicker,
              onTap: _isPickingImage ? null : _pickImage,
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  LocalClothingImage(
                    imagePath: _imagePath,
                    width: double.infinity,
                    height: 230,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.48),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isPickingImage)
                            const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          else
                            const Icon(
                              Icons.add_photo_alternate_outlined,
                              color: Colors.white,
                              size: 19,
                            ),
                          const SizedBox(width: 7),
                          Text(
                            _imagePath == null ? '选择图片' : '更换图片',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_imagePath != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: WardrobeKeys.clothingImageAnalyze,
                  onPressed: _isAnalyzingImage
                      ? null
                      : () => _analyzeImage(_imagePath!),
                  icon: _isAnalyzingImage
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.document_scanner_outlined),
                  label: Text(_isAnalyzingImage ? '读取中…' : '读取图片参数'),
                ),
              ),
              if (_imageAnalysisStatus case final status?)
                Padding(
                  key: WardrobeKeys.clothingImageAnalysisStatus,
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    status,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 18),
            TextFormField(
              key: WardrobeKeys.clothingNameField,
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '衣服名称 *',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入衣服名称' : null,
            ),
            const SizedBox(height: 18),
            Text('季节（最多三个）', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final season in _seasons)
                  FilterChip(
                    key: WardrobeKeys.season(season),
                    label: Text(season),
                    selected: _selectedSeasons.contains(season),
                    onSelected: (selected) => _toggleSeason(season, selected),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _SuggestionDropdown(
              key: WardrobeKeys.clothingCategoryField,
              controller: _categoryController,
              label: '品类（可直接输入新增）',
              suggestions: widget.categories,
            ),
            const SizedBox(height: 12),
            _SuggestionDropdown(
              key: WardrobeKeys.clothingBrandField,
              controller: _brandController,
              label: '品牌（可直接输入新增）',
              suggestions: widget.brands,
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: '基础信息',
              children: [
                _TextField(controller: _colorController, label: '颜色'),
                _TextField(controller: _materialController, label: '材质'),
                _TextField(controller: _sizeController, label: '尺码'),
              ],
            ),
            if (parameterProfile.fields.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SectionCard(
                title: '尺寸（厘米）',
                children: [
                  if (parameterProfile.includes(
                    ClothingMeasurementField.clothingLength,
                  ))
                    _NumberField(
                      key: WardrobeKeys.clothingLengthField,
                      controller: _clothingLengthController,
                      label: '衣长',
                    ),
                  if (parameterProfile.includes(
                    ClothingMeasurementField.shoulderWidth,
                  ))
                    _NumberField(
                      key: WardrobeKeys.clothingShoulderWidthField,
                      controller: _shoulderWidthController,
                      label: '肩宽',
                    ),
                  if (parameterProfile.includes(
                    ClothingMeasurementField.chestCircumference,
                  ))
                    _NumberField(
                      key: WardrobeKeys.clothingChestField,
                      controller: _chestController,
                      label: '胸围',
                    ),
                  if (parameterProfile.includes(
                    ClothingMeasurementField.sleeveLength,
                  ))
                    _NumberField(
                      key: WardrobeKeys.clothingSleeveLengthField,
                      controller: _sleeveLengthController,
                      label: '袖长',
                    ),
                  if (parameterProfile.includes(
                    ClothingMeasurementField.waistCircumference,
                  ))
                    _NumberField(
                      key: WardrobeKeys.clothingWaistField,
                      controller: _waistController,
                      label: '腰围',
                    ),
                  if (parameterProfile.includes(
                    ClothingMeasurementField.hipCircumference,
                  ))
                    _NumberField(
                      key: WardrobeKeys.clothingHipField,
                      controller: _hipController,
                      label: '臀围',
                    ),
                  if (parameterProfile.includes(
                    ClothingMeasurementField.trouserLength,
                  ))
                    _NumberField(
                      key: WardrobeKeys.clothingTrouserLengthField,
                      controller: _trouserLengthController,
                      label: '裤长',
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            _SectionCard(
              title: '购买信息',
              children: [
                _NumberField(controller: _priceController, label: '购买价格'),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('购买日期'),
                  subtitle: Text(
                    _purchaseDate == null ? '未填写' : _formatDate(_purchaseDate!),
                  ),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: _selectPurchaseDate,
                ),
                TextFormField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: '备注',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          key: WardrobeKeys.clothingSubmit,
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: Text(isEditing ? '保存修改' : '保存衣服'),
        ),
      ),
    );
  }

  static TextEditingController _numberController(double? value) {
    if (value == null) {
      return TextEditingController();
    }
    final text = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
    return TextEditingController(text: text);
  }

  static String? _optionalText(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  static double? _number(TextEditingController controller) {
    return double.tryParse(controller.text.trim());
  }

  static String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class _SuggestionDropdown extends StatelessWidget {
  const _SuggestionDropdown({
    super.key,
    required this.controller,
    required this.label,
    required this.suggestions,
  });

  final TextEditingController controller;
  final String label;
  final List<String> suggestions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return DropdownMenu<String>(
          controller: controller,
          width: constraints.maxWidth,
          enableFilter: true,
          enableSearch: true,
          requestFocusOnTap: true,
          label: Text(label),
          dropdownMenuEntries: [
            for (final suggestion in suggestions)
              DropdownMenuEntry(value: suggestion, label: suggestion),
          ],
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
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
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index != children.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      textInputAction: TextInputAction.next,
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    super.key,
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final normalized = value?.trim() ?? '';
        if (normalized.isEmpty || double.tryParse(normalized) != null) {
          return null;
        }
        return '请输入有效数字';
      },
    );
  }
}
