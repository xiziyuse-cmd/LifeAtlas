import 'package:flutter/material.dart';

typedef QuickRecordSaver =
    Future<bool> Function(String text, List<String> imagePaths);

class QuickRecordCard extends StatefulWidget {
  const QuickRecordCard({super.key, required this.onSave});

  final QuickRecordSaver onSave;

  @override
  State<QuickRecordCard> createState() => _QuickRecordCardState();
}

class _QuickRecordCardState extends State<QuickRecordCard> {
  final _textController = TextEditingController();
  final _imagePaths = <String>[];
  bool _isSaving = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _addImagePath() async {
    final pathController = TextEditingController();
    final imagePath = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('添加图片'),
          content: TextField(
            controller: pathController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '图片路径',
              hintText: '输入设备中的图片完整路径',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (value) {
              final normalized = value.trim();
              if (normalized.isNotEmpty) {
                Navigator.of(context).pop(normalized);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final normalized = pathController.text.trim();
                if (normalized.isNotEmpty) {
                  Navigator.of(context).pop(normalized);
                }
              },
              child: const Text('添加'),
            ),
          ],
        );
      },
    );
    pathController.dispose();

    if (!mounted || imagePath == null || imagePath.isEmpty) {
      return;
    }

    setState(() {
      if (!_imagePaths.contains(imagePath)) {
        _imagePaths.add(imagePath);
      }
    });
  }

  Future<void> _submit() async {
    if (_textController.text.trim().isEmpty && _imagePaths.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入文字或添加图片')));
      return;
    }

    setState(() => _isSaving = true);
    final saved = await widget.onSave(
      _textController.text,
      List.unmodifiable(_imagePaths),
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
      if (saved) {
        _textController.clear();
        _imagePaths.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.secondaryContainer,
                  foregroundColor: colorScheme.onSecondaryContainer,
                  child: const Icon(Icons.auto_awesome_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI 快捷记录',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '先记录此刻，AI 能力后续接入',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('home-quick-record-text'),
              controller: _textController,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: '写下今天发生的事……',
                filled: true,
                fillColor: colorScheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_imagePaths.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final path in _imagePaths)
                    InputChip(
                      avatar: const Icon(Icons.image_outlined, size: 18),
                      label: Text(
                        _fileName(path),
                        overflow: TextOverflow.ellipsis,
                      ),
                      onDeleted: _isSaving
                          ? null
                          : () => setState(() => _imagePaths.remove(path)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('home-add-image'),
                  onPressed: _isSaving ? null : _addImagePath,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('图片'),
                ),
                const Spacer(),
                FilledButton.icon(
                  key: const ValueKey('home-save-quick-record'),
                  onPressed: _isSaving ? null : _submit,
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(_isSaving ? '保存中' : '保存记录'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '图片 AI 读取与 Prompt 将在后续版本接入。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fileName(String path) {
    final segments = path.split(RegExp(r'[/\\]'));
    return segments.isEmpty || segments.last.isEmpty ? path : segments.last;
  }
}
