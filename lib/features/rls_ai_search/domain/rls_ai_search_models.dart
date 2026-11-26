import 'package:flutter/foundation.dart';

/// 外部連携ドキュメントへのアクセス権限区分。
enum RlsAccessLevel {
  owner('owner', '所有者'),
  editor('editor', '編集者'),
  viewer('viewer', '閲覧者'),
  revoked('revoked', '剥奪済み');

  const RlsAccessLevel(this.dbValue, this.labelJa);

  final String dbValue;
  final String labelJa;

  static RlsAccessLevel fromDb(String? raw) {
    final String normalized = (raw ?? '').trim().toLowerCase();
    for (final RlsAccessLevel value in RlsAccessLevel.values) {
      if (value.dbValue == normalized) {
        return value;
      }
    }
    return RlsAccessLevel.viewer;
  }
}

/// RLS フィルタリングを通過した AI 検索コンテキスト結果。
@immutable
class RlsAiDocumentHit {
  const RlsAiDocumentHit({
    required this.documentId,
    required this.externalSourceKey,
    required this.title,
    required this.contentExcerpt,
    required this.aclVersion,
    required this.permissionSource,
    required this.similarityScore,
    this.updatedAtIso = '',
  });

  final String documentId;
  final String externalSourceKey;
  final String title;
  final String contentExcerpt;
  final int aclVersion;
  final RlsAccessLevel permissionSource;
  final double similarityScore;
  final String updatedAtIso;

  factory RlsAiDocumentHit.fromJson(Map<String, Object?> json) {
    return RlsAiDocumentHit(
      documentId:
          (json['document_id'] as String? ?? json['id'] as String? ?? '')
              .trim(),
      externalSourceKey: (json['external_source_key'] as String? ?? '').trim(),
      title: (json['title'] as String? ?? '').trim(),
      contentExcerpt: (json['content_excerpt'] as String? ?? '').trim(),
      aclVersion: (json['acl_version'] as num?)?.toInt() ?? 1,
      permissionSource:
          RlsAccessLevel.fromDb(json['permission_source'] as String?),
      similarityScore: (json['similarity_score'] as num?)?.toDouble() ?? 0.0,
      updatedAtIso: (json['updated_at'] as String? ?? '').trim(),
    );
  }
}

/// 外部ソースドキュメントのライブ ACL エントリ（有効／剥奪状態）。
@immutable
class RlsDocumentAclEntry {
  const RlsDocumentAclEntry({
    required this.id,
    required this.documentId,
    required this.externalSourceKey,
    required this.documentTitle,
    required this.granteeLabel,
    required this.permissionLevel,
    required this.isActive,
    this.ownerUserId = '',
    this.canManage = false,
    this.aclVersion = 1,
    this.revokedAtIso,
  });

  final String id;
  final String documentId;
  final String externalSourceKey;
  final String documentTitle;
  final String granteeLabel;
  final RlsAccessLevel permissionLevel;
  final bool isActive;
  final String ownerUserId;
  final bool canManage;
  final int aclVersion;
  final String? revokedAtIso;

  RlsDocumentAclEntry copyWith({
    RlsAccessLevel? permissionLevel,
    bool? isActive,
    bool? canManage,
    int? aclVersion,
    String? revokedAtIso,
  }) {
    return RlsDocumentAclEntry(
      id: id,
      documentId: documentId,
      externalSourceKey: externalSourceKey,
      documentTitle: documentTitle,
      granteeLabel: granteeLabel,
      permissionLevel: permissionLevel ?? this.permissionLevel,
      isActive: isActive ?? this.isActive,
      ownerUserId: ownerUserId,
      canManage: canManage ?? this.canManage,
      aclVersion: aclVersion ?? this.aclVersion,
      revokedAtIso:
          isActive == true ? null : (revokedAtIso ?? this.revokedAtIso),
    );
  }

  factory RlsDocumentAclEntry.fromJson(
    Map<String, Object?> json, {
    String? currentUserId,
  }) {
    final String? revoked = (json['revoked_at'] as String?)?.trim();
    final bool active = revoked == null || revoked.isEmpty;
    final Object? rawDoc = json['rls_ai_documents'];
    final Map<String, Object?> joinedDoc =
        rawDoc is Map<String, Object?> ? rawDoc : const <String, Object?>{};
    final String ownerId = (joinedDoc['owner_user_id'] as String? ??
            json['owner_user_id'] as String? ??
            '')
        .trim();
    final String sourceKey = (joinedDoc['external_source_key'] as String? ??
            json['external_source_key'] as String? ??
            '')
        .trim();
    final String docTitle = (joinedDoc['title'] as String? ??
            json['document_title'] as String? ??
            '外部連携ドキュメント')
        .trim();
    final int version = (joinedDoc['acl_version'] as num?)?.toInt() ??
        (json['acl_version'] as num?)?.toInt() ??
        1;
    final bool ownerManage = currentUserId != null &&
        ownerId.isNotEmpty &&
        ownerId == currentUserId.trim();

    return RlsDocumentAclEntry(
      id: (json['id'] as String? ?? '').trim(),
      documentId: (json['document_id'] as String? ?? '').trim(),
      externalSourceKey: sourceKey,
      documentTitle: docTitle,
      granteeLabel: (json['grantee_user_id'] as String? ?? '').trim(),
      permissionLevel: active
          ? RlsAccessLevel.fromDb(json['permission_level'] as String?)
          : RlsAccessLevel.revoked,
      isActive: active,
      ownerUserId: ownerId,
      canManage: (json['can_manage'] as bool?) ?? ownerManage,
      aclVersion: version,
      revokedAtIso: revoked,
    );
  }
}

/// 検索ヒット・除外件数・サニタイズ済みプロンプトコンテキストの一式。
@immutable
class RlsAiSearchResult {
  const RlsAiSearchResult({
    required this.hits,
    required this.aclEntries,
    required this.excludedUnauthorizedCount,
    required this.promptContextPreview,
  });

  final List<RlsAiDocumentHit> hits;
  final List<RlsDocumentAclEntry> aclEntries;
  final int excludedUnauthorizedCount;
  final String promptContextPreview;
}

/// RLS 連動 AI 検索および ACL 即時同期のリポジトリ契約。
abstract class RlsAiSearchRepository {
  Future<RlsAiSearchResult> searchAuthorizedDocuments({
    required String query,
    int limit = 10,
  });

  Future<RlsDocumentAclEntry> setAclAccess({
    required RlsDocumentAclEntry entry,
    required bool grantAccess,
    RlsAccessLevel level = RlsAccessLevel.viewer,
  });
}
