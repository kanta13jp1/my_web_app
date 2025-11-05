import '../main.dart';

/// 添付ファイル数のキャッシュサービス
class AttachmentCacheService {
  static final Map<int, int> _cache = {};

  /// キャッシュをクリア
  static void clearCache() {
    _cache.clear();
  }

  /// 特定のノートのキャッシュをクリア
  static void clearNoteCache(int noteId) {
    _cache.remove(noteId);
  }

  /// 添付ファイル数を取得（キャッシュあり）
  static Future<int> getAttachmentCount(int noteId) async {
    // キャッシュをチェック
    if (_cache.containsKey(noteId)) {
      return _cache[noteId]!;
    }

    try {
      final response =
          await supabase.from('attachments').select('id').eq('note_id', noteId);
      final count = (response as List).length;

      // キャッシュに保存
      _cache[noteId] = count;

      return count;
    } catch (e) {
      return 0;
    }
  }
}
