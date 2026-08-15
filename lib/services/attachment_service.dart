import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'supabase_client_provider.dart';
import '../models/attachment.dart';
import 'direct_storage_upload_service.dart';

class AttachmentService {
  static const int maxFileSize = 5 * 1024 * 1024; // 5MB
  static const String markdownAttachmentScheme = 'attachment';
  static const List<String> allowedImageTypes = [
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/gif',
    'image/webp',
  ];
  static const List<String> allowedPdfTypes = [
    'application/pdf',
  ];

  // ファイルを選択
  static Future<PlatformFile?> pickFile() async {
    try {
      debugPrint('pickFile start');
      // Web版向けの修正：allowMultipleを明示的にfalseに設定
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf'],
        withData: true, // Web用（必須）
        allowMultiple: false, // Web版で重要
        compressionQuality: 100, // 圧縮を無効化
      );
      debugPrint('pickFile 1 result: $result');
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        debugPrint('pickFile 2 file: $file');
        // ファイルサイズチェック
        if (file.size > maxFileSize) {
          throw Exception('ファイルサイズは5MB以下にしてください');
        }
        debugPrint('pickFile 3 file: $file');
        // MIMEタイプチェック
        final mimeType =
            lookupMimeType(file.name) ?? 'application/octet-stream';
        if (!allowedImageTypes.contains(mimeType) &&
            !allowedPdfTypes.contains(mimeType)) {
          throw Exception('サポートされていないファイル形式です');
        }
        debugPrint('pickFile 4 return file');
        return file;
      }
      debugPrint('pickFile 5 return null');
      return null;
    } catch (e) {
      // デバッグ用：エラーの詳細をログ出力
      debugPrint('❌ File picker error: $e');
      rethrow;
    }
  }

  // ファイルをアップロード
  // uploadFile メソッドの引数を修正
  static Future<Attachment?> uploadFile({
    required int noteId, // String → int に変更
    required PlatformFile file,
  }) async {
    try {
      debugPrint(
        '📎 [AttachmentService] Starting file upload for noteId: $noteId',
      );
      debugPrint(
        '📎 [AttachmentService] File name: ${file.name}, size: ${file.size} bytes',
      );

      final userId = supabase.auth.currentUser!.id;
      debugPrint('📎 [AttachmentService] User ID: $userId');

      final bytes = file.bytes;
      if (bytes == null) {
        debugPrint(
          '❌ [AttachmentService] File bytes is null - this should not happen on Web',
        );
        debugPrint(
          '📎 [AttachmentService] File details: name=${file.name}, size=${file.size}, path=${file.path}',
        );
        throw Exception('ファイルデータが取得できません');
      }
      debugPrint(
        '✅ [AttachmentService] File bytes loaded successfully: ${bytes.length} bytes',
      );

      // ファイル情報
      final mimeType = lookupMimeType(file.name) ?? 'application/octet-stream';
      final fileType = _getFileType(mimeType);
      final uploadService = DirectStorageUploadService.supabase(supabase);

      // ファイル名をURLセーフな形式にサニタイズ
      final uploadResult = await uploadService.uploadAndInsertMetadata(
        bucketId: 'attachments',
        tableName: 'attachments',
        userId: userId,
        bytes: bytes,
        originalFileName: file.name,
        contentType: mimeType,
        ownerPathSegments: <String>[noteId.toString()],
        metadataBuilder: (final object) {
          return <String, dynamic>{
            'note_id': noteId,
            'user_id': object.userId,
            'file_name': file.name,
            'file_path': object.storagePath,
            'file_size': object.sizeBytes,
            'file_type': fileType,
            'mime_type': object.contentType,
          };
        },
      );

      debugPrint(
        '📎 [AttachmentService] MIME type: $mimeType, file type: $fileType',
      );
      debugPrint(
        '📎 [AttachmentService] Upload path: ${uploadResult.storagePath}',
      );

      debugPrint(
        '✅ [AttachmentService] Attachment record inserted successfully',
      );
      debugPrint('📎 [AttachmentService] Attachment metadata inserted');

      return Attachment.fromJson(uploadResult.metadataRow);
    } catch (e, stackTrace) {
      debugPrint('❌ [AttachmentService] Upload failed with error: $e');
      debugPrint('❌ [AttachmentService] Stack trace: $stackTrace');
      debugPrint('📎 [AttachmentService] Error type: ${e.runtimeType}');
      if (e.toString().contains('row level security')) {
        debugPrint('🔒 [AttachmentService] RLS policy error detected');
      } else if (e.toString().contains('cors')) {
        debugPrint('🌐 [AttachmentService] CORS error detected');
      } else if (e.toString().contains('network')) {
        debugPrint('📡 [AttachmentService] Network error detected');
      }
      rethrow;
    }
  }

  // ファイルタイプを判定
  static String _getFileType(String mimeType) {
    if (allowedImageTypes.contains(mimeType)) {
      return 'image';
    } else if (allowedPdfTypes.contains(mimeType)) {
      return 'pdf';
    } else {
      return 'other';
    }
  }

