import '../models/note.dart';

/// 並び替えの種類
enum SortType {
  updatedDesc('更新日時（新しい順）'),
  updatedAsc('更新日時（古い順）'),
  createdDesc('作成日時（新しい順）'),
  createdAsc('作成日時（古い順）'),
  titleAsc('タイトル（A→Z）'),
  titleDesc('タイトル（Z→A）');

  const SortType(this.label);
  final String label;

  /// ノートリストをソートする
  void sortNotes(List<Note> notes) {
    switch (this) {
      case SortType.updatedDesc:
        notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case SortType.updatedAsc:
        notes.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        break;
      case SortType.createdDesc:
        notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortType.createdAsc:
        notes.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortType.titleAsc:
        notes.sort((a, b) {
          final aTitle = a.title.isEmpty ? '' : a.title.toLowerCase();
          final bTitle = b.title.isEmpty ? '' : b.title.toLowerCase();
          if (aTitle.isEmpty && bTitle.isEmpty) return 0;
          if (aTitle.isEmpty) return 1;
          if (bTitle.isEmpty) return -1;
          return aTitle.compareTo(bTitle);
        });
        break;
      case SortType.titleDesc:
        notes.sort((a, b) {
          final aTitle = a.title.isEmpty ? '' : a.title.toLowerCase();
          final bTitle = b.title.isEmpty ? '' : b.title.toLowerCase();
          if (aTitle.isEmpty && bTitle.isEmpty) return 0;
          if (aTitle.isEmpty) return 1;
          if (bTitle.isEmpty) return -1;
          return bTitle.compareTo(aTitle);
        });
        break;
    }
  }
}
