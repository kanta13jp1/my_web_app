import '../main.dart';
import '../models/note.dart';

/// ノートに対する操作（ピン留め、お気に入り、アーカイブ、削除など）を管理するサービス
class NoteOperationsService {
  /// ノートのピン留め状態を切り替え
  static Future<void> togglePin(Note note) async {
    await supabase.from('notes').update({
      'is_pinned': !note.isPinned,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', note.id);
  }

  /// ノートのお気に入り状態を切り替え
  static Future<void> toggleFavorite(Note note) async {
    await supabase.from('notes').update({
      'is_favorite': !note.isFavorite,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', note.id);
  }

  /// ノートをアーカイブ
  static Future<void> archiveNote(Note note) async {
    await supabase.from('notes').update({
      'is_archived': true,
      'archived_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', note.id);
  }

  /// アーカイブされたノートを復元
  static Future<void> restoreNote(int noteId) async {
    await supabase.from('notes').update({
      'is_archived': false,
      'archived_at': null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', noteId);
  }

  /// ノートを削除
  static Future<void> deleteNote(int noteId) async {
    await supabase.from('notes').delete().eq('id', noteId);
  }

  /// ノートのリマインダーを更新
  static Future<void> updateReminder(Note note, DateTime? reminderDate) async {
    await supabase.from('notes').update({
      'reminder_date': reminderDate?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', note.id);
  }
}
