/// UNDO/REDO機能用の編集履歴スナップショット
class NoteSnapshot {
  final String title;
  final String content;
  final int? categoryId;
  final DateTime timestamp;

  NoteSnapshot({
    required this.title,
    required this.content,
    this.categoryId,
    required this.timestamp,
  });

  /// スナップショットのコピーを作成
  NoteSnapshot copyWith({
    String? title,
    String? content,
    int? categoryId,
  }) {
    return NoteSnapshot(
      title: title ?? this.title,
      content: content ?? this.content,
      categoryId: categoryId ?? this.categoryId,
      timestamp: DateTime.now(),
    );
  }

  /// 別のスナップショットと内容が同一かチェック
  bool isIdenticalTo(NoteSnapshot other) {
    return title == other.title &&
        content == other.content &&
        categoryId == other.categoryId;
  }

  @override
  String toString() {
    return 'NoteSnapshot(title: $title, contentLength: ${content.length}, categoryId: $categoryId, timestamp: $timestamp)';
  }
}
