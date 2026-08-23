import 'dart:convert';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/photo_action_advice.dart';

const int photoActionMaxImageBytes = 8 * 1024 * 1024;

enum PhotoActionImageSource { camera, gallery }

class PhotoActionImage {
  const PhotoActionImage({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
}

class PhotoActionAdvisorException implements Exception {
  const PhotoActionAdvisorException(
    this.message, {
    this.requiresLogin = false,
  });

  final String message;
  final bool requiresLogin;

  @override
  String toString() => message;
}

abstract interface class PhotoActionImagePicker {
  Future<PhotoActionImage?> pick(PhotoActionImageSource source);
}

abstract interface class PhotoActionAnalyzer {
  Future<PhotoActionAdvice> analyze(PhotoActionImage image);
}

class ImagePickerPhotoActionImagePicker implements PhotoActionImagePicker {
  ImagePickerPhotoActionImagePicker({ImagePicker? imagePicker})
      : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  @override
  Future<PhotoActionImage?> pick(PhotoActionImageSource source) async {
    final file = await _imagePicker.pickImage(
      source: source == PhotoActionImageSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const PhotoActionAdvisorException('空の画像は解析できません。');
    }
    if (bytes.length > photoActionMaxImageBytes) {
      throw const PhotoActionAdvisorException(
        '画像が大きすぎます。8MB以下の画像を選んでください。',
      );
    }
    return PhotoActionImage(
      bytes: bytes,
      fileName: file.name.trim().isEmpty ? 'photo.jpg' : file.name,
      mimeType: _safeMimeType(file.mimeType, file.name),
    );
  }

  static String _safeMimeType(String? suppliedMimeType, String fileName) {
    final normalized = suppliedMimeType?.toLowerCase().trim();
    if (normalized == 'image/png' ||
        normalized == 'image/jpeg' ||
        normalized == 'image/webp') {
      return normalized!;
    }
    final extension = fileName.toLowerCase();
    if (extension.endsWith('.png')) return 'image/png';
    if (extension.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}

class SupabasePhotoActionAnalyzer implements PhotoActionAnalyzer {
  const SupabasePhotoActionAnalyzer(this._client);

  final SupabaseClient _client;

  @override
  Future<PhotoActionAdvice> analyze(PhotoActionImage image) async {
    if (_client.auth.currentUser == null) {
      throw const PhotoActionAdvisorException(
        'AIで写真を解析するにはログインが必要です。',
        requiresLogin: true,
      );
    }
    try {
      final response = await _client.functions.invoke(
        'ai-assistant',
        body: <String, dynamic>{
          'action': 'analyze_photo_actions',
          'imageBase64': base64Encode(image.bytes),
          'mimeType': image.mimeType,
          'fileName': image.fileName,
        },
      );
      final data = _responseMap(response.data);
      if (data['success'] != true) {
        throw PhotoActionAdvisorException(
          _message(data['error']) ?? 'AIが写真を解析できませんでした。',
        );
      }
      final rawResult = data['result'];
      if (rawResult is! Map) {
        throw const PhotoActionAdvisorException('AIの回答形式が正しくありません。');
      }
      return PhotoActionAdvice.fromJson(Map<String, dynamic>.from(rawResult));
    } on PhotoActionAdvisorException {
      rethrow;
    } on FormatException catch (error) {
      throw PhotoActionAdvisorException(error.message);
    } catch (_) {
      throw const PhotoActionAdvisorException(
        'AI分析に失敗しました。通信状態を確認して、もう一度お試しください。',
      );
    }
  }

  static Map<String, dynamic> _responseMap(Object? rawData) {
    final decoded = rawData is String ? jsonDecode(rawData) : rawData;
    if (decoded is! Map) {
      throw const PhotoActionAdvisorException('AIの回答形式が正しくありません。');
    }
    return Map<String, dynamic>.from(decoded);
  }

  static String? _message(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }
}
