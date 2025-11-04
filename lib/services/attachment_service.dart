import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import '../main.dart';
import '../models/attachment.dart';

class AttachmentService {
  static const int maxFileSize = 5 * 1024 * 1024; // 5MB
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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf'],
        withData: true, // Web用
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // ファイルサイズチェック
        if (file.size > maxFileSize) {
          throw Exception('ファイルサイズは5MB以下にしてください');
        }

        // MIMEタイプチェック
        final mimeType =
            lookupMimeType(file.name) ?? 'application/octet-stream';
        if (!allowedImageTypes.contains(mimeType) &&
            !allowedPdfTypes.contains(mimeType)) {
          throw Exception('サポートされていないファイル形式です');
        }

        return file;
      }
      return null;
    } catch (e) {
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
      final userId = supabase.auth.currentUser!.id;
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('ファイルデータが取得できません');
      }

      // ファイル情報
      final mimeType = lookupMimeType(file.name) ?? 'application/octet-stream';
      final fileType = _getFileType(mimeType);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_${file.name}';
      final filePath = '$userId/$noteId/$fileName';

      // Supabase Storageにアップロード
      await supabase.storage.from('attachments').uploadBinary(
            filePath,
            bytes,
          );

      // データベースに記録
      final response = await supabase
          .from('attachments')
          .insert({
            'note_id': noteId,
            'user_id': userId,
            'file_name': file.name,
            'file_path': filePath,
            'file_size': file.size,
            'file_type': fileType,
            'mime_type': mimeType,
          })
          .select()
          .single();

      return Attachment.fromJson(response);
    } catch (e) {
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
      await supabase.from('attachments').delete().eq('id', attachment.id);
    } catch (e) {
      rethrow;
    }
  }

  // ファイルの公開URLを取得
  static String getPublicUrl(String filePath) {
    return supabase.storage.from('attachments').getPublicUrl(filePath);
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
