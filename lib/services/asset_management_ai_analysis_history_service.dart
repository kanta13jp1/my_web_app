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

    // プロンプト文脈で実際に使うのは metrics_snapshot 相当の数値だけなので、
    // 巨大な input_payload 全体と summary_text 本文は取得しない
    // (5行で ~158KB → 数KB)。本文の存在は summary_text <> '' の
    // server-side filter で保証する。
    final rawRows = await client
        .from(tableName)
        .select(
          'id, request_fingerprint, status, source, '
          'generated_at, created_at, report_base_date, provider_choice_reason, '
          'provider_route, '
          'payload_totals:input_payload->workbook->totals, '
          'payload_available_money:input_payload->available_money',
        )
        .eq('user_id', userId)
        .eq('status', AssetManagementAiSummaryStatus.aiGenerated.name)
        .neq('summary_text', '')
        .order('generated_at', ascending: false)
        .limit(limit);

    return rawRows
        .map(_rowToMap)
        .where((row) => row.isNotEmpty)
        .map(_narrowRowToEntryJson)
        .map(AssetManagementAiAnalysisHistoryEntry.fromJson)
        .toList(growable: false);
  }

  /// 指定基準日の保存済み分析のうち最新の 1 件を返す (本文込み)。
  ///
  /// フィンガープリントは基準日を含む日付単位で回転するため、指紋一致の
  /// 再利用判定はこの「同日最新 1 行」を見れば足りる。加えて呼び出し側は
  /// generated_at の鮮度 (自動再生成クールダウン) 判定にも同じ行を使える —
  /// 引落済み等の編集毎に指紋が変わり、完全一致だけでは 1 セッションに
  /// 何度も 1 分超のプレミアム生成が走ってしまうため。
  Future<AssetManagementAiAnalysisHistoryEntry?> loadLatestForBaseDate({
    required String reportBaseDate,
  }) async {
    final client = _resolveClient();
    final userId = _resolveUserId(client);
    if (client == null || userId == null) {
      return null;
    }

    final rawRows = await client
        .from(tableName)
        .select(
          'id, request_fingerprint, summary_text, status, source, '
          'generated_at, created_at, report_base_date, provider_choice_reason, '
          'provider_route',
        )
        .eq('user_id', userId)
        .eq('status', AssetManagementAiSummaryStatus.aiGenerated.name)
        .eq('report_base_date', reportBaseDate)
        .neq('summary_text', '')
        .order('generated_at', ascending: false)
        .limit(1);

    final entries = rawRows
        .map(_rowToMap)
        .where((row) => row.isNotEmpty)
        .map(AssetManagementAiAnalysisHistoryEntry.fromJson)
        .where((entry) => entry.summaryText.trim().isNotEmpty)
        .toList(growable: false);
    return entries.isEmpty ? null : entries.first;
  }

  /// 縮小 projection の行を、モデルが期待する input_payload 形へ組み直す。
  /// summary_text キーは意図的に持たせない (= summaryTextOmitted として扱う)。
  Map<String, dynamic> _narrowRowToEntryJson(Map<String, dynamic> row) {
    final json = Map<String, dynamic>.from(row)
      ..remove('payload_totals')
      ..remove('payload_available_money');
    json['input_payload'] = <String, dynamic>{
      'workbook': <String, dynamic>{'totals': row['payload_totals']},
      'available_money': row['payload_available_money'],
    };
    return json;
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

  /// report_base_date 列と同一形式 (yyyy-MM-dd) の基準日キー。
  /// [loadLatestForBaseDate] へ渡す値もこれで作る。
  static String reportBaseDateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _dateOnly(DateTime value) => reportBaseDateKey(value);
}
