import 'dart:io';

import 'package:flutter/material.dart';

class LocalClothingImage extends StatelessWidget {
  const LocalClothingImage({
    super.key,
    required this.imagePath,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.placeholder,
    this.semanticLabel = '衣服图片',
  });

  final String? imagePath;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final Widget? placeholder;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final normalizedPath = imagePath?.trim();
    final file = normalizedPath == null || normalizedPath.isEmpty
        ? null
        : File(normalizedPath);
    final canShowFile =
        !_isFlutterTest && file != null && _fileExistsSafely(file);

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: canShowFile
            ? Image.file(
                file,
                width: width,
                height: height,
                fit: fit,
                semanticLabel: semanticLabel,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholder(context);
                },
              )
            : _buildPlaceholder(context),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Semantics(
      label: '$semanticLabel不可用',
      image: true,
      child:
          placeholder ??
          ColoredBox(
            key: const ValueKey('local-clothing-image-placeholder'),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Center(
              child: Icon(
                Icons.checkroom_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
    );
  }

  static bool _fileExistsSafely(File file) {
    try {
      return file.existsSync();
    } on FileSystemException {
      return false;
    } on ArgumentError {
      return false;
    }
  }

  static bool get _isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');
}
