import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/kitchen_export.dart';
import 'export_image_renderer.dart';

class KitchenExportPage extends StatefulWidget {
  const KitchenExportPage({
    super.key,
    required this.document,
    this.asImage = true,
    this.allowText = false,
    this.renderer,
  });
  final KitchenExport document;
  final bool asImage, allowText;
  final Future<ExportImages> Function(KitchenExport)? renderer;
  @override
  State<KitchenExportPage> createState() => _KitchenExportPageState();
}

class _KitchenExportPageState extends State<KitchenExportPage> {
  late bool asImage = widget.asImage;
  bool busy = false;
  ExportImages? images;
  String? error;
  @override
  void initState() {
    super.initState();
    if (asImage) _generate();
  }

  Future<void> _generate() async {
    if (busy || images != null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await (widget.renderer ?? ExportImageRenderer.render)(
        widget.document,
      );
      if (mounted) setState(() => images = result);
    } catch (_) {
      if (mounted) setState(() => error = '图片生成失败，请重试或减少导出内容');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _share(BuildContext anchor) async {
    if (busy) return;
    final box = anchor.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => busy = true);
    try {
      final files = <XFile>[];
      if (asImage) {
        final directory = Directory(
          '${(await getTemporaryDirectory()).path}/kitchen_exports',
        );
        await directory.create(recursive: true);
        final cutoff = DateTime.now().subtract(const Duration(days: 1));
        await for (final entity in directory.list(followLinks: false)) {
          if (entity is File && entity.path.endsWith('.png')) {
            try {
              if ((await entity.stat()).modified.isBefore(cutoff)) {
                await entity.delete();
              }
            } catch (_) {
              /* Old cache cleanup does not block a new export. */
            }
          }
        }
        final stamp = DateTime.now().microsecondsSinceEpoch;
        for (var i = 0; i < images!.pages.length; i++) {
          final file = File('${directory.path}/export-$stamp-${i + 1}.png');
          await file.writeAsBytes(images!.pages[i], flush: true);
          files.add(XFile(file.path, mimeType: 'image/png'));
        }
      }
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          title: widget.document.title,
          text: asImage ? null : widget.document.text,
          files: asImage ? files : null,
          sharePositionOrigin: origin,
        ),
      );
      // Opening/dismissing the native share sheet is not a delivery receipt.
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('导出失败，请重试或选择其他应用')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.document.text));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已复制文字')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('复制失败，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('导出预览')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (widget.allowText)
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('图片')),
                    ButtonSegment(value: false, label: Text('文字')),
                  ],
                  selected: {asImage},
                  onSelectionChanged: busy
                      ? null
                      : (value) {
                          setState(() => asImage = value.single);
                          if (asImage) _generate();
                        },
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (!asImage)
                    OutlinedButton.icon(
                      onPressed: busy ? null : _copy,
                      icon: const Icon(Icons.copy),
                      label: const Text('复制文字'),
                    ),
                  Builder(
                    builder: (anchor) => FilledButton.icon(
                      onPressed: busy || (asImage && images == null)
                          ? null
                          : () => _share(anchor),
                      icon: const Icon(Icons.ios_share),
                      label: Text(asImage ? '分享图片' : '分享文字'),
                    ),
                  ),
                ],
              ),
              if (asImage && images != null)
                Text('共 ${images!.pages.length} 张，左右滑动预览'),
              const Text('通过系统分享面板选择保存或发送的应用', textAlign: TextAlign.center),
              if (asImage && images?.warning.isNotEmpty == true)
                Text(images!.warning),
            ],
          ),
        ),
        if (busy) const LinearProgressIndicator(),
        Expanded(
          child: !asImage
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: SelectableText(widget.document.text),
                )
              : error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(error!),
                      TextButton(onPressed: _generate, child: const Text('重试')),
                    ],
                  ),
                )
              : images == null
              ? const Center(child: Text('正在生成图片…'))
              : PageView.builder(
                  itemCount: images!.pages.length,
                  itemBuilder: (_, i) => InteractiveViewer(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.memory(
                        images!.pages[i],
                        fit: BoxFit.contain,
                        semanticLabel: '第${i + 1}张导出图片',
                      ),
                    ),
                  ),
                ),
        ),
      ],
    ),
  );
}
