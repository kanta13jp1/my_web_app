import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/external_ai_webhook_models.dart';

/// Supabase `external_ai_webhook_events` / `external_ai_webhook_keys` リポジトリ (#2663).
class SupabaseExternalAiWebhookRepository
    implements ExternalAiWebhookRepository {
  SupabaseExternalAiWebhookRepository({final SupabaseClient? client})
      : _client = client;

  final SupabaseClient? _client;
  RealtimeChannel? _channel;

  SupabaseClient get _resolvedClient => _client ?? Supabase.instance.client;

  String _requireUserId(final SupabaseClient client) {
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) {
      throw StateError('認証済みセッションが必要です。サインイン後に再試行してください。');
    }
    return userId;
  }

  Map<String, Object?> _normalizeRow(final Map<Object?, Object?> raw) {
    final map = <String, Object?>{};
    for (final entry in raw.entries) {
      if (entry.key != null) {
        map[entry.key.toString()] = entry.value;
      }
    }
    return map;
  }

  List<Map<String, Object?>> _extractRows(final Object rawResponse) {
    if (rawResponse is! List<Object?>) {
      return const <Map<String, Object?>>[];
    }
    final result = <Map<String, Object?>>[];
    for (final item in rawResponse) {
      if (item is Map<Object?, Object?>) {
        result.add(_normalizeRow(item));
      }
    }
    return result;
  }

  @override
  Future<List<ExternalAiWebhookEvent>> fetchRecentEvents({
    final int limit = 40,
  }) async {
    final client = _resolvedClient;
    _requireUserId(client);
    final Object response = await client
        .from('external_ai_webhook_events')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return _extractRows(response)
        .map(ExternalAiWebhookEvent.fromMap)
        .toList(growable: false);
  }

  @override
  Future<List<ExternalAiWebhookKey>> fetchWebhookKeys() async {
    final client = _resolvedClient;
    _requireUserId(client);
    final Object response = await client
        .from('external_ai_webhook_keys')
        .select(
          'id, user_id, label, key_prefix, is_active, last_used_at, created_at',
        )
        .order('created_at', ascending: false);
    return _extractRows(response)
        .map(ExternalAiWebhookKey.fromMap)
        .toList(growable: false);
  }

  @override
  Future<ExternalAiWebhookKey> createWebhookKey({
    required final String label,
    required final String keyPrefix,
    required final String keyHash,
  }) async {
    final client = _resolvedClient;
    final userId = _requireUserId(client);
    final Object inserted = await client
        .from('external_ai_webhook_keys')
        .insert(<String, Object?>{
          'user_id': userId,
          'label': label.trim(),
          'key_prefix': keyPrefix.trim(),
          'key_hash': keyHash.trim().toLowerCase(),
          'is_active': true,
        })
        .select(
          'id, user_id, label, key_prefix, is_active, last_used_at, created_at',
        )
        .single();
    if (inserted is! Map<Object?, Object?>) {
      throw StateError('Webhook APIキーの作成結果が不正です。');
    }
    return ExternalAiWebhookKey.fromMap(_normalizeRow(inserted));
  }

  @override
  Future<void> revokeWebhookKey(final String keyId) async {
    final client = _resolvedClient;
    _requireUserId(client);
    await client
        .from('external_ai_webhook_keys')
        .update(<String, Object?>{'is_active': false}).eq('id', keyId);
  }

  @override
  Future<ExternalWebhookInvokeResult> invokeWebhookEndpoint({
    required final ExternalWebhookSourceTool sourceTool,
    required final String eventType,
    required final Map<String, Object?> payload,
    required final bool dryRun,
  }) async {
    final client = _resolvedClient;
    _requireUserId(client);
    final response = await client.functions.invoke(
      'external-ai-webhook',
      body: <String, Object?>{
        'source_tool': sourceTool.wireValue,
        'event_type': eventType.trim(),
        'payload': payload,
        'processing_status': 'processed',
        'dry_run': dryRun,
      },
    );
    final data = response.data is Map<Object?, Object?>
        ? _normalizeRow(response.data as Map<Object?, Object?>)
        : const <String, Object?>{};
    return ExternalWebhookInvokeResult(
      ok: data['ok'] as bool? ?? false,
      dryRun: data['dry_run'] as bool? ?? dryRun,
      authMethod:
          ExternalWebhookAuthMethod.fromWire(data['auth_method'] as String?),
      eventId: data['id'] as String?,
    );
  }

  @override
  bool subscribeToEvents(final void Function() onRealtimeChange) {
    final existing = _channel;
    if (existing != null) {
      return true;
    }
    try {
      final client = _resolvedClient;
      _channel = client
          .channel('public:external_ai_webhook_events:feed')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'external_ai_webhook_events',
            callback: (final PostgresChangePayload _) => onRealtimeChange(),
          )
          .subscribe();
      return true;
    } catch (_) {
      _channel = null;
      return false;
    }
  }

  @override
  Future<void> disposeSubscription() async {
    final channel = _channel;
    _channel = null;
    if (channel == null) {
      return;
    }
    try {
      await _resolvedClient.removeChannel(channel);
    } catch (_) {
      // Realtime チャンネル解放時のエラーは画面遷移を阻害しない。
    }
  }
}
