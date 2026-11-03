import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../domain/kitchen_export.dart';

class ExportImages {
  ExportImages(this.pages, {this.warning = ''});
  final List<Uint8List> pages;
  final String warning;
}

/// A bounded page at a time, with page breaks between complete text lines.
class ExportImageRenderer {
  static const double width = 800,
      height = 1120,
      margin = 48,
      top = 90,
      bottom = 1040;

  static Future<ui.Image?> _photo(String path) async {
    ImageProvider provider;
    if (path.startsWith('assets/')) {
      provider = AssetImage(path);
    } else if (path.startsWith(
      'https://lifeatlas-updates.xiziyuse.workers.dev/v1/app/image?',
    )) {
      provider = NetworkImage(path);
    } else if (!path.contains('://')) {
      provider = FileImage(File(path));
    } else {
      throw const FormatException('不支持的图片来源');
    }
    final stream = ResizeImage(
      provider,
      width: 800,
    ).resolve(ImageConfiguration.empty);
    final result = Completer<ui.Image>();
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!result.isCompleted) result.complete(info.image.clone());
      },
      onError: (Object error, StackTrace? stack) {
        if (!result.isCompleted) result.completeError(error, stack);
      },
    );
    stream.addListener(listener);
    try {
      return await result.future.timeout(const Duration(seconds: 12));
    } finally {
      stream.removeListener(listener);
    }
  }

  static Future<ExportImages> render(
    KitchenExport document, {
    String? fontFamily,
  }) async {
    if (document.text.length > 200000) {
      throw const FormatException('内容过长，请精简后重试');
    }
    final pages = <Uint8List>[];
    ui.Image? photo;
    var warning = '';
    if (document.image.isNotEmpty) {
      try {
        photo = await _photo(document.image);
      } catch (_) {
        warning = '主图未能载入，已保留完整文字内容';
      }
    }
    TextPainter painter(String text, double size, {bool bold = false}) =>
        TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: const Color(0xff242d29),
              fontSize: size,
              fontFamily: fontFamily,
              height: 1.5,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: width - margin * 2);
    final retained = <TextPainter>[];
    late ui.PictureRecorder recorder;
    late Canvas canvas;
    double y = top;
    void begin() {
      recorder = ui.PictureRecorder();
      canvas = Canvas(recorder);
      canvas.drawColor(Colors.white, BlendMode.src);
      final label = painter('LifeAtlas · 厨房', 18);
      label.paint(canvas, const Offset(margin, 26));
      retained.add(label);
      canvas.drawLine(
        const Offset(margin, 70),
        const Offset(width - margin, 70),
        Paint()..color = const Color(0xffdbe5de),
      );
      y = top;
    }

    Future<void> finish() async {
      if (pages.length >= 60) throw const FormatException('导出超过60页，请精简后重试');
      final footer = painter('第 ${pages.length + 1} 页', 18);
      footer.paint(canvas, const Offset(margin, height - 48));
      retained.add(footer);
      final picture = recorder.endRecording();
      ui.Image? image;
      try {
        image = await picture.toImage(width.toInt(), height.toInt());
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) throw StateError('图片生成失败');
        pages.add(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
      } finally {
        image?.dispose();
        picture.dispose();
      }
    }

    begin();
    try {
      if (photo != null) {
        paintImage(
          canvas: canvas,
          rect: const Rect.fromLTWH(margin, top, width - margin * 2, 240),
          image: photo,
          fit: BoxFit.cover,
        );
        y += 264;
      }
      final blocks = [document.title, ...document.sections];
      for (var block = 0; block < blocks.length; block++) {
        final text = painter(
          blocks[block],
          block == 0 ? 36 : 24,
          bold: block == 0,
        );
        try {
          if (text.height <= bottom - top && y + text.height > bottom) {
            await finish();
            begin();
          }
          final lines = text.computeLineMetrics();
          var line = 0;
          while (line < lines.length) {
            final start = line == 0
                ? 0.0
                : lines[line].baseline - lines[line].ascent;
            var end = start;
            while (line < lines.length) {
              final next = lines[line].baseline + lines[line].descent;
              if (y + next - start > bottom) break;
              end = next;
              line++;
            }
            if (end == start) {
              await finish();
              begin();
              continue;
            }
            canvas.save();
            canvas.clipRect(
              Rect.fromLTWH(margin, y, width - margin * 2, end - start),
            );
            text.paint(canvas, Offset(margin, y - start));
            canvas.restore();
            y += end - start;
            if (line < lines.length) {
              await finish();
              begin();
            }
          }
          y += 24;
        } finally {
          retained.add(text);
        }
      }
      await finish();
      return ExportImages(pages, warning: warning);
    } finally {
      photo?.dispose();
      for (final text in retained) {
        text.dispose();
      }
      if (recorder.isRecording) recorder.endRecording().dispose();
    }
  }
}
