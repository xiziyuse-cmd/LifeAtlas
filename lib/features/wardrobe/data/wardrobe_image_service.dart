import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

typedef WardrobeDocumentsDirectoryProvider = Future<Directory> Function();

/// Selects wardrobe images and moves them out of the picker cache.
abstract interface class WardrobeImageService {
  /// Opens the device gallery for a single image.
  ///
  /// Returns the persisted local path, or `null` when the picker is cancelled.
  Future<String?> pickSingleFromGallery();

  /// Recovers picker results after Android has killed and recreated the app.
  ///
  /// Every recovered file is copied into the same durable wardrobe directory
  /// used by [pickSingleFromGallery].
  Future<List<String>> retrieveLostData();
}

class DeviceWardrobeImageService implements WardrobeImageService {
  DeviceWardrobeImageService({
    ImagePicker? imagePicker,
    WardrobeDocumentsDirectoryProvider? documentsDirectoryProvider,
    DateTime Function()? clock,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _clock = clock ?? DateTime.now;

  final ImagePicker _imagePicker;
  final WardrobeDocumentsDirectoryProvider _documentsDirectoryProvider;
  final DateTime Function() _clock;

  int _fileSequence = 0;

  @override
  Future<String?> pickSingleFromGallery() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (pickedFile == null) {
      return null;
    }

    return _persist(pickedFile);
  }

  @override
  Future<List<String>> retrieveLostData() async {
    final response = await _imagePicker.retrieveLostData();
    if (response.isEmpty) {
      return const [];
    }

    final recoveredFiles = response.files;
    if (recoveredFiles == null || recoveredFiles.isEmpty) {
      final exception = response.exception;
      if (exception != null) {
        throw exception;
      }
      return const [];
    }

    final persistedPaths = <String>[];
    for (final recoveredFile in recoveredFiles) {
      persistedPaths.add(await _persist(recoveredFile));
    }
    return List.unmodifiable(persistedPaths);
  }

  Future<String> _persist(XFile source) async {
    final documentsDirectory = await _documentsDirectoryProvider();
    final wardrobeDirectory = Directory(
      p.join(documentsDirectory.path, 'lifeatlas', 'wardrobe'),
    );
    await wardrobeDirectory.create(recursive: true);

    final extension = _extensionFor(source);
    late File destination;
    do {
      final timestamp = _clock().toUtc().microsecondsSinceEpoch;
      final sequence = _fileSequence++;
      destination = File(
        p.join(
          wardrobeDirectory.path,
          'wardrobe_${timestamp}_$sequence$extension',
        ),
      );
    } while (await destination.exists());

    await source.saveTo(destination.path);
    return destination.path;
  }

  static String _extensionFor(XFile source) {
    final nameExtension = p.extension(source.name);
    if (nameExtension.isNotEmpty) {
      return nameExtension;
    }
    return p.extension(source.path);
  }
}
