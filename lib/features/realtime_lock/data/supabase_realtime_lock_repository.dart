import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/realtime_lock_models.dart';

class _SupabaseChannelHandle implements RealtimeLockSubscriptionHandle {
  _SupabaseChannelHandle({
    required this.client,
    required this.channel,
  });

  final SupabaseClient client;
  final RealtimeChannel channel;
  bool _disposed = false;

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    try {
      await channel.untrack();
    } catch (_) {
      // Presence untrack failures must not block screen disposal.
    }
    try {
      await client.removeChannel(channel);
    } catch (_) {
      // Channel teardown failures must not disrupt navigation.
    }
  }
}

/// `app-hub` + `Supabase Realtime` による排他制御・Presence・競合通知実装 (#2744)。
class SupabaseRealtimeLockRepository implements RealtimeLockRepository {
  SupabaseRealtimeLockRepository({
    SupabaseClient Function()? clientResolver,
  }) : _clientResolver = clientResolver ?? _defaultClient;

  final SupabaseClient Function() _clientResolver;
  final Map<String, RealtimeChannel> _activeChannels =
      <String, RealtimeChannel>{};

  static SupabaseClient _defaultClient() => Supabase.instance.client;

  Map<String, Object?> _asMap(Object? raw) {
    if (raw is Map<Object?, Object?>) {
      return Map<String, Object?>.from(raw);
    }
    return const <String, Object?>{};
  }

  Future<Map<String, Object?>> _invokeAppHub(
    Map<String, Object?> payload,
  ) async {
    final SupabaseClient client = _clientResolver();
    try {
      final FunctionResponse response = await client.functions.invoke(
        'app-hub',
        body: payload,
      );
      final Map<String, Object?> body = _asMap(response.data);
      final String errorText = (body['error'] as String? ?? '').trim();
      if (response.status >= 400 || errorText.isNotEmpty) {
        throw StateError(
          errorText.isNotEmpty
              ? errorText
              : 'Realtime lock request failed (${response.status})',
        );
      }
      return body;
    } on FunctionException catch (error) {
      final Map<String, Object?> details = _asMap(error.details);
      if (error.status == 409 || details['conflict'] == true) {
        rethrow;
      }
      final String detailError = (details['error'] as String? ?? '').trim();
      final String reason = (error.reasonPhrase ?? '').trim();
      throw StateError(
        detailError.isNotEmpty
            ? detailError
            : (reason.isNotEmpty
                ? reason
                : 'Realtime lock request failed (${error.status})'),
      );
    }
  }

  @override
  Future<List<LockedDocumentRecord>> loadDocuments() async {
    final Map<String, Object?> data = await _invokeAppHub(
      const <String, Object?>{'action': 'realtime_lock.list'},
    );
    final Object? rawRecords = data['records'];
    if (rawRecords is! List<Object?>) {
      return const <LockedDocumentRecord>[];
    }
    return rawRecords
        .whereType<Map<Object?, Object?>>()
        .map(
          (Map<Object?, Object?> item) =>
              LockedDocumentRecord.fromJson(Map<String, Object?>.from(item)),
        )
        .toList(growable: false);
  }

  @override
  Future<LockedDocumentRecord> createDocument({
    required String title,
    required String content,
    required String updatedBy,
  }) async {
    final Map<String, Object?> data = await _invokeAppHub(
      <String, Object?>{
        'action': 'realtime_lock.create',
        'title': title,
        'content': content,
        'updated_by': updatedBy,
      },
    );
    return LockedDocumentRecord.fromJson(_asMap(data['record']));
  }

  @override
  Future<SaveLockedRecordOutcome> saveWithOptimisticLock({
    required String recordId,
    required int expectedRevision,
    required String title,
    required String content,
    required String updatedBy,
    String expectedUpdatedAtIso = '',
  }) async {
    try {
      final Map<String, Object?> data = await _invokeAppHub(
        <String, Object?>{
          'action': 'realtime_lock.save',
          'record_id': recordId,
          'expected_revision': expectedRevision,
          if (expectedUpdatedAtIso.isNotEmpty)
            'expected_updated_at': expectedUpdatedAtIso,
          'title': title,
          'content': content,
          'updated_by': updatedBy,
        },
      );
      final LockedDocumentRecord saved = LockedDocumentRecord.fromJson(
        _asMap(data['record']),
      );
      await _broadcastRevision(saved);
      return SaveLockedRecordOutcome(
        saved: true,
        conflict: false,
        record: saved,
        expectedRevision: expectedRevision,
        currentRevision: saved.revision,
        message: 'リビジョン r${saved.revision} として保存しました',
      );
    } on FunctionException catch (error) {
      final Map<String, Object?> details = _asMap(error.details);
      final Map<String, Object?> serverMap = _asMap(details['server_record']);
      final LockedDocumentRecord? serverRecord = serverMap.isNotEmpty
          ? LockedDocumentRecord.fromJson(serverMap)
          : null;
      return SaveLockedRecordOutcome(
        saved: false,
        conflict: true,
        expectedRevision: expectedRevision,
        currentRevision: (details['current_revision'] as num?)?.toInt() ??
            serverRecord?.revision,
        serverRecord: serverRecord,
        message: '他セッションまたはバッチによる先行更新のため保存をブロックしました (HTTP 409)',
      );
    }
  }

