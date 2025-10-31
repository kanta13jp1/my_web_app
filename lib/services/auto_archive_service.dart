import '../main.dart';
import '../models/note.dart';

class AutoArchiveService {
  // 期限切れから30日経過したメモを自動アーカイブ
  static Future<int> autoArchiveOverdueNotes() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      // 期限切れから30日経過したメモを取得
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final response = await supabase
          .from('notes')
          .select()
          .eq('user_id', userId)
          .eq('is_archived', false)
          .not('reminder_date', 'is', null)
          .lt('reminder_date', thirtyDaysAgo.toIso8601String());

      final notes = (response as List).map((note) => Note.fromJson(note)).toList();

      if (notes.isEmpty) return 0;

      // 一括アーカイブ
      final noteIds = notes.map((note) => note.id).toList();
      await supabase.from('notes').update({
        'is_archived': true,
        'archived_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).inFilter('id', noteIds);  // ← 修正

      return notes.length;
    } catch (error) {
      return 0;
    }
  }

  // アーカイブされてから90日経過したメモを完全削除
  static Future<int> deleteOldArchivedNotes() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      // 90日前の日付
      final ninetyDaysAgo = DateTime.now().subtract(const Duration(days: 90));

      final response = await supabase
          .from('notes')
          .select()
          .eq('user_id', userId)
          .eq('is_archived', true)
          .not('archived_at', 'is', null)
          .lt('archived_at', ninetyDaysAgo.toIso8601String());

      final notes = (response as List).map((note) => Note.fromJson(note)).toList();

      if (notes.isEmpty) return 0;

      // 一括削除
      final noteIds = notes.map((note) => note.id).toList();
      await supabase.from('notes').delete().inFilter('id', noteIds);  // ← 修正

      return notes.length;
    } catch (error) {
      return 0;
    }
  }
}