import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/rls_ai_search_models.dart';

/// Supabase `rls_ai_documents` / `rls_ai_document_acls` と
/// `search_rls_authorized_ai_documents` RPC を利用するリポジトリ実装。
class SupabaseRlsAiSearchRepository implements RlsAiSearchRepository {
  SupabaseRlsAiSearchRepository({
    SupabaseClient Function()? clientResolver,
    DateTime Function()? nowProvider,
  })  : _clientResolver = clientResolver,
        _nowProvider = nowProvider ?? DateTime.now;

  final SupabaseClient Function()? _clientResolver;
  final DateTime Function() _nowProvider;

  final List<_SampleDoc> _sampleDocs = <_SampleDoc>[
    const _SampleDoc(
      id: 'doc-roadmap',
      externalSourceKey: 'drive://roadmap-2026',
      title: '製品ロードマップ 2026',
      contentExcerpt: 'RLS連動検索と外部権限即時同期のマイルストーン',
      aclVersion: 1,
      permission: RlsAccessLevel.owner,
      authorizedToCaller: true,
    ),
    const _SampleDoc(
      id: 'doc-finance',
      externalSourceKey: 'notion://q4-budget-plan',
      title: 'Q4 予算配分計画',
      contentExcerpt: '部門別のAI投資枠と安全上限ガイドライン',
      aclVersion: 2,
      permission: RlsAccessLevel.viewer,
      authorizedToCaller: true,
    ),
    const _SampleDoc(
      id: 'doc-secret',
      externalSourceKey: 'drive://executive-private',
      title: '非公開役員会議事録',
      contentExcerpt: '権限外の非公開情報',
      aclVersion: 4,
      permission: RlsAccessLevel.revoked,
      authorizedToCaller: false,
    ),
  ];

  final List<RlsDocumentAclEntry> _sampleAcls = <RlsDocumentAclEntry>[
    const RlsDocumentAclEntry(
      id: 'acl-finance-1',
      documentId: 'doc-finance',
      externalSourceKey: 'notion://q4-budget-plan',
      documentTitle: 'Q4 予算配分計画',
      granteeLabel: 'current-user',
      permissionLevel: RlsAccessLevel.viewer,
      isActive: true,
      ownerUserId: 'sample-owner',
      canManage: true,
      aclVersion: 2,
    ),
    const RlsDocumentAclEntry(
      id: 'acl-secret-2',
      documentId: 'doc-secret',
      externalSourceKey: 'drive://executive-private',
      documentTitle: '非公開役員会議事録',
      granteeLabel: 'former-collaborator',
      permissionLevel: RlsAccessLevel.revoked,
      isActive: false,
      ownerUserId: 'other-owner',
      canManage: false,
      aclVersion: 4,
      revokedAtIso: '2026-11-24T08:00:00Z',
    ),
  ];

  @override
  Future<RlsAiSearchResult> searchAuthorizedDocuments({
    required String query,
    int limit = 10,
  }) async {
    final String cleanQuery = query.trim();
    final SupabaseClient? client = _tryResolveClient();
    final String? userId = client?.auth.currentUser?.id;

    if (client == null || userId == null) {
      return _searchSampleCorpus(cleanQuery, limit);
    }

    final Object rawRpc = (await client.rpc(
          'search_rls_authorized_ai_documents',
          params: <String, Object?>{
            'p_query': cleanQuery,
            'p_limit': limit,
          },
        )) ??
        const <Object?>[];
    final List<Object?> rpcRows =
        rawRpc is List<Object?> ? rawRpc : const <Object?>[];

    final List<RlsAiDocumentHit> hits = rpcRows
        .whereType<Map<String, Object?>>()
        .map(RlsAiDocumentHit.fromJson)
        .toList(growable: false);

    final List<Object?> aclRows = await client
        .from('rls_ai_document_acls')
        .select(
          'id,document_id,grantee_user_id,permission_level,granted_by_user_id,revoked_at,created_at,updated_at,rls_ai_documents(owner_user_id,external_source_key,title,acl_version)',
        )
        .order('updated_at', ascending: false)
        .limit(20);

    final List<RlsDocumentAclEntry> acls = aclRows
        .whereType<Map<String, Object?>>()
        .map(
          (Map<String, Object?> row) =>
              RlsDocumentAclEntry.fromJson(row, currentUserId: userId),
        )
        .toList(growable: false);

    final int revokedCount =
        acls.where((RlsDocumentAclEntry entry) => !entry.isActive).length;
    final String prompt = _buildPromptPreview(cleanQuery, hits);

    return RlsAiSearchResult(
      hits: hits,
      aclEntries: acls,
      excludedUnauthorizedCount: revokedCount,
      promptContextPreview: prompt,
    );
  }