  @override
  Future<LockedDocumentRecord> triggerBatchUpdate({
    required String recordId,
    String actor = 'batch-job',
  }) async {
    final Map<String, Object?> data = await _invokeAppHub(
      <String, Object?>{
        'action': 'realtime_lock.simulate_batch_update',
        'record_id': recordId,
        'actor': actor,
      },
    );
    final LockedDocumentRecord updated = LockedDocumentRecord.fromJson(
      _asMap(data['record']),
    );
    await _broadcastRevision(updated);
    return updated;
  }

  Future<void> _broadcastRevision(LockedDocumentRecord record) async {
    final RealtimeChannel? channel = _activeChannels[record.id];
    if (channel == null) {
      return;
    }
    try {
      await channel.sendBroadcastMessage(
        event: 'revision_updated',
        payload: <String, Object?>{
          'record_id': record.id,
          'new_revision': record.revision,
          'updated_by': record.updatedBy,
          'updated_at': record.updatedAtIso,
          'source_actor': record.sourceActor,
          'server_record': <String, Object?>{
            'id': record.id,
            'title': record.title,
            'content': record.content,
            'revision': record.revision,
            'updated_by': record.updatedBy,
            'updated_at': record.updatedAtIso,
            'source_actor': record.sourceActor,
          },
        },
      );
    } catch (_) {
      // Broadcast errors never invalidate persisted optimistic lock state.
    }
  }

  @override
  RealtimeLockSubscriptionHandle subscribeToDocument({
    required String recordId,
    required String sessionId,
    required String displayName,
    required void Function(List<PresenceEditor> editors) onPresenceChanged,
    required void Function(RevisionAlertEvent event) onRevisionChanged,
  }) {
    final SupabaseClient client = _clientResolver();
    final String selfUserId = client.auth.currentUser?.id ?? 'anonymous';
    final RealtimeChannel channel = client.channel('realtime_lock:$recordId');
    _activeChannels[recordId] = channel;

    channel
        .onPresenceSync((final RealtimePresenceSyncPayload _) {
          final List<SinglePresenceState> states = channel.presenceState();
          final List<PresenceEditor> editors = <PresenceEditor>[];
          for (final SinglePresenceState group in states) {
            for (final Presence entry in group.presences) {
              final Map<String, Object?> meta = Map<String, Object?>.from(
                entry.payload,
              );
              final String sid =
                  (meta['session_id'] as String? ?? entry.presenceRef).trim();
              editors.add(
                PresenceEditor(
                  sessionId: sid,
                  userId: (meta['user_id'] as String? ?? group.key).trim(),
                  displayName:
                      (meta['display_name'] as String? ?? '編集ユーザー').trim(),
                  joinedAtIso: (meta['joined_at'] as String? ?? '').trim(),
                  isSelf: sid == sessionId,
                ),
              );
            }
          }
          onPresenceChanged(editors);
        })
        .onBroadcast(
          event: 'revision_updated',
          callback: (final Map<Object?, Object?> raw) {
            final Map<String, Object?> data = Map<String, Object?>.from(raw);
            final Map<String, Object?> serverMap = _asMap(
              data['server_record'],
            );
            onRevisionChanged(
              RevisionAlertEvent(
                recordId: (data['record_id'] as String? ?? recordId).trim(),
                newRevision: (data['new_revision'] as num?)?.toInt() ?? 1,
                updatedBy: (data['updated_by'] as String? ?? 'other').trim(),
                updatedAtIso: (data['updated_at'] as String? ?? '').trim(),
                sourceActor: (data['source_actor'] as String? ?? 'user').trim(),
                serverRecord: serverMap.isNotEmpty
                    ? LockedDocumentRecord.fromJson(serverMap)
                    : null,
              ),
            );
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'hub_data',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: recordId,
          ),
          callback: (final PostgresChangePayload payload) {
            final Map<String, Object?> newRow = _asMap(payload.newRecord);
            if (newRow.isEmpty) {
              return;
            }
            final LockedDocumentRecord server = LockedDocumentRecord.fromJson(
              newRow,
            );
            onRevisionChanged(
              RevisionAlertEvent(
                recordId: server.id.isEmpty ? recordId : server.id,
                newRevision: server.revision,
                updatedBy: server.updatedBy,
                updatedAtIso: server.updatedAtIso,
                sourceActor: server.sourceActor,
                serverRecord: server,
              ),
            );
          },
        )
        .subscribe((final RealtimeSubscribeStatus status, final Object? _) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            channel.track(<String, Object?>{
              'session_id': sessionId,
              'user_id': selfUserId,
              'display_name': displayName,
              'joined_at': DateTime.now().toUtc().toIso8601String(),
            });
          }
        });

    return _SupabaseChannelHandle(client: client, channel: channel);
  }
}
