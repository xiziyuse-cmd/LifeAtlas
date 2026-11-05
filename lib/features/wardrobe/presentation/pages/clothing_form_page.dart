import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/clothing_image_parameter_service.dart';
import '../../data/wardrobe_image_service.dart';
import '../../domain/models/clothing_image_parameters.dart';
import '../../domain/models/clothing_item.dart';
import '../../domain/models/clothing_parameter.dart';
import '../wardrobe_keys.dart';
import '../widgets/local_clothing_image.dart';
import '../widgets/wardrobe_tag.dart';

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
  static const _visibleMeasurementGroups = {
    '尺寸',
    '裤装尺寸',
    '内衣尺寸',
    '鞋履尺寸',
    '箱包尺寸',
    '配饰尺寸',
  };

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _colorController;
  late final TextEditingController _sizeController;
  late final Map<String, TextEditingController> _parameterControllers;
  late final TextEditingController _priceController;
  late final TextEditingController _notesController;

  late final Set<String> _selectedSeasons;
  String? _selectedCategory;
  String? _imagePath;
  String? _measurementImagePath;
  DateTime? _purchaseDate;
  bool _showMeasurements = false;
  bool _isPickingImage = false;
  bool _isPickingMeasurementImage = false;
  bool _isAnalyzingMeasurementImage = false;
  String? _measurementAnalysisStatus;
  ClothingImageDiagnostic? _measurementDiagnostic;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _nameController = TextEditingController(text: item?.name);
    _brandController = TextEditingController(text: item?.brand);
    _colorController = TextEditingController(text: item?.color);
    _sizeController = TextEditingController(text: item?.size);
    _parameterControllers = {
      for (final definition in ClothingParameterCatalog.definitions.where(
        (definition) => _visibleMeasurementGroups.contains(definition.group),
      ))
        definition.key: TextEditingController(
          text: item?.parameterValues[definition.key]?.editableText,
        ),
    };
    _fillLegacyParameter('clothing_length', item?.clothingLength);
    _fillLegacyParameter('shoulder_width', item?.shoulderWidth);
    _fillLegacyParameter('chest_circumference', item?.chestCircumference);
    _fillLegacyParameter('sleeve_length', item?.sleeveLength);
    final legacyWaist =
        item?.parameterValues['waist_circumference']?.numberValue ??
        item?.waistCircumference;
    _fillLegacyParameter('waist_circumference_min', legacyWaist);
    _fillLegacyParameter('waist_circumference_max', legacyWaist);
    _fillLegacyParameter('hip_circumference', item?.hipCircumference);
    for (final base in ['hip_circumference', 'thigh_circumference']) {
      final old =
          item?.parameterValues[base]?.numberValue ??
          (base == 'hip_circumference' ? item?.hipCircumference : null);
      if (!(item?.parameterValues.containsKey('${base}_min') ?? false) &&
          !(item?.parameterValues.containsKey('${base}_max') ?? false)) {
        _fillLegacyParameter('${base}_min', old);
        _fillLegacyParameter('${base}_max', old);
      }
    }
    _fillLegacyParameter('trouser_length', item?.trouserLength);
    _priceController = _numberController(item?.purchasePrice);
    _notesController = TextEditingController(text: item?.notes);
    _selectedSeasons = {...?item?.seasonTags};
    _selectedCategory = item?.category;
    _imagePath = item?.imagePath;
    _purchaseDate = item?.purchaseDate;
    _recoverLostImage();
  }

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _brandController,
      _colorController,
      _sizeController,
      _priceController,
      _notesController,
      ..._parameterControllers.values,
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
    } on Object {
      // A failed recovery must not prevent manual editing or another pick.
    }
  }

  Future<void> _pickImage() async {
    setState(() => _isPickingImage = true);
    try {
      final selectedImagePath = await widget.imageService
          .pickSingleFromGallery();
      if (mounted && selectedImagePath != null) {
        setState(() => _imagePath = selectedImagePath);
      }
    } on Object catch (error, stackTrace) {
      developer.log(
        '衣服展示图片上传失败',
        name: 'lifeatlas.wardrobe.form',
        error: error.runtimeType.toString(),
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('图片上传失败，请重新上传')));
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  Future<void> _pickMeasurementImage() async {
    setState(() => _isPickingMeasurementImage = true);
    try {
      final selectedImagePath = await widget.imageService
          .pickSingleFromGallery();
      if (mounted && selectedImagePath != null) {
        setState(() {
          _measurementImagePath = selectedImagePath;
          _measurementAnalysisStatus = null;
          _measurementDiagnostic = null;
        });
      }
    } on Object catch (error, stackTrace) {
      developer.log(
        '尺寸图片上传失败',
        name: 'lifeatlas.wardrobe.form',
        error: error.runtimeType.toString(),
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('图片上传失败，请重新上传')));
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingMeasurementImage = false);
      }
    }
  }

  void _fillLegacyParameter(String key, double? value) {
    final controller = _parameterControllers[key];
    if (controller != null) {
      _fillNumberIfEmpty(controller, value);
    }
  }

  Future<void> _analyzeMeasurementImage(String imagePath) async {
    if (_isAnalyzingMeasurementImage) return;
    final watch = Stopwatch()..start();
    final startedAt = DateTime.now().toUtc().toIso8601String();
    var applying = false;
    if (!widget.imageParameterService.isConfigured) {
      if (mounted) {
        setState(() {
          _measurementAnalysisStatus = '请先配置 AI 接口，可继续手动填写尺寸';
        });
      }
      return;
    }

    setState(() {
      _isAnalyzingMeasurementImage = true;
      _measurementAnalysisStatus = '正在识别尺寸…';
      _measurementDiagnostic = null;
    });
    try {
      final parameters = await widget.imageParameterService.analyze(imagePath);
      if (!mounted || _measurementImagePath != imagePath) {
        return;
      }
      applying = true;
      _applyMeasurementParameters(parameters);
      setState(() => _measurementAnalysisStatus = '已识别尺寸，请核对后保存');
    } on ClothingImageParameterRequestException catch (error, stackTrace) {
      developer.log(
        'AI 尺寸识别请求失败',
        name: 'lifeatlas.wardrobe.form',
        error: error.runtimeType.toString(),
        stackTrace: stackTrace,
      );
      if (mounted && _measurementImagePath == imagePath) {
        setState(() {
          _measurementAnalysisStatus = error.message;
          _measurementDiagnostic =
              error.diagnostic ??
              ClothingImageDiagnostic(
                code: 'request_failed',
                phase: '识别请求',
                elapsedMs: watch.elapsedMilliseconds,
                startedAt: startedAt,
                exceptionType: error.runtimeType.toString(),
              );
        });
      }
    } on ClothingImageParameterUnavailableException catch (error, stackTrace) {
      developer.log(
        'AI 尺寸识别服务未配置',
        name: 'lifeatlas.wardrobe.form',
        error: error.runtimeType.toString(),
        stackTrace: stackTrace,
      );
      if (mounted && _measurementImagePath == imagePath) {
        setState(() => _measurementAnalysisStatus = error.message);
      }
    } on Object catch (error, stackTrace) {
      developer.log(
        'AI 尺寸识别发生未分类异常',
        name: 'lifeatlas.wardrobe.form',
        error: error.runtimeType.toString(),
        stackTrace: stackTrace,
      );
      if (mounted && _measurementImagePath == imagePath) {
        setState(() {
          _measurementAnalysisStatus = '识别暂未完成，请查看错误详情';
          _measurementDiagnostic = ClothingImageDiagnostic(
            code: applying ? 'result_application' : 'unexpected',
            phase: applying ? '填写识别结果' : '请求识别服务',
            elapsedMs: watch.elapsedMilliseconds,
            startedAt: startedAt,
            exceptionType: error.runtimeType.toString(),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzingMeasurementImage = false);
      }
    }
  }

  Future<void> _showMeasurementDiagnostic() async {
    final diagnostic = _measurementDiagnostic;
    if (diagnostic == null) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('识别错误详情'),
        content: SingleChildScrollView(child: SelectableText(diagnostic.text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('关闭'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await Clipboard.setData(ClipboardData(text: diagnostic.text));
                if (c.mounted) {
                  ScaffoldMessenger.of(
                    c,
                  ).showSnackBar(const SnackBar(content: Text('诊断信息已复制')));
                }
              } catch (_) {
                if (c.mounted) {
                  ScaffoldMessenger.of(
                    c,
                  ).showSnackBar(const SnackBar(content: Text('复制失败，请重试')));
                }
              }
            },
            child: const Text('复制诊断信息'),
          ),
        ],
      ),
    );
  }

  void _applyMeasurementParameters(ClothingImageParameters parameters) {
    _fillTextIfEmpty(_sizeController, parameters.size);
    _fillRecognizedNumber('clothing_length', parameters.clothingLength);
    _fillRecognizedNumber('shoulder_width', parameters.shoulderWidth);
    _fillRecognizedNumber('chest_circumference', parameters.chestCircumference);
    _fillRecognizedNumber('sleeve_length', parameters.sleeveLength);
    _fillRecognizedNumber('hip_circumference', parameters.hipCircumference);
    _fillRecognizedNumber('trouser_length', parameters.trouserLength);
    for (final entry in parameters.parameterValues.entries) {
      final definition = ClothingParameterCatalog.byKey[entry.key];
      final controller = _parameterControllers[entry.key];
      if (definition == null ||
          !_measurementDefinitions.any((item) => item.key == definition.key) ||
          controller == null ||
          controller.text.trim().isNotEmpty) {
        continue;
      }
      final value = entry.value;
      if (value is num) {
        _fillNumberIfEmpty(controller, value.toDouble());
      } else if (value is String) {
        _fillTextIfEmpty(controller, value);
      }
    }
    for (final base in ['hip_circumference', 'thigh_circumference']) {
      if (!parameters.parameterValues.containsKey('${base}_min') &&
          !parameters.parameterValues.containsKey('${base}_max')) {
        final value =
            parameters.parameterValues[base] ??
            (base == 'hip_circumference' ? parameters.hipCircumference : null);
        if (value is num) {
          _fillRecognizedNumber('${base}_min', value.toDouble());
          _fillRecognizedNumber('${base}_max', value.toDouble());
        }
      }
    }
    _fillWaistRangeIfEmpty(parameters.waistCircumference);
    setState(() {});
  }

  void _fillRecognizedNumber(String key, double? value) {
    final isVisible = _measurementDefinitions.any(
      (definition) => definition.key == key,
    );
    final controller = _parameterControllers[key];
    if (isVisible && controller != null) {
      _fillNumberIfEmpty(controller, value);
    }
  }

  void _fillWaistRangeIfEmpty(double? value) {
    _fillRecognizedNumber('waist_circumference_min', value);
    _fillRecognizedNumber('waist_circumference_max', value);
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

  Future<void> _selectSeasons() async {
    final temporarySelection = {..._selectedSeasons};
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '选择季节（最多三个）',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final season in _seasons)
                      FilterChip(
                        key: WardrobeKeys.season(season),
                        label: Text(season),
                        backgroundColor: WardrobeTagColors.of(
                          context,
                          WardrobeTagKind.season,
                        ).background,
                        selectedColor: WardrobeTagColors.of(
                          context,
                          WardrobeTagKind.season,
                        ).background,
                        labelStyle: TextStyle(
                          color: WardrobeTagColors.of(
                            context,
                            WardrobeTagKind.season,
                          ).foreground,
                        ),
                        checkmarkColor: WardrobeTagColors.of(
                          context,
                          WardrobeTagKind.season,
                        ).foreground,

                        selected: temporarySelection.contains(season),
                        onSelected: (isSelected) {
                          if (isSelected && temporarySelection.length >= 3) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(content: Text('一件衣服最多选择三个季节')),
                            );
                            return;
                          }
                          setSheetState(() {
                            if (isSelected) {
                              temporarySelection.add(season);
                            } else {
                              temporarySelection.remove(season);
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: WardrobeKeys.clothingSeasonConfirm,
                  onPressed: () =>
                      Navigator.of(sheetContext).pop(temporarySelection),
                  child: const Text('完成'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedSeasons
          ..clear()
          ..addAll(selected);
      });
    }
  }

  Future<void> _selectCategory() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('选择品类', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in _categoryOptions)
                    ChoiceChip(
                      key: WardrobeKeys.category(category),
                      label: Text(category),
                      backgroundColor: WardrobeTagColors.of(
                        context,
                        WardrobeTagKind.category,
                      ).background,
                      selectedColor: WardrobeTagColors.of(
                        context,
                        WardrobeTagKind.category,
                      ).background,
                      labelStyle: TextStyle(
                        color: WardrobeTagColors.of(
                          context,
                          WardrobeTagKind.category,
                        ).foreground,
                      ),
                      checkmarkColor: WardrobeTagColors.of(
                        context,
                        WardrobeTagKind.category,
                      ).foreground,
                      showCheckmark: true,

                      selected: _selectedCategory == category,
                      onSelected: (_) =>
                          Navigator.of(sheetContext).pop(category),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _selectedCategory = selected);
    }
  }

  List<String> get _categoryOptions {
    final categories = [...widget.categories];
    final selected = _selectedCategory?.trim() ?? '';
    if (selected.isNotEmpty && !categories.contains(selected)) {
      categories.add(selected);
    }
    return categories;
  }

  List<ClothingParameterDefinition> get _measurementDefinitions =>
      ClothingParameterCatalog.forCategory(_selectedCategory)
          .where(
            (definition) =>
                _visibleMeasurementGroups.contains(definition.group),
          )
          .toList(growable: false);

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
    final parameterValues = _parameterValuesForCategory(_selectedCategory);
    double? parameterNumber(String key) => parameterValues[key]?.numberValue;
    final item = ClothingItem(
      id: initialItem?.id,
      name: _nameController.text.trim(),
      imagePath: imagePath,
      brand: _optionalText(_brandController),
      category: _selectedCategory,
      seasonTags: [
        for (final season in _seasons)
          if (_selectedSeasons.contains(season)) season,
      ],
      color: _optionalText(_colorController),
      material: initialItem?.material,
      size: _optionalText(_sizeController),
      clothingLength: parameterNumber('clothing_length'),
      shoulderWidth: parameterNumber('shoulder_width'),
      chestCircumference: parameterNumber('chest_circumference'),
      sleeveLength: parameterNumber('sleeve_length'),
      waistCircumference: null,
      hipCircumference: parameterNumber('hip_circumference'),
      trouserLength: parameterNumber('trouser_length'),
      parameterValues: parameterValues,
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
    final parameterDefinitions = _measurementDefinitions;
    final parameterGroups = <String, List<ClothingParameterDefinition>>{};
    for (final definition in parameterDefinitions) {
      parameterGroups.putIfAbsent(definition.group, () => []).add(definition);
    }
    return Scaffold(
      key: WardrobeKeys.clothingForm,
      appBar: AppBar(title: Text(isEditing ? '编辑衣服' : '新增衣服')),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
            _SelectionField(
              key: WardrobeKeys.clothingSeasonSelector,
              label: '季节',
              value: _selectedSeasons.isEmpty
                  ? null
                  : [
                      for (final season in _seasons)
                        if (_selectedSeasons.contains(season)) season,
                    ].join('、'),
              placeholder: '请选择季节（最多三个）',
              onTap: _selectSeasons,
            ),
            const SizedBox(height: 12),
            _SelectionField(
              key: WardrobeKeys.clothingCategorySelector,
              label: '品类',
              value: _selectedCategory,
              placeholder: '请选择品类',
              onTap: _selectCategory,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: WardrobeKeys.clothingSizeToggle,
              onPressed: () {
                setState(() => _showMeasurements = !_showMeasurements);
              },
              icon: Icon(
                _showMeasurements ? Icons.expand_less : Icons.expand_more,
              ),
              label: const Text('衣服尺寸'),
            ),
            if (_showMeasurements) ...[
              const SizedBox(height: 12),
              _SectionCard(
                key: WardrobeKeys.clothingSizeContent,
                title: '衣服尺寸',
                children: [
                  _TextField(controller: _sizeController, label: '尺码'),
                  InkWell(
                    key: WardrobeKeys.clothingMeasurementImagePicker,
                    onTap: _isPickingMeasurementImage
                        ? null
                        : _pickMeasurementImage,
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        LocalClothingImage(
                          imagePath: _measurementImagePath,
                          width: double.infinity,
                          height: 160,
                          borderRadius: BorderRadius.circular(14),
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
                                if (_isPickingMeasurementImage)
                                  const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.document_scanner_outlined,
                                    color: Colors.white,
                                    size: 19,
                                  ),
                                const SizedBox(width: 7),
                                Text(
                                  _measurementImagePath == null
                                      ? '上传尺寸图片'
                                      : '更换尺寸图片',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_measurementImagePath != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonalIcon(
                        key: WardrobeKeys.clothingMeasurementImageAnalyze,
                        onPressed: _isAnalyzingMeasurementImage
                            ? null
                            : () => _analyzeMeasurementImage(
                                _measurementImagePath!,
                              ),
                        icon: _isAnalyzingMeasurementImage
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.auto_awesome_outlined),
                        label: Text(
                          _isAnalyzingMeasurementImage ? '识别中…' : 'AI识别尺寸',
                        ),
                      ),
                    ),
                  if (_measurementAnalysisStatus case final status?)
                    Text(
                      status,
                      key: WardrobeKeys.clothingMeasurementImageStatus,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (_measurementDiagnostic != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const ValueKey('measurement-error-details'),
                        onPressed: _showMeasurementDiagnostic,
                        icon: const Icon(Icons.info_outline),
                        label: const Text('查看错误详情'),
                      ),
                    ),
                  for (final entry in parameterGroups.entries) ...[
                    Text(
                      entry.key,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    for (final definition in entry.value)
                      if (const [
                        'waist_circumference_min',
                        'hip_circumference_min',
                        'thigh_circumference_min',
                      ].contains(definition.key))
                        _RangeNumberField(
                          key: definition.key == 'waist_circumference_min'
                              ? WardrobeKeys.clothingWaistRange
                              : ValueKey('${definition.key}_range'),
                          label: definition.label.replaceAll('最小值', ''),
                          fieldBase: definition.key.replaceAll('_min', ''),
                          minimumController:
                              _parameterControllers[definition.key]!,
                          maximumController:
                              _parameterControllers[definition.key.replaceAll(
                                '_min',
                                '_max',
                              )]!,
                          unit: definition.unit,
                        )
                      else if (const [
                        'waist_circumference_max',
                        'hip_circumference_max',
                        'thigh_circumference_max',
                      ].contains(definition.key))
                        const SizedBox.shrink()
                      else if (definition.type == ClothingParameterType.number)
                        _NumberField(
                          key: _legacyFieldKey(definition.key),
                          controller: _parameterControllers[definition.key]!,
                          label: _parameterLabel(definition),
                        )
                      else
                        _TextField(
                          controller: _parameterControllers[definition.key]!,
                          label: definition.label,
                        ),
                  ],
                ],
              ),
            ],
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
              children: [_TextField(controller: _colorController, label: '颜色')],
            ),
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

  Map<String, ClothingParameterValue> _parameterValuesForCategory(
    String? category,
  ) {
    final values = <String, ClothingParameterValue>{};
    for (final definition
        in ClothingParameterCatalog.forCategory(category).where(
          (definition) => _visibleMeasurementGroups.contains(definition.group),
        )) {
      final text = _parameterControllers[definition.key]!.text.trim();
      if (text.isEmpty) {
        continue;
      }
      values[definition.key] = definition.type == ClothingParameterType.number
          ? ClothingParameterValue(
              key: definition.key,
              numberValue: double.tryParse(text),
              unit: definition.unit,
            )
          : ClothingParameterValue(
              key: definition.key,
              textValue: text,
              unit: definition.unit,
            );
    }
    final initialValues = widget.initialItem?.parameterValues ?? const {};
    for (final entry in initialValues.entries) {
      final definition = ClothingParameterCatalog.byKey[entry.key];
      if (definition != null &&
          !_visibleMeasurementGroups.contains(definition.group)) {
        values.putIfAbsent(entry.key, () => entry.value);
      }
    }
    return values;
  }

  static String _parameterLabel(ClothingParameterDefinition definition) {
    final unit = definition.unit;
    return unit == null || unit.isEmpty
        ? definition.label
        : '${definition.label}（$unit）';
  }

  static Key? _legacyFieldKey(String key) => switch (key) {
    'clothing_length' => WardrobeKeys.clothingLengthField,
    'shoulder_width' => WardrobeKeys.clothingShoulderWidthField,
    'chest_circumference' => WardrobeKeys.clothingChestField,
    'sleeve_length' => WardrobeKeys.clothingSleeveLengthField,
    'hip_circumference' => WardrobeKeys.clothingHipField,
    'trouser_length' => WardrobeKeys.clothingTrouserLengthField,
    _ => null,
  };

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

class _SelectionField extends StatelessWidget {
  const _SelectionField({
    super.key,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayValue = value?.trim();
    final isEmpty = displayValue == null || displayValue.isEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScaler = MediaQuery.textScalerOf(context);
          final useVerticalLayout =
              constraints.maxWidth < 300 || textScaler.scale(16) > 21;
          final selector = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: InputDecorator(
              isEmpty: isEmpty,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.fromLTRB(12, 13, 8, 13),
                suffixIcon: Icon(Icons.expand_more),
              ),
              child: Text(
                isEmpty ? placeholder : displayValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: isEmpty
                    ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )
                    : Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );
          final labelWidget = Text(
            '$label：',
            maxLines: 1,
            style: Theme.of(context).textTheme.bodyLarge,
          );
          if (useVerticalLayout) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelWidget, const SizedBox(height: 8), selector],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              labelWidget,
              const SizedBox(width: 12),
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: selector),
              ),
            ],
          );
        },
      ),
    );
  }
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
  const _SectionCard({super.key, required this.title, required this.children});

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
        return '$label格式有误，请输入数字';
      },
    );
  }
}

