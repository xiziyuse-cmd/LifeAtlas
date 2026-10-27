import 'package:flutter/material.dart';
import '../domain/kitchen_models.dart';
import 'kitchen_widgets.dart';

class StepFormPage extends StatefulWidget {
  const StepFormPage({
    super.key,
    this.step,
    this.canParallel = false,
    this.stepNumber = 1,
    required this.materials,
    required this.seasonings,
  });
  final RecipeStep? step;
  final bool canParallel;
  final int stepNumber;
  final List<RecipeMaterial> materials, seasonings;
  @override
  State<StepFormPage> createState() => _StepFormPageState();
}

class _StepFormPageState extends State<StepFormPage> {
  late final _name = TextEditingController(
    text: widget.step?.name ?? '步骤 ${widget.stepNumber}',
  );
  late bool _parallel =
      widget.canParallel && (widget.step?.parallelWithPrevious ?? false);
  late final _content = TextEditingController(text: widget.step?.content ?? '');
  late final _duration = TextEditingController(
    text: '${widget.step?.duration ?? 5}',
  );
  late final _materials = <String>{...?widget.step?.materials};
  late final _seasonings = <String>{...?widget.step?.seasonings};
  late String _image = widget.step?.image ?? '',
      _video = widget.step?.video ?? '';
  @override
  void dispose() {
    _name.dispose();
    _content.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _pick(bool video) async {
    try {
      final path = await pickKitchenMedia(video: video);
      if (path != null && mounted) {
        setState(() {
          if (video) {
            _video = path;
          } else {
            _image = path;
          }
        });
      }
    } catch (e) {
      if (mounted) kitchenError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('制作步骤')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: '步骤名称'),
        ),
        TextField(
          controller: _content,
          decoration: const InputDecoration(
            labelText: '步骤描述',
            helperText: '保存时自动提取食材和调料',
          ),
          minLines: 3,
          maxLines: 8,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _duration,
          decoration: const InputDecoration(labelText: '预计耗时（分钟）'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        if (widget.canParallel)
          SwitchListTile(
            key: const ValueKey('step-parallel-switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('并行'),
            value: _parallel,
            onChanged: (value) => setState(() => _parallel = value),
          ),
        const Text('使用食材和调料'),
        Wrap(
          spacing: 8,
          children: [
            for (final m in [...widget.materials, ...widget.seasonings])
              FilterChip(
                label: Text(m.name),
                selected:
                    _materials.contains(m.name) || _seasonings.contains(m.name),
                onSelected: (v) => setState(() {
                  final isSeasoning = widget.seasonings.any(
                    (entry) => entry.name == m.name,
                  );
                  final selected = isSeasoning ? _seasonings : _materials;
                  v ? selected.add(m.name) : selected.remove(m.name);
                }),
              ),
          ],
        ),
        if (_image.isNotEmpty) KitchenImage(_image),
        TextButton(
          onPressed: () => _pick(false),
          child: const Text('添加 / 更换步骤图片'),
        ),
        if (_image.isNotEmpty)
          TextButton(
            onPressed: () => setState(() => _image = ''),
            child: const Text('移除图片'),
          ),
        if (_video.isNotEmpty) KitchenVideo(_video, key: ValueKey(_video)),
        TextButton(
          onPressed: () => _pick(true),
          child: const Text('添加 / 更换步骤视频'),
        ),
        if (_video.isNotEmpty)
          TextButton(
            onPressed: () => setState(() => _video = ''),
            child: const Text('移除视频'),
          ),
        FilledButton(
          onPressed: () {
            final d = int.tryParse(_duration.text);
            if (_name.text.trim().isEmpty ||
                _content.text.trim().isEmpty ||
                d == null ||
                d < 0) {
              kitchenError(context, const FormatException('请填写步骤名称、描述及非负整数耗时'));
              return;
            }
            Navigator.pop(
              context,
              RecipeStep(
                name: _name.text.trim(),
                content: _content.text.trim(),
                duration: d,
                parallelWithPrevious: widget.canParallel && _parallel,
                materials: _materials.toList(),
                seasonings: _seasonings.toList(),
                image: _image,
                video: _video,
              ),
            );
          },
          child: const Text('保存步骤'),
        ),
      ],
    ),
  );
}
