import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/long_form_summary_models.dart';

/// 長文ドキュメントおよびバックグラウンド要約データアクセス抽象。
abstract class LongFormSummaryRepository {
  Future<List<LongFormDocumentWithSummary>> fetchDocuments();

  Future<LongFormDocumentWithSummary> saveDocument({
    required String title,
    required String bodyText,
  });

  Future<LongFormDocumentWithSummary?> fetchByDocumentId(String documentId);
}

/// 遅延 SupabaseClient 解決を用いるリポジトリ実装。
class SupabaseLongFormSummaryRepository implements LongFormSummaryRepository {
  const SupabaseLongFormSummaryRepository({
    SupabaseClient Function()? clientResolver,
  }) : _clientResolver = clientResolver;

  final SupabaseClient Function()? _clientResolver;

  @override
  Future<List<LongFormDocumentWithSummary>> fetchDocuments() async {
    final SupabaseClient? client = _tryResolveClient();
    final String? userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      throw StateError('Supabase client unavailable');
    }

    final List<Object?> docRows = await client
        .from('long_form_documents')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(20);

    final List<Object?> summaryRows =
        await client.from('long_form_summaries').select().eq('user_id', userId);

    final Map<String, Map<String, Object?>> summaryByDocId =
        <String, Map<String, Object?>>{};
    for (final Map<String, Object?> row
        in summaryRows.whereType<Map<String, Object?>>()) {
      final String docId = (row['document_id'] as String? ?? '').trim();
      if (docId.isNotEmpty) {
        summaryByDocId[docId] = row;
      }
    }

    return docRows
        .whereType<Map<String, Object?>>()
        .map((Map<String, Object?> docRow) {
      final String docId = (docRow['id'] as String? ?? '').trim();
      return LongFormDocumentWithSummary.fromDocumentAndSummaryJson(
        docJson: docRow,
        summaryJson: summaryByDocId[docId],
      );
    }).toList(growable: false);
  }

  @override
  Future<LongFormDocumentWithSummary> saveDocument({
    required String title,
    required String bodyText,
  }) async {
    final SupabaseClient? client = _tryResolveClient();
    final String? userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      throw StateError('Supabase client unavailable');
    }

    final Map<String, Object?> insertedDoc = await client
        .from('long_form_documents')
        .insert(<String, Object?>{
          'user_id': userId,
          'title': title.trim(),
          'body_text': bodyText.trim(),
        })
        .select()
        .single();

    final String docId = (insertedDoc['id'] as String? ?? '').trim();
    final Map<String, Object?>? summaryRow = await client
        .from('long_form_summaries')
        .select()
        .eq('document_id', docId)
        .maybeSingle();

    return LongFormDocumentWithSummary.fromDocumentAndSummaryJson(
      docJson: insertedDoc,
      summaryJson: summaryRow,
    );
  }

  @override
  Future<LongFormDocumentWithSummary?> fetchByDocumentId(
    String documentId,
  ) async {
    final SupabaseClient? client = _tryResolveClient();
    final String? userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      throw StateError('Supabase client unavailable');
    }

    final Map<String, Object?>? docRow = await client
        .from('long_form_documents')
        .select()
        .eq('id', documentId)
        .eq('user_id', userId)
        .maybeSingle();
    if (docRow == null) {
      return null;
    }

    final Map<String, Object?>? summaryRow = await client
        .from('long_form_summaries')
        .select()
        .eq('document_id', documentId)
        .maybeSingle();

    return LongFormDocumentWithSummary.fromDocumentAndSummaryJson(
      docJson: docRow,
      summaryJson: summaryRow,
    );
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
