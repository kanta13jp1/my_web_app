import 'package:flutter/material.dart';
import 'package:my_web_app/pages/ai_search_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Synthetic data source for browser tests; production builds use lib/main.dart.
void main() {
  WidgetsFlutterBinding.ensureInitialized().ensureSemantics();
  final attempts = <String, int>{};
  final guest = Uri.base.queryParameters['guest'] == '1';
  runApp(
    MaterialApp(
      theme: ThemeData(fontFamily: 'NotoSansJP'),
      routes: {
        '/login': (_) => Scaffold(appBar: AppBar(title: const Text('ログイン入口'))),
      },
      home: AiSearchPage(
        supabaseClient: guest
            ? SupabaseClient('https://example.invalid', 'fixture-public-key')
            : null,
        notePageBuilder: (id) => Scaffold(
          appBar: AppBar(title: const Text('保存ノートを開いた画面')),
          body: Text('保存された本文: $id'),
        ),
        search: (query) async {
          final count = attempts.update(
            query,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
          await Future<void>.delayed(
            Duration(milliseconds: query == '遅い検索' ? 1800 : 250),
          );
          if (query == '失敗から再試行' && count == 1) {
            throw Exception('controlled failure');
          }
          return {
            'results': query == '該当なし'
                ? []
                : [
                    {
                      'id': 'fixture-$query',
                      'title': '$query のノート',
                      'content': '画面試験用の合成ノートです。実ユーザーの情報ではありません。',
                      'tags': ['試験'],
                    },
                  ],
            'searchMode': 'text',
          };
        },
      ),
    ),
  );
}
