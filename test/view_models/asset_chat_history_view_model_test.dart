import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_chat.dart';
import 'package:my_web_app/services/asset_chat_history_repository.dart';
import 'package:my_web_app/view_models/asset_chat_history_view_model.dart';

typedef ThreadLoader = Future<AssetChatThreadPage> Function(
  String searchQuery,
  int offset,
  int limit,
);
typedef MessageLoader = Future<AssetChatMessagePage> Function(
  String threadId,
  int offset,
  int limit,
);

class _FakeRepository implements AssetChatHistoryRepository {
  _FakeRepository({
    required this.threadLoader,
    required this.messageLoader,
    this.onDelete,
  });

  final ThreadLoader threadLoader;
  final MessageLoader messageLoader;
  final Future<void> Function(String threadId)? onDelete;

  @override
  Future<AssetChatThreadPage> fetchThreads({
    String searchQuery = '',
    int offset = 0,
    int limit = 50,
  }) =>
      threadLoader(searchQuery, offset, limit);

  @override
  Future<AssetChatMessagePage> fetchMessages({
    required String threadId,
    int offset = 0,
    int limit = 100,
  }) =>
      messageLoader(threadId, offset, limit);

  @override
  Future<void> deleteThread(String threadId) async {
    await onDelete?.call(threadId);
  }
}

AssetChatThreadSummary _thread(int index, {String? title}) {
  final time = DateTime.utc(2026, 8, 18, 0, index % 60);
  return AssetChatThreadSummary(
    id: 'thread-$index',
    title: title ?? '相談 $index',
    createdAt: time,
    lastMessageAt: time,
  );
}

AssetChatStoredMessage _message(int index) {
  return AssetChatStoredMessage(
    id: 'message-$index',
    threadId: 'thread-1',
    role: index.isEven
        ? AssetChatMessageRole.user
        : AssetChatMessageRole.assistant,
    text: 'message $index',
    tokensIn: 0,
    tokensOut: 0,
    model: null,
    createdAt: DateTime.utc(2026, 8, 18, 0, index),
  );
}

void main() {
  test('loads thread pages and applies server-side title search', () async {
    final calls = <String>[];
    final allThreads = List.generate(51, _thread);
    final repository = _FakeRepository(
      threadLoader: (search, offset, limit) async {
        calls.add('$search:$offset:$limit');
        if (search == '支払い') {
          return AssetChatThreadPage(
            items: [_thread(99, title: '支払い相談')],
            hasMore: false,
          );
        }
        final end = (offset + limit).clamp(0, allThreads.length);
        return AssetChatThreadPage(
          items: allThreads.sublist(offset, end),
          hasMore: end < allThreads.length,
        );
      },
      messageLoader: (_, __, ___) async =>
          const AssetChatMessagePage(items: [], hasMore: false),
    );
    final viewModel = AssetChatHistoryViewModel(repository: repository);
    addTearDown(viewModel.dispose);

    await viewModel.initialize();
    expect(viewModel.threads, hasLength(50));
    expect(viewModel.hasMoreThreads, isTrue);

    await viewModel.loadThreads();
    expect(viewModel.threads, hasLength(51));
    expect(viewModel.hasMoreThreads, isFalse);

    await viewModel.search('  支払い  ');
    expect(viewModel.searchQuery, '支払い');
    expect(viewModel.threads.single.title, '支払い相談');
    expect(calls, contains('支払い:0:50'));
  });

  test('loads newest page then prepends older messages chronologically',
      () async {
    final thread = _thread(1);
    final repository = _FakeRepository(
      threadLoader: (_, __, ___) async =>
          AssetChatThreadPage(items: [thread], hasMore: false),
      messageLoader: (_, offset, __) async {
        if (offset == 0) {
          return AssetChatMessagePage(
            items: [_message(4), _message(3)],
            hasMore: true,
          );
        }
        return AssetChatMessagePage(
          items: [_message(2), _message(1)],
          hasMore: false,
        );
      },
    );
    final viewModel = AssetChatHistoryViewModel(repository: repository);
    addTearDown(viewModel.dispose);

    await viewModel.selectThread(thread);
    expect(viewModel.messages.map((message) => message.id), [
      'message-3',
      'message-4',
    ]);
    expect(viewModel.hasOlderMessages, isTrue);

    await viewModel.loadOlderMessages();
    expect(viewModel.messages.map((message) => message.id), [
      'message-1',
      'message-2',
      'message-3',
      'message-4',
    ]);
    expect(viewModel.hasOlderMessages, isFalse);
  });

  test('deletes the selected thread and clears its messages', () async {
    final deletedIds = <String>[];
    final thread = _thread(1);
    final repository = _FakeRepository(
      threadLoader: (_, __, ___) async =>
          AssetChatThreadPage(items: [thread], hasMore: false),
      messageLoader: (_, __, ___) async => AssetChatMessagePage(
        items: [_message(1)],
        hasMore: false,
      ),
      onDelete: (id) async => deletedIds.add(id),
    );
    final viewModel = AssetChatHistoryViewModel(repository: repository);
    addTearDown(viewModel.dispose);

    await viewModel.initialize();
    await viewModel.selectThread(thread);
    expect(await viewModel.deleteThread(thread), isTrue);

    expect(deletedIds, ['thread-1']);
    expect(viewModel.threads, isEmpty);
    expect(viewModel.selectedThread, isNull);
    expect(viewModel.messages, isEmpty);
  });

  test('maps an unauthenticated repository error to a safe login message',
      () async {
    final repository = _FakeRepository(
      threadLoader: (_, __, ___) async =>
          throw const AssetChatHistoryRepositoryException(
        'login_required',
        'jwt detail must not leak',
      ),
      messageLoader: (_, __, ___) async =>
          const AssetChatMessagePage(items: [], hasMore: false),
    );
    final viewModel = AssetChatHistoryViewModel(repository: repository);
    addTearDown(viewModel.dispose);

    await viewModel.initialize();

    expect(viewModel.errorMessage, contains('ログイン'));
    expect(viewModel.errorMessage, isNot(contains('jwt')));
  });
}
