import 'package:flutter/material.dart';
import '../../lib/pages/ai_search_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized().ensureSemantics();
  final attempts = <String, int>{};
  runApp(MaterialApp(home: AiSearchPage(search: (query) async {
    final count = attempts.update(query, (value) => value + 1, ifAbsent: () => 1);
    await Future<void>.delayed(Duration(milliseconds: query == '遅い検索' ? 1800 : 250));
    if (query == '失敗から再試行' && count == 1) throw Exception('controlled failure');
    return {
      'results': query == '該当なし' ? [] : [
        {'title': '$query のノート', 'content': '画面試験用の合成ノートです。実ユーザーの情報ではありません。', 'tags': ['試験']},
      ],
      'searchMode': 'text',
    };
  })));
}
