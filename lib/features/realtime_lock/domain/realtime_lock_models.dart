import 'package:flutter/foundation.dart';

/// Supabase Realtime Presence 上で同一レコードを編集中のユーザー状態。
@immutable
class PresenceEditor {
  const PresenceEditor({
    required this.sessionId,
    required this.userId,
    required this.displayName,
    required this.joinedAtIso,
    required this.isSelf,
  });

  final String sessionId;
  final String userId;
  final String displayName;
  final String joinedAtIso;
  final bool isSelf;
}

/// 編集中レコードに対する他ユーザーまたはバッチ処理の更新通知。
@immutable
class RevisionAlertEvent {
  const RevisionAlertEvent({
    required this.recordId,
    required this.newRevision,
    required this.updatedBy,
    required this.updatedAtIso,
    required this.sourceActor,
    this.serverRecord,
  });

  final String recordId;
  final int newRevision;
  final String updatedBy;
  final String updatedAtIso;
  final String sourceActor;
  final LockedDocumentRecord? serverRecord;
}

/// 楽観的ロック付き共有ドキュメントレコード (`hub_data` JSONB 永続化)。
@immutable
class LockedDocumentRecord {
  const LockedDocumentRecord({
    required this.id,
    required this.title,
    required this.content,
    required this.revision,
    required this.updatedBy,
    required this.updatedAtIso,
    required this.sourceActor,
  });

  factory LockedDocumentRecord.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> rawMeta = json['metadata']
            is Map<Object?, Object?>
        ? Map<String, Object?>.from(json['metadata'] as Map<Object?, Object?>)
        : const <String, Object?>{};
    final Map<String, Object?> effective = rawMeta.isNotEmpty ? rawMeta : json;
    final int rev = (effective['revision'] as num?)?.toInt() ?? 1;

    return LockedDocumentRecord(
      id: (json['id'] as String? ?? effective['id'] as String? ?? '').trim(),
      title: (effective['title'] as String? ?? '').trim(),
      content: effective['content'] as String? ?? '',
      revision: rev >= 1 ? rev : 1,
      updatedBy: (effective['updated_by'] as String? ?? 'user').trim(),
      updatedAtIso: (effective['updated_at'] as String? ??
              json['created_at'] as String? ??
              '')
          .trim(),
      sourceActor: (effective['source_actor'] as String? ?? 'user').trim(),
    );
  }

  final String id;
  final String title;
  final String content;
  final int revision;
  final String updatedBy;
  final String updatedAtIso;
  final String sourceActor;
}

/// 楽観的ロック保存リクエストの結果（成功または HTTP 409 競合ブロック）。
@immutable
class SaveLockedRecordOutcome {
  const SaveLockedRecordOutcome({
    required this.saved,
    required this.conflict,
    this.record,
    this.expectedRevision,
    this.currentRevision,
    this.serverRecord,
    this.message = '',
  });

  final bool saved;
  final bool conflict;
  final LockedDocumentRecord? record;
  final int? expectedRevision;
  final int? currentRevision;
  final LockedDocumentRecord? serverRecord;
  final String message;
}

/// Realtime チャネル購読・Presence 追跡の解放ハンドル。
abstract class RealtimeLockSubscriptionHandle {
  Future<void> dispose();
}

/// Realtime Presence・変更通知・楽観的ロック永続化のリポジトリ境界。
abstract class RealtimeLockRepository {
  Future<List<LockedDocumentRecord>> loadDocuments();

  Future<LockedDocumentRecord> createDocument({
    required String title,
    required String content,
    required String updatedBy,
  });

  Future<SaveLockedRecordOutcome> saveWithOptimisticLock({
    required String recordId,
    required int expectedRevision,
    required String title,
    required String content,
    required String updatedBy,
    String expectedUpdatedAtIso = '',
  });

  Future<LockedDocumentRecord> triggerBatchUpdate({
    required String recordId,
    String actor = 'batch-job',
  });

  RealtimeLockSubscriptionHandle subscribeToDocument({
    required String recordId,
    required String sessionId,
    required String displayName,
    required void Function(List<PresenceEditor> editors) onPresenceChanged,
    required void Function(RevisionAlertEvent event) onRevisionChanged,
  });
}
