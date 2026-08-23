import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/asset_chat.dart';

abstract class AssetChatHistoryRepository {
  const AssetChatHistoryRepository();

  Future<AssetChatThreadPage> fetchThreads({
    String searchQuery = '',
    int offset = 0,
    int limit = 50,
  });

  Future<AssetChatMessagePage> fetchMessages({
    required String threadId,
    int offset = 0,
    int limit = 100,
  });

  Future<void> deleteThread(String threadId);
}

class AssetChatHistoryRepositoryException implements Exception {
  final String code;
  final String message;

  const AssetChatHistoryRepositoryException(this.code, this.message);

  @override
  String toString() => message;
}

class SupabaseAssetChatHistoryRepository implements AssetChatHistoryRepository {
  SupabaseAssetChatHistoryRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static const String threadTable = 'asset_chat_threads';
  static const String messageTable = 'asset_chat_messages';
  static const String threadColumns = 'id,title,created_at,last_message_at';
  static const String messageColumns =
      'id,thread_id,role,content,tokens_in,tokens_out,model,created_at';

  final SupabaseClient _client;

  @override
  Future<AssetChatThreadPage> fetchThreads({
    String searchQuery = '',
    int offset = 0,
    int limit = 50,
  }) async {
    final userId = _requiredUserId();
    final safeOffset = offset < 0 ? 0 : offset;
    final safeLimit = limit.clamp(1, 100);
    var request =
        _client.from(threadTable).select(threadColumns).eq('user_id', userId);
    final normalizedSearch = searchQuery.trim();
    if (normalizedSearch.isNotEmpty) {
      request = request.ilike('title', '%${_escapeLike(normalizedSearch)}%');
    }
    try {
      final rows = await request
          .order('last_message_at', ascending: false)
          .order('id', ascending: true)
          .range(safeOffset, safeOffset + safeLimit);
      final pageRows = _rows(rows);
      return AssetChatThreadPage(
        items: List<AssetChatThreadSummary>.unmodifiable(
          pageRows.take(safeLimit).map(AssetChatThreadSummary.fromMap),
        ),
        hasMore: pageRows.length > safeLimit,
      );
    } on PostgrestException catch (error) {
      throw AssetChatHistoryRepositoryException(
        'thread_read_failed',
        error.message,
      );
    }
  }

  @override
  Future<AssetChatMessagePage> fetchMessages({
    required String threadId,
    int offset = 0,
    int limit = 100,
  }) async {
    _requiredUserId();
    final normalizedThreadId = _requiredId(threadId, 'threadId');
    final safeOffset = offset < 0 ? 0 : offset;
    final safeLimit = limit.clamp(1, 200);
    try {
      final rows = await _client
          .from(messageTable)
          .select(messageColumns)
          .eq('thread_id', normalizedThreadId)
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .range(safeOffset, safeOffset + safeLimit);
      final pageRows = _rows(rows);
      return AssetChatMessagePage(
        items: List<AssetChatStoredMessage>.unmodifiable(
          pageRows.take(safeLimit).map(AssetChatStoredMessage.fromMap),
        ),
        hasMore: pageRows.length > safeLimit,
      );
    } on PostgrestException catch (error) {
      throw AssetChatHistoryRepositoryException(
        'message_read_failed',
        error.message,
      );
    }
  }

  @override
  Future<void> deleteThread(String threadId) async {
    final userId = _requiredUserId();
    final normalizedThreadId = _requiredId(threadId, 'threadId');
    try {
      final rows = await _client
          .from(threadTable)
          .delete()
          .eq('id', normalizedThreadId)
          .eq('user_id', userId)
          .select('id');
      if (_rows(rows).isEmpty) {
        throw const AssetChatHistoryRepositoryException(
          'thread_not_found',
          'Asset chat thread not found',
        );
      }
    } on PostgrestException catch (error) {
      throw AssetChatHistoryRepositoryException(
        'thread_delete_failed',
        error.message,
      );
    }
  }

  String _requiredUserId() {
    final userId = _client.auth.currentUser?.id.trim() ?? '';
    if (userId.isEmpty) {
      throw const AssetChatHistoryRepositoryException(
        'login_required',
        'Authenticated user required',
      );
    }
    return userId;
  }
}

List<Map<String, dynamic>> _rows(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((row) => row.cast<String, dynamic>())
      .toList(growable: false);
}

String _requiredId(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be empty');
  }
  return normalized;
}

String _escapeLike(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