  @override
  Future<RlsDocumentAclEntry> setAclAccess({
    required RlsDocumentAclEntry entry,
    required bool grantAccess,
    RlsAccessLevel level = RlsAccessLevel.viewer,
  }) async {
    if (!entry.canManage) {
      throw StateError('Only document owners may manage document ACLs');
    }
    final String nowIso = _nowProvider().toUtc().toIso8601String();
    final SupabaseClient? client = _tryResolveClient();
    final String? userId = client?.auth.currentUser?.id;

    if (client == null || userId == null) {
      final int idx = _sampleAcls.indexWhere(
        (RlsDocumentAclEntry e) => e.id == entry.id,
      );
      final int nextVersion = entry.aclVersion + 1;
      final RlsDocumentAclEntry updated = entry.copyWith(
        permissionLevel: grantAccess ? level : RlsAccessLevel.revoked,
        isActive: grantAccess,
        aclVersion: nextVersion,
        revokedAtIso: grantAccess ? null : nowIso,
      );
      if (idx >= 0) {
        _sampleAcls[idx] = updated;
      }
      final int docIdx = _sampleDocs.indexWhere(
        (_SampleDoc d) => d.id == entry.documentId,
      );
      if (docIdx >= 0) {
        final _SampleDoc prev = _sampleDocs[docIdx];
        _sampleDocs[docIdx] = _SampleDoc(
          id: prev.id,
          externalSourceKey: prev.externalSourceKey,
          title: prev.title,
          contentExcerpt: prev.contentExcerpt,
          aclVersion: nextVersion,
          permission: grantAccess ? level : RlsAccessLevel.revoked,
          authorizedToCaller: grantAccess,
        );
      }
      return updated;
    }

    final Map<String, Object?> saved = await client
        .from('rls_ai_document_acls')
        .update(<String, Object?>{
          'permission_level': grantAccess ? level.dbValue : 'viewer',
          'revoked_at': grantAccess ? null : nowIso,
        })
        .eq('id', entry.id)
        .select(
          'id,document_id,grantee_user_id,permission_level,granted_by_user_id,revoked_at,created_at,updated_at,rls_ai_documents(owner_user_id,external_source_key,title,acl_version)',
        )
        .single();

    return RlsDocumentAclEntry.fromJson(saved, currentUserId: userId);
  }

  RlsAiSearchResult _searchSampleCorpus(String cleanQuery, int limit) {
    final String lower = cleanQuery.toLowerCase();
    int excluded = 0;
    final List<RlsAiDocumentHit> hits = <RlsAiDocumentHit>[];

    for (final _SampleDoc doc in _sampleDocs) {
      if (!doc.authorizedToCaller) {
        excluded += 1;
        continue;
      }
      final String haystack =
          '${doc.title} ${doc.contentExcerpt} ${doc.externalSourceKey}'
              .toLowerCase();
      if (lower.isNotEmpty && !haystack.contains(lower)) {
        continue;
      }
      hits.add(
        RlsAiDocumentHit(
          documentId: doc.id,
          externalSourceKey: doc.externalSourceKey,
          title: doc.title,
          contentExcerpt: doc.contentExcerpt,
          aclVersion: doc.aclVersion,
          permissionSource: doc.permission,
          similarityScore: lower.isEmpty ? 0.85 : 0.94,
          updatedAtIso: '2026-11-24T08:00:00Z',
        ),
      );
      if (hits.length >= limit) {
        break;
      }
    }

    return RlsAiSearchResult(
      hits: List<RlsAiDocumentHit>.unmodifiable(hits),
      aclEntries: List<RlsDocumentAclEntry>.unmodifiable(_sampleAcls),
      excludedUnauthorizedCount: excluded,
      promptContextPreview: _buildPromptPreview(cleanQuery, hits),
    );
  }

  String _buildPromptPreview(String query, List<RlsAiDocumentHit> hits) {
    if (hits.isEmpty) {
      return 'クエリ "${query.isEmpty ? '全件' : query}" に一致する認可済みコンテキストはありません。';
    }
    final StringBuffer buffer = StringBuffer();
    for (final RlsAiDocumentHit hit in hits) {
      buffer.writeln(
        '[${hit.externalSourceKey} | ACL v${hit.aclVersion} | ${hit.permissionSource.labelJa}] '
        '${hit.title}: ${hit.contentExcerpt}',
      );
    }
    return buffer.toString().trim();
  }

  SupabaseClient? _tryResolveClient() {
    final SupabaseClient Function()? resolver = _clientResolver;
    if (resolver != null) {
      return resolver();
    }
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}

class _SampleDoc {
  const _SampleDoc({
    required this.id,
    required this.externalSourceKey,
    required this.title,
    required this.contentExcerpt,
    required this.aclVersion,
    required this.permission,
    required this.authorizedToCaller,
  });

  final String id;
  final String externalSourceKey;
  final String title;
  final String contentExcerpt;
  final int aclVersion;
  final RlsAccessLevel permission;
  final bool authorizedToCaller;
}
