import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:my_web_app/models/asset_chat.dart';
import 'package:my_web_app/pages/asset_chat_history_page.dart';
import 'package:my_web_app/services/asset_chat_history_repository.dart';

// Synthetic in-memory history. Never included in the production entrypoint.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  runApp(MaterialApp(
    theme: ThemeData(colorSchemeSeed: const Color(0xFF176B57)),
    home: AssetChatHistoryPage(repository: ReplayFixtureRepository()),
  ));
}

class ReplayFixtureRepository implements AssetChatHistoryRepository {
  int reads = 0;
  bool failOnce = Uri.base.queryParameters['fail'] == 'true';

  @override
  Future<AssetChatThreadPage> fetchThreads({String searchQuery = '', int offset = 0, int limit = 50}) async {
    return AssetChatThreadPage(items: [
      for (final id in ['sample', 'empty'])
        AssetChatThreadSummary(id: id, title: id == 'sample' ? '発表用サンプル' : '空の会話',
          createdAt: DateTime.utc(2026), lastMessageAt: DateTime.utc(2026)),
    ], hasMore: false);
  }

  @override
  Future<AssetChatMessagePage> fetchMessages({required String threadId, int offset = 0, int limit = 100}) async {
    reads++;
    if (failOnce) { failOnce = false; throw Exception('synthetic read failure'); }
    return AssetChatMessagePage(items: threadId == 'empty' ? [] : [
      AssetChatStoredMessage(id: 'answer', threadId: threadId,
        role: AssetChatMessageRole.assistant, text: '保存済み回答です。読み出し回数: $reads',
        tokensIn: 0, tokensOut: 0, model: null, createdAt: DateTime.utc(2026, 1, 1, 0, 1)),
      AssetChatStoredMessage(id: 'prompt', threadId: threadId,
        role: AssetChatMessageRole.user, text: '会話を一件ずつ紹介したいです。',
        tokensIn: 0, tokensOut: 0, model: null, createdAt: DateTime.utc(2026)),
    ], hasMore: threadId == 'sample');
  }

  @override
  Future<void> deleteThread(String threadId) async => throw StateError('Deletion must not run');
}