// getAttachments メソッドの引数を修正
  static Future<List<Attachment>> getAttachments(int noteId) async {
    // String → int に変更
    try {
      final response = await supabase
          .from('attachments')
          .select()
          .eq('note_id', noteId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Attachment.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // 添付ファイルを削除
  static Future<void> deleteAttachment(Attachment attachment) async {
    try {
      // Storageから削除
      await supabase.storage.from('attachments').remove([attachment.filePath]);

      // データベースから削除
      await supabase
          .from('attachments')
          .delete()
          .eq('id', attachment.id)
          .select();
    } catch (e) {
      rethrow;
    }
  }

  // ファイルの公開URLを取得
  static String getPublicUrl(String filePath) {
    return supabase.storage.from('attachments').getPublicUrl(filePath);
  }

  static String getMarkdownUrl(String filePath) {
    return '$markdownAttachmentScheme:${Uri.encodeComponent(filePath)}';
  }

  static bool containsAttachmentReference(String markdown) {
    return markdown.contains('$markdownAttachmentScheme:') ||
        markdown.contains('/storage/v1/object/public/attachments/');
  }

  static String? extractAttachmentFilePath(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return null;
    }

    if (uri.scheme == markdownAttachmentScheme) {
      final encodedPath = uri.path.isNotEmpty
          ? uri.path
          : url.substring('$markdownAttachmentScheme:'.length);
      if (encodedPath.isEmpty) {
        return null;
      }
      return Uri.decodeComponent(encodedPath);
    }

    final segments = uri.pathSegments;
    final publicIndex = segments.indexOf('public');
    if (publicIndex == -1 || publicIndex + 1 >= segments.length) {
      return null;
    }
    if (segments[publicIndex + 1] != 'attachments') {
      return null;
    }

    final objectPath = segments.skip(publicIndex + 2).join('/');
    if (objectPath.isEmpty) {
      return null;
    }
    return Uri.decodeComponent(objectPath);
  }

  static Future<String> resolveMarkdownAttachmentUrls(String markdown) async {
    if (!containsAttachmentReference(markdown)) {
      return markdown;
    }

    final replacements = <String, String>{};
    for (final match in RegExp(r'\(([^)]+)\)').allMatches(markdown)) {
      final originalUrl = match.group(1);
      if (originalUrl == null || replacements.containsKey(originalUrl)) {
        continue;
      }
      final filePath = extractAttachmentFilePath(originalUrl);
      if (filePath == null) {
        continue;
      }
      try {
        replacements[originalUrl] = await getSignedUrl(filePath);
      } catch (error) {
        debugPrint(
          '[AttachmentService] Failed to sign markdown attachment $filePath: $error',
        );
      }
    }

    var resolved = markdown;
    for (final entry in replacements.entries) {
      resolved = resolved.replaceAll('(${entry.key})', '(${entry.value})');
    }
    return resolved;
  }

  // ファイルをダウンロード
  static Future<Uint8List> downloadFile(String filePath) async {
    try {
      final bytes =
          await supabase.storage.from('attachments').download(filePath);
      return bytes;
    } catch (e) {
      rethrow;
    }
  }

  // 署名付きURLを取得（プライベートファイル用）
  static Future<String> getSignedUrl(String filePath) async {
    try {
      final url = await supabase.storage
          .from('attachments')
          .createSignedUrl(filePath, 3600); // 1時間有効
      return url;
    } catch (e) {
      rethrow;
    }
  }
}