class _RangeNumberField extends StatelessWidget {
  const _RangeNumberField({
    super.key,
    required this.label,
    required this.minimumController,
    required this.fieldBase,
    required this.maximumController,
    required this.unit,
  });

  final String label;
  final String fieldBase;
  final TextEditingController minimumController;
  final TextEditingController maximumController;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final displayUnit = unit?.trim() ?? '';
    final title = displayUnit.isEmpty ? label : '$label（$displayUnit）';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: fieldBase == 'waist_circumference'
                    ? WardrobeKeys.clothingWaistMinField
                    : ValueKey('${fieldBase}_min'),
                controller: minimumController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '最小值',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => _validateNumber(value, '$label最小值'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('–'),
            ),
            Expanded(
              child: TextFormField(
                key: fieldBase == 'waist_circumference'
                    ? WardrobeKeys.clothingWaistMaxField
                    : ValueKey('${fieldBase}_max'),
                controller: maximumController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '最大值',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final error = _validateNumber(value, '$label最大值');
                  if (error != null) return error;
                  final min = double.tryParse(minimumController.text.trim());
                  final max = double.tryParse(value?.trim() ?? '');
                  return min != null && max != null && min > max
                      ? '最大值不得小于最小值'
                      : null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String? _validateNumber(String? value, String label) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return null;
    final number = double.tryParse(normalized);
    if (number == null || !number.isFinite || number <= 0) {
      return '$label请输入大于0的数字';
    }
    return null;
  }
}
