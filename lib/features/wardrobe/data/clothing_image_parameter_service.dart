import '../domain/models/clothing_image_parameters.dart';

/// Extracts editable clothing suggestions from a product image or screenshot.
abstract interface class ClothingImageParameterService {
  bool get isConfigured;

  Future<ClothingImageParameters> analyze(String imagePath);
}

class UnconfiguredClothingImageParameterService
    implements ClothingImageParameterService {
  const UnconfiguredClothingImageParameterService();

  @override
  bool get isConfigured => false;

  @override
  Future<ClothingImageParameters> analyze(String imagePath) async {
    throw const ClothingImageParameterUnavailableException();
  }
}

class ClothingImageParameterUnavailableException implements Exception {
  const ClothingImageParameterUnavailableException([
    this.message = '图片参数识别服务尚未配置',
  ]);

  final String message;

  @override
  String toString() => message;
}
