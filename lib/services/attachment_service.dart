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
      print('pickFile start');
      // Web版向けの修正：allowMultipleを明示的にfalseに設定
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf'],
        withData: true, // Web用（必須）
        allowMultiple: false, // Web版で重要
        allowCompression: false, // 圧縮を無効化
      );
      print('pickFile 1 result: $result');
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        print('pickFile 2 file: $file');
        // ファイルサイズチェック
        if (file.size > maxFileSize) {
          throw Exception('ファイルサイズは5MB以下にしてください');
        }
        print('pickFile 3 file: $file');
        // MIMEタイプチェック
        final mimeType =
            lookupMimeType(file.name) ?? 'application/octet-stream';
        if (!allowedImageTypes.contains(mimeType) &&
            !allowedPdfTypes.contains(mimeType)) {
          throw Exception('サポートされていないファイル形式です');
        }
        print('pickFile 4 return file');
        return file;
      }
      print('pickFile 5 return null');
      return null;
    } catch (e) {
      // デバッグ用：エラーの詳細をログ出力
      print('❌ File picker error: $e');
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
      print('📎 [AttachmentService] Starting file upload for noteId: $noteId');
      print('📎 [AttachmentService] File name: ${file.name}, size: ${file.size} bytes');

      final userId = supabase.auth.currentUser!.id;
      print('📎 [AttachmentService] User ID: $userId');

      final bytes = file.bytes;
      if (bytes == null) {
        print('❌ [AttachmentService] File bytes is null - this should not happen on Web');
        print('📎 [AttachmentService] File details: name=${file.name}, size=${file.size}, path=${file.path}');
        throw Exception('ファイルデータが取得できません');
      }
      print('✅ [AttachmentService] File bytes loaded successfully: ${bytes.length} bytes');

      // ファイル情報
      final mimeType = lookupMimeType(file.name) ?? 'application/octet-stream';
      final fileType = _getFileType(mimeType);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // ファイル名をURLセーフな形式にサニタイズ
      final safeFileName = _sanitizeFileName(file.name);
      final fileName = '${timestamp}_$safeFileName';
      final filePath = '$userId/$noteId/$fileName';

      print('📎 [AttachmentService] MIME type: $mimeType, file type: $fileType');
      print('📎 [AttachmentService] Upload path: $filePath');

      // Supabase Storageにアップロード
      print('📤 [AttachmentService] Uploading to Supabase Storage...');
      await supabase.storage.from('attachments').uploadBinary(
            filePath,
            bytes,
          );
      print('✅ [AttachmentService] File uploaded to storage successfully');

      // データベースに記録
      print('💾 [AttachmentService] Inserting attachment record to database...');
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

      print('✅ [AttachmentService] Attachment record inserted successfully');
      print('📎 [AttachmentService] Attachment ID: ${response['id']}');

      return Attachment.fromJson(response);
    } catch (e, stackTrace) {
      print('❌ [AttachmentService] Upload failed with error: $e');
      print('❌ [AttachmentService] Stack trace: $stackTrace');
      print('📎 [AttachmentService] Error type: ${e.runtimeType}');
      if (e.toString().contains('row level security')) {
        print('🔒 [AttachmentService] RLS policy error detected');
      } else if (e.toString().contains('cors')) {
        print('🌐 [AttachmentService] CORS error detected');
      } else if (e.toString().contains('network')) {
        print('📡 [AttachmentService] Network error detected');
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

  // ファイル名をURLセーフな形式にサニタイズ
  static String _sanitizeFileName(String fileName) {
    // ファイル名から拡張子を分離
    final lastDot = fileName.lastIndexOf('.');
    final nameWithoutExt = lastDot > 0 ? fileName.substring(0, lastDot) : fileName;
    final extension = lastDot > 0 ? fileName.substring(lastDot) : '';

    // 非ASCII文字と特殊文字をアンダースコアに置換
    // ASCII文字、数字、ハイフン、ピリオドのみ許可
    final sanitized = nameWithoutExt
        .replaceAll(RegExp(r'[^\x00-\x7F]'), '_') // 非ASCII文字を置換
        .replaceAll(RegExp(r'[^\w\-.]'), '_') // 英数字、ハイフン、ピリオド以外を置換
        .replaceAll(RegExp(r'_+'), '_') // 連続するアンダースコアを1つに
        .replaceAll(RegExp(r'^_|_$'), ''); // 先頭と末尾のアンダースコアを削除

    // サニタイズ後のファイル名が空の場合は'file'を使用
    final safeName = sanitized.isEmpty ? 'file' : sanitized;

    return '$safeName$extension';
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
