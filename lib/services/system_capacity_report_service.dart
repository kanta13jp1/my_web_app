import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 月次システム利用統計・キャパシティレポートの1か月分レコード (#2745)。
@immutable
class SystemCapacityMonthlyStat {
  const SystemCapacityMonthlyStat({
    required this.reportMonth,
    required this.userAccessCount,
    required this.batchJobCount,
    required this.errorCount,
    required this.errorRatePercent,
    required this.summaryPayload,
    this.notifiedAt,
    this.updatedAt,
  });

  final String reportMonth;
  final int userAccessCount;
  final int batchJobCount;
  final int errorCount;
  final double errorRatePercent;
  final DateTime? notifiedAt;
  final Map<String, Object?> summaryPayload;
  final DateTime? updatedAt;

  bool get isNotified => notifiedAt != null;

  factory SystemCapacityMonthlyStat.fromJson(Map<String, Object?> json) {
    final rawPayload = json['summary_payload'];
    final summaryPayload = <String, Object?>{};
    if (rawPayload is Map) {
      rawPayload.forEach((key, value) {
        summaryPayload[key.toString()] = value;
      });
    }
    return SystemCapacityMonthlyStat(
      reportMonth: (json['report_month']?.toString() ?? '').trim(),
      userAccessCount: _parseNonNegativeInt(json['user_access_count']),
      batchJobCount: _parseNonNegativeInt(json['batch_job_count']),
      errorCount: _parseNonNegativeInt(json['error_count']),
      errorRatePercent: _parseNonNegativeDouble(json['error_rate_percent']),
      notifiedAt: _parseOptionalDateTime(json['notified_at']),
      summaryPayload: Map<String, Object?>.unmodifiable(summaryPayload),
      updatedAt: _parseOptionalDateTime(json['updated_at']),
    );
  }
}

/// 月次レポート通知アクションの結果 (#2745)。
@immutable
class CapacityReportNotifyResult {
  const CapacityReportNotifyResult({
    required this.report,
    required this.dryRun,
    required this.emailSent,
    required this.inAppRecorded,
    required this.message,
  });

  final SystemCapacityMonthlyStat report;
  final bool dryRun;
  final bool emailSent;
  final bool inAppRecorded;
  final String message;
}

/// 管理者向けシステムキャパシティレポートリポジトリ境界 (#2745)。
abstract class SystemCapacityReportRepository {
  Future<List<SystemCapacityMonthlyStat>> fetchMonthlyStats({int limit = 12});

  Future<SystemCapacityMonthlyStat> aggregateMonth({String? reportMonth});

  Future<CapacityReportNotifyResult> notifyReport({
    String? reportMonth,
    bool dryRun = false,
  });
}

typedef SupabaseClientResolver = SupabaseClient Function();

/// `admin-hub` Edge Function 経由で月次キャパシティ統計を取得・集計・通知する実装 (#2745)。
///
/// `Supabase.instance.client` は呼び出し時まで遅延解決し、ウィジェットテスト等での
/// 未初期化アクセスを防ぐ。
class SupabaseSystemCapacityReportRepository
    implements SystemCapacityReportRepository {
  SupabaseSystemCapacityReportRepository({
    SupabaseClient? client,
    SupabaseClientResolver? clientResolver,
  })  : _client = client,
        _clientResolver = clientResolver;

  final SupabaseClient? _client;
  final SupabaseClientResolver? _clientResolver;

  SupabaseClient get _resolvedClient =>
      _client ??
      (_clientResolver != null ? _clientResolver() : Supabase.instance.client);

  @override
  Future<List<SystemCapacityMonthlyStat>> fetchMonthlyStats({
    int limit = 12,
  }) async {
    final res = await _resolvedClient.functions.invoke(
      'admin-hub',
      body: <String, Object?>{
        'action': 'capacity_report.list',
        'limit': limit,
      },
    );
    final map = _asStringMap(res.data);
    _throwIfError(map, fallback: '月次統計一覧の取得に失敗しました');
    final rawReports = map['reports'];
    if (rawReports is! List) {
      return const <SystemCapacityMonthlyStat>[];
    }
    return rawReports
        .whereType<Map<Object?, Object?>>()
        .map(
          (row) => SystemCapacityMonthlyStat.fromJson(
            _asStringMap(row),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<SystemCapacityMonthlyStat> aggregateMonth({
    String? reportMonth,
  }) async {
    final trimmed = reportMonth?.trim() ?? '';
    final res = await _resolvedClient.functions.invoke(
      'admin-hub',
      body: <String, Object?>{
        'action': 'capacity_report.aggregate',
        if (trimmed.isNotEmpty) 'report_month': trimmed,
      },
    );
    final map = _asStringMap(res.data);
    _throwIfError(map, fallback: '月次統計の集計に失敗しました');
    final rawReport = map['report'];
    if (rawReport is Map<Object?, Object?>) {
      return SystemCapacityMonthlyStat.fromJson(_asStringMap(rawReport));
    }
    throw StateError('月次統計の集計レスポンスを取得できませんでした');
  }

  @override
  Future<CapacityReportNotifyResult> notifyReport({
    String? reportMonth,
    bool dryRun = false,
  }) async {
    final trimmed = reportMonth?.trim() ?? '';
    final res = await _resolvedClient.functions.invoke(
      'admin-hub',
      body: <String, Object?>{
        'action': 'capacity_report.notify',
        if (trimmed.isNotEmpty) 'report_month': trimmed,
        'dry_run': dryRun,
      },
    );
    final map = _asStringMap(res.data);
    _throwIfError(map, fallback: '月次レポート通知の送信に失敗しました');
    final rawReport = map['report'];
    if (rawReport is! Map<Object?, Object?>) {
      throw StateError('月次通知レスポンスの統計情報を取得できませんでした');
    }
    final report = SystemCapacityMonthlyStat.fromJson(_asStringMap(rawReport));
    final delivery = _asStringMap(map['delivery']);
    final emailSent = delivery['email_sent'] == true;
    final inAppRecorded = delivery['in_app_recorded'] == true;
    final isDryRun = map['dry_run'] == true;
    final message = isDryRun
        ? '${report.reportMonth} の通知プレビューを確認しました'
        : emailSent
            ? '${report.reportMonth} の月次レポートをメール送信・記録しました'
            : '${report.reportMonth} の月次レポート通知を記録しました';
    return CapacityReportNotifyResult(
      report: report,
      dryRun: isDryRun,
      emailSent: emailSent,
      inAppRecorded: inAppRecorded,
      message: message,
    );
  }
}

Map<String, Object?> _asStringMap(Object? raw) {
  final result = <String, Object?>{};
  if (raw is Map<Object?, Object?>) {
    raw.forEach((key, value) {
      result[key.toString()] = value;
    });
  }
  return result;
}

void _throwIfError(Map<String, Object?> map, {required String fallback}) {
  final err = map['error']?.toString().trim() ?? '';
  if (err.isNotEmpty) {
    throw StateError('$fallback ($err)');
  }
}

int _parseNonNegativeInt(Object? raw) {
  if (raw is int) return raw < 0 ? 0 : raw;
  if (raw is num) {
    final value = raw.round();
    return value < 0 ? 0 : value;
  }
  if (raw is String) {
    final parsed = int.tryParse(raw.trim());
    if (parsed != null) return parsed < 0 ? 0 : parsed;
  }
  return 0;
}

double _parseNonNegativeDouble(Object? raw) {
  if (raw is double) return raw < 0 ? 0 : raw;
  if (raw is num) {
    final value = raw.toDouble();
    return value < 0 ? 0 : value;
  }
  if (raw is String) {
    final parsed = double.tryParse(raw.trim());
    if (parsed != null) return parsed < 0 ? 0 : parsed;
  }
  return 0;
}

DateTime? _parseOptionalDateTime(Object? raw) {
  final text = raw?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toUtc();
}
