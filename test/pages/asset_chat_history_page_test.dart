import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_chat.dart';
import 'package:my_web_app/pages/asset_chat_history_page.dart';
import 'package:my_web_app/services/asset_chat_history_repository.dart';

class _FakeHistoryRepository implements AssetChatHistoryRepository {
  _FakeHistoryRepository({required List<AssetChatThreadSummary> threads})
      : _threads = List.of(threads);

  final List<AssetChatThreadSummary> _threads;
  final List<String> deletedIds = [];

  @override
  Future<AssetChatThreadPage> fetchThreads({
    String searchQuery = '',
    int offset = 0,
    int limit = 50,
  }) async {
    final normalized = searchQuery.trim().toLowerCase();
    final filtered = normalized.isEmpty
        ? _threads
        : _threads
            .where((thread) => thread.title.toLowerCase().contains(normalized))
            .toList(growable: false);
    final end = (offset + limit).clamp(0, filtered.length);
    return AssetChatThreadPage(
      items:
          offset >= filtered.length ? const [] : filtered.sublist(offset, end),
      hasMore: end < filtered.length,
    );
  }

  @override
  Future<AssetChatMessagePage> fetchMessages({
    required String threadId,
    int offset = 0,
    int limit = 100,
  }) async {
    return AssetChatMessagePage(
      items: [
        AssetChatStoredMessage(
          id: 'assistant-1',
          threadId: threadId,
          role: AssetChatMessageRole.assistant,
          text: '未払い予定を先に確認してください。',
          tokensIn: 100,
          tokensOut: 20,
          model: 'gemini-2.5-flash',
          createdAt: DateTime.utc(2026, 8, 18, 2),
        ),
        AssetChatStoredMessage(
          id: 'user-1',
          threadId: threadId,
          role: AssetChatMessageRole.user,
          text: '今月の支払いを確認して',
          tokensIn: 0,
          tokensOut: 0,
          model: null,
          createdAt: DateTime.utc(2026, 8, 18, 1),
        ),
      ],
      hasMore: false,
    );
  }

  @override
  Future<void> deleteThread(String threadId) async {
    deletedIds.add(threadId);
    _threads.removeWhere((thread) => thread.id == threadId);
  }
}

AssetChatThreadSummary _thread(String id, String title) {
  return AssetChatThreadSummary(
    id: id,
    title: title,
    createdAt: DateTime.utc(2026, 8, 18, 1),
    lastMessageAt: DateTime.utc(2026, 8, 18, 2),
  );
}

Widget _app(_FakeHistoryRepository repository) {
  return MaterialApp(
    home: AssetChatHistoryPage(repository: repository),
  );
}

void main() {
  testWidgets('shows thread list and message detail in a wide layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeHistoryRepository(
      threads: [_thread('thread-1', '今月の支払い相談')],
    );

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('asset_chat_history_wide_layout')), findsOne);
    expect(find.text('今月の支払い相談'), findsOneWidget);
    expect(
      find.byKey(const Key('asset_chat_history_no_selection')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('asset_chat_thread_thread-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('asset_chat_history_detail')), findsOneWidget);
    expect(find.text('今月の支払いを確認して'), findsOneWidget);
    expect(find.text('未払い予定を先に確認してください。'), findsOneWidget);
    expect(find.textContaining('120 tokens'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('searches by title and clears the result', (tester) async {
    final repository = _FakeHistoryRepository(
      threads: [
        _thread('thread-1', '支払い相談'),
        _thread('thread-2', '資産配分相談'),
      ],
    );

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('asset_chat_history_search_input')),
      '支払い',
    );
    await tester.tap(
      find.byKey(const Key('asset_chat_history_search_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('支払い相談'), findsOneWidget);
    expect(find.text('資産配分相談'), findsNothing);
    expect(find.textContaining('検索結果'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('asset_chat_history_clear_search_button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('資産配分相談'), findsOneWidget);
  });

  testWidgets('confirms deletion and removes the whole thread', (tester) async {
    final repository = _FakeHistoryRepository(
      threads: [_thread('thread-1', '削除対象の相談')],
    );

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('asset_chat_delete_thread-1')));
    await tester.pumpAndSettle();

    expect(find.text('チャットを削除しますか？'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('asset_chat_delete_confirm_button')),
    );
    await tester.pumpAndSettle();

    expect(repository.deletedIds, ['thread-1']);
    expect(find.byKey(const Key('asset_chat_history_empty')), findsOneWidget);
  });

  testWidgets('uses list-detail navigation without overflow on a narrow screen',
      (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeHistoryRepository(
      threads: [_thread('thread-1', 'モバイル相談')],
    );

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('asset_chat_history_narrow_layout')), findsOne);

    await tester.tap(find.byKey(const Key('asset_chat_thread_thread-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('asset_chat_history_detail')), findsOneWidget);
    expect(
      find.byKey(const Key('asset_chat_history_back_to_list')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.byKey(const Key('asset_chat_history_back_to_list')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('asset_chat_history_thread_list')), findsOne);
  });
}
