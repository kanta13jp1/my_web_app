import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/asset_management_ai_analysis_history.dart';
import 'asset_management_ai_summary_service.dart';
import 'asset_management_insight_service.dart';

class AssetManagementAiAnalysisHistoryService {
  static const String tableName = 'asset_management_ai_analysis_history';

  final SupabaseClient? _client;
  final String? Function()? _userIdProvider;

  const AssetManagementAiAnalysisHistoryService({
    SupabaseClient? client,
    String? Function()? userIdProvider,
  })  : _client = client,
        _userIdProvider = userIdProvider;

  Future<List<AssetManagementAiAnalysisHistoryEntry>> loadRecent({
    int limit = 5,
  }) async {
    final client = _resolveClient();
    final userId = _resolveUserId(client);
    if (client == null || userId == null) {
      return const <AssetManagementAiAnalysisHistoryEntry>[];
    }

    final rawRows = await client
        .from(tableName)
        .select(
          'id, request_fingerprint, summary_text, status, source, '
          'generated_at, created_at, report_base_date, provider_choice_reason, '
          'provider_route, input_payload',
        )
        .eq('user_id', userId)
        .eq('status', AssetManagementAiSummaryStatus.aiGenerated.name)
        .order('generated_at', ascending: false)
        .limit(limit);

    return rawRows
        .map(_rowToMap)
        .where((row) => row.isNotEmpty)
        .map(AssetManagementAiAnalysisHistoryEntry.fromJson)
        .where((entry) => entry.summaryText.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<void> saveResult({
    required AssetManagementAiSummaryResult result,
    required AssetManagementInsightReport report,
    required String requestFingerprint,
  }) async {
    if (!result.usedExternalAi || result.text.trim().isEmpty) {
      return;
    }

    final client = _resolveClient();
    final userId = _resolveUserId(client);
    if (client == null || userId == null) {
      return;
    }

    await client.from(tableName).insert(<String, dynamic>{
      'user_id': userId,
      'request_fingerprint': _safeRequestFingerprint(requestFingerprint),
      'report_base_date': _dateOnly(report.workbook.baseDate),
      'status': result.status.name,
      'source': result.source,
      'summary_text': result.text.trim(),
      'provider_route': result.providerRoute ?? const <String, dynamic>{},
      'provider_choice_reason': result.providerChoiceReason,
      'input_payload': result.payload,
      'generated_at': result.generatedAt.toUtc().toIso8601String(),
    });
  }

  String _safeRequestFingerprint(String value) {
    final trimmed = value.trim();
    if (_isSha256Fingerprint(trimmed)) {
      return trimmed;
    }
    return 'sha256:${sha256.convert(utf8.encode(trimmed))}';
  }

  bool _isSha256Fingerprint(String value) {
    if (value.length != 71 || !value.startsWith('sha256:')) {
      return false;
    }
    final hex = value.substring(7);
    return RegExp(r'^[0-9a-f]{64}$').hasMatch(hex);
  }

  SupabaseClient? _resolveClient() {
    if (_client != null) {
      return _client;
    }
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String? _resolveUserId(SupabaseClient? client) {
    final provided = _userIdProvider?.call()?.trim();
    if (provided != null && provided.isNotEmpty) {
      return provided;
    }
    return client?.auth.currentUser?.id;
  }

  Map<String, dynamic> _rowToMap(Object? row) {
    if (row is Map<String, dynamic>) {
      return row;
    }
    if (row is Map) {
      return row.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
