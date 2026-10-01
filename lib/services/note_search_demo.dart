/// Fixed, public examples. Never reads or writes an account's notes.
class NoteSearchDemo {
  static const notes = <Map<String, dynamic>>[
    {
      'id': 'sample-shopping',
      'title': '週末の買い物',
      'content': '買い物メモ。パン、牛乳、りんごを買う。帰宅したら冷蔵庫に片付ける。',
      'tags': ['暮らし'],
    },
    {
      'id': 'sample-flutter',
      'title': 'Flutter学習メモ',
      'content': 'Flutterの検索画面を作る。再検索中も前の結果を残し、ノートを開いてから一覧に戻れるようにする。',
      'tags': ['学習'],
    },
    {
      'id': 'sample-review',
      'title': '先月の振り返り',
      'content': '学習の振り返り。平日は短いメモを残せた。来月は週末にメモを読み直す時間を作る。',
      'tags': ['学習', '振り返り'],
    },
  ];

  static Future<Object?> search(String query) async {
    // A visible, disclosed delay lets readers try retained results.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final terms = query.trim().toLowerCase().split(RegExp(r'\s+'));
    return {
      'results': notes.where((note) {
        final text = '${note['title']} ${note['content']} ${note['tags']}'
            .toLowerCase();
        return terms.every(text.contains);
      }).map(Map<String, dynamic>.from).toList(),
      'searchMode': 'sample',
    };
  }
}
