import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

class KitchenImage extends StatelessWidget {
  const KitchenImage(this.path, {super.key, this.height = 150});
  final String path;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: path.isEmpty
        ? SizedBox(
            height: height,
            width: double.infinity,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.restaurant, size: 40),
            ),
          )
        : path.startsWith('assets/')
        ? Image.asset(
            path,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => SizedBox(
              height: height,
              width: double.infinity,
              child: const Center(child: Icon(Icons.broken_image_outlined)),
            ),
          )
        : Image.file(
            File(path),
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => SizedBox(
              height: height,
              child: const Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
  );
}

Future<String?> pickKitchenMedia({bool video = false}) async {
  final picker = ImagePicker();
  final source = video
      ? await picker.pickVideo(source: ImageSource.gallery)
      : await picker.pickImage(
          source: ImageSource.gallery,
          requestFullMetadata: false,
        );
  if (source == null) return null;
  final directory = Directory(
    p.join(
      (await getApplicationDocumentsDirectory()).path,
      'lifeatlas',
      'kitchen',
    ),
  );
  await directory.create(recursive: true);
  final path = p.join(
    directory.path,
    '${DateTime.now().microsecondsSinceEpoch}${p.extension(source.path)}',
  );
  await source.saveTo(path);
  return path;
}

void kitchenError(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error is FormatException ? error.message : '操作失败：$error'),
      ),
    );

Future<bool> confirmKitchenDelete(BuildContext context, String name) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除$name？'),
        content: const Text('此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    ) ??
    false;

class KitchenVideo extends StatefulWidget {
  const KitchenVideo(this.path, {super.key});
  final String path;
  @override
  State<KitchenVideo> createState() => _KitchenVideoState();
}

class _KitchenVideoState extends State<KitchenVideo> {
  late final VideoPlayerController _controller;
  String? _error;
  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.path));
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _error = '视频无法读取');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _error != null
      ? Text(_error!)
      : !_controller.value.isInitialized
      ? const LinearProgressIndicator()
      : Column(
          children: [
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              icon: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
              label: const Text('播放 / 暂停'),
            ),
          ],
        );
}

/// A disposable editor used for ingredient, inventory and other short forms.
Future<List<String>?> kitchenFields(
  BuildContext context,
  String title,
  List<String> labels,
  List<String> values, {
  Set<int> numeric = const {},
  Map<int, List<String>> choices = const {},
  String? Function(List<String>)? validate,
}) async {
  return showDialog<List<String>>(
    context: context,
    builder: (_) => _FieldsDialog(
      title: title,
      labels: labels,
      values: values,
      numeric: numeric,
      choices: choices,
      validate: validate,
    ),
  );
}

class _FieldsDialog extends StatefulWidget {
  const _FieldsDialog({
    required this.title,
    required this.labels,
    required this.values,
    required this.numeric,
    required this.choices,
    this.validate,
  });
  final String title;
  final List<String> labels, values;
  final Set<int> numeric;
  final Map<int, List<String>> choices;
  final String? Function(List<String>)? validate;
  @override
  State<_FieldsDialog> createState() => _FieldsDialogState();
}

class _FieldsDialogState extends State<_FieldsDialog> {
  String? _error;
  late final _controllers = widget.values
      .map((v) => TextEditingController(text: v))
      .toList();
  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _controllers.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: widget.choices.containsKey(i)
                    ? DropdownButtonFormField<String>(
                        initialValue: _controllers[i].text,
                        decoration: InputDecoration(
                          labelText: widget.labels[i],
                        ),
                        items: [
                          for (final value in widget.choices[i]!)
                            DropdownMenuItem(value: value, child: Text(value)),
                        ],
                        onChanged: (value) => _controllers[i].text = value!,
                      )
                    : TextField(
                        controller: _controllers[i],
                        decoration: InputDecoration(
                          labelText: widget.labels[i],
                        ),
                        keyboardType: widget.numeric.contains(i)
                            ? const TextInputType.numberWithOptions(
                                decimal: true,
                              )
                            : TextInputType.text,
                        maxLines: widget.numeric.contains(i) ? 1 : null,
                      ),
              ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
      FilledButton(
        onPressed: () {
          final values = _controllers.map((c) => c.text.trim()).toList();
          final error = widget.validate?.call(values);
          if (error != null) {
            setState(() => _error = error);
            return;
          }
          Navigator.pop(context, values);
        },
        child: const Text('确定'),
      ),
    ],
  );
}
