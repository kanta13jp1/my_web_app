import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/palm_reading_exception.dart';
import '../models/palm_reading_image.dart';

abstract interface class PalmReadingImagePicker {
  Future<PalmReadingImage?> pick(PalmImageSource source);
}

class ImagePickerPalmReadingImagePicker implements PalmReadingImagePicker {
  ImagePickerPalmReadingImagePicker({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  static const int maxImageBytes = 4 * 1024 * 1024;
  static const Set<String> allowedMimeTypes = <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  final ImagePicker _picker;

  static bool get cameraSupported {
    return kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  Future<PalmReadingImage?> pick(PalmImageSource source) async {
    XFile? file;
    try {
      file = await _picker.pickImage(
        source: source == PalmImageSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
        preferredCameraDevice: CameraDevice.rear,
      );
    } catch (_) {
      throw PalmReadingException(
        source == PalmImageSource.camera
            ? 'この端末ではカメラを起動できません。写真を選ぶ方法をお試しください。'
            : '写真を選択できませんでした。端末の写真アクセス権限をご確認ください。',
        code: 'imagePickerUnavailable',
      );
    }
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final mimeType = _mimeType(file);
    if (!allowedMimeTypes.contains(mimeType)) {
      throw const PalmReadingException(
        'JPEG・PNG・WebP形式の写真を選んでください。',
        code: 'unsupportedImageType',
      );
    }
    if (bytes.isEmpty) {
      throw const PalmReadingException('写真データを読み込めませんでした。', code: 'emptyImage');
    }
    if (bytes.length > maxImageBytes) {
      throw const PalmReadingException(
        '写真は4MB以下にしてください。少し小さいサイズで撮り直してください。',
        code: 'imageTooLarge',
      );
    }
    return PalmReadingImage(
      fileName: _safeFileName(file.name, mimeType),
      mimeType: mimeType,
      bytes: bytes,
    );
  }

  String _mimeType(XFile file) {
    final declared = file.mimeType?.toLowerCase().trim();
    if (declared != null && allowedMimeTypes.contains(declared)) {
      return declared;
    }
    final extension = file.name.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  String _safeFileName(String value, String mimeType) {
    final fallback = switch (mimeType) {
      'image/png' => 'palm.png',
      'image/webp' => 'palm.webp',
      _ => 'palm.jpg',
    };
    final sanitized = value
        .trim()
        .replaceAll(RegExp(r'[\r\n\\/]+'), '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    if (sanitized.isEmpty) return fallback;
    return sanitized.length <= 120 ? sanitized : sanitized.substring(0, 120);
  }
}
