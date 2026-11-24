import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 週次パフォーマンスレポートの配信状態。
enum WeeklyDeliveryStatus {
  draft('draft', '下書き'),
  dryRun('dry_run', 'ドライラン生成済み'),
  sent('sent', '配信完了'),
  failed('failed', '配信失敗');

  const WeeklyDeliveryStatus(this.dbValue, this.labelJa);

  final String dbValue;
  final String labelJa;

  static WeeklyDeliveryStatus fromDb(String? raw) {
    final String normalized = (raw ?? '').trim().toLowerCase();
    for (final WeeklyDeliveryStatus value in WeeklyDeliveryStatus.values) {
      if (value.dbValue == normalized) {
        return value;
      }
    }
    return WeeklyDeliveryStatus.draft;
  }
}

/// 検知された週次異常項目。
@immutable
class WeeklyPerformanceAnomaly {
  const WeeklyPerformanceAnomaly({
    required this.code,
    required this.severity,
    required this.title,
    required this.detail,
  });

  final String code;
  final String severity;
  final String title;
  final String detail;

  factory WeeklyPerformanceAnomaly.fromJson(Map<String, Object?> json) {
    return WeeklyPerformanceAnomaly(
      code: (json['code'] as String? ?? '').trim(),
      severity: (json['severity'] as String? ?? 'info').trim(),
      title: (json['title'] as String? ?? '').trim(),
      detail: (json['detail'] as String? ?? '').trim(),
    );
  }
}

/// 週次パフォーマンスレポートモデル。
@immutable
class WeeklyPerformanceReport {
  const WeeklyPerformanceReport({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    required this.activeDays,
    required this.tasksCompleted,
    required this.tasksDeltaPct,
    required this.focusMinutes,
    required this.focusDeltaPct,
    required this.errorCount,
    required this.anomalies,
    required this.insightMarkdown,
    required this.deliveryStatus,
    this.piiRedacted = true,
  });

  final String id;
  final String periodStart;
  final String periodEnd;
  final int activeDays;
  final int tasksCompleted;
  final double tasksDeltaPct;
  final int focusMinutes;
  final double focusDeltaPct;
  final int errorCount;
  final List<WeeklyPerformanceAnomaly> anomalies;
  final String insightMarkdown;
  final WeeklyDeliveryStatus deliveryStatus;
  final bool piiRedacted;

  WeeklyPerformanceReport copyWith({
    WeeklyDeliveryStatus? deliveryStatus,
    String? insightMarkdown,
    bool? piiRedacted,
  }) {
    return WeeklyPerformanceReport(
      id: id,
      periodStart: periodStart,
      periodEnd: periodEnd,
      activeDays: activeDays,
      tasksCompleted: tasksCompleted,
      tasksDeltaPct: tasksDeltaPct,
      focusMinutes: focusMinutes,
      focusDeltaPct: focusDeltaPct,
      errorCount: errorCount,
      anomalies: anomalies,
      insightMarkdown: insightMarkdown ?? this.insightMarkdown,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      piiRedacted: piiRedacted ?? this.piiRedacted,
    );
  }

  factory WeeklyPerformanceReport.fromJson(Map<String, Object?> json) {
    final Object? rawSummary = json['metrics_summary'];
    final Map<String, Object?> summary = rawSummary is Map<String, Object?>
        ? rawSummary
        : const <String, Object?>{};
    final Object? rawAnomalies = json['anomalies'];
    final List<WeeklyPerformanceAnomaly> parsedAnomalies =
        rawAnomalies is List<Object?>
            ? rawAnomalies
                .whereType<Map<String, Object?>>()
                .map(WeeklyPerformanceAnomaly.fromJson)
                .toList(growable: false)
            : const <WeeklyPerformanceAnomaly>[];

    return WeeklyPerformanceReport(
      id: (json['id'] as String? ?? '').trim(),
      periodStart: (json['period_start'] as String? ?? '').trim(),
      periodEnd: (json['period_end'] as String? ?? '').trim(),
      activeDays: (summary['active_days'] as num?)?.toInt() ?? 0,
      tasksCompleted: (summary['tasks_completed'] as num?)?.toInt() ?? 0,
      tasksDeltaPct: (summary['tasks_delta_pct'] as num?)?.toDouble() ?? 0.0,
      focusMinutes: (summary['focus_minutes'] as num?)?.toInt() ?? 0,
      focusDeltaPct: (summary['focus_delta_pct'] as num?)?.toDouble() ?? 0.0,
      errorCount: (summary['error_count'] as num?)?.toInt() ?? 0,
      anomalies: parsedAnomalies,
      insightMarkdown: (json['insight_markdown'] as String? ?? '').trim(),
      deliveryStatus: WeeklyDeliveryStatus.fromDb(
        json['delivery_status'] as String?,
      ),
      piiRedacted: json['pii_redacted'] as bool? ?? true,
    );
  }
}

/// 決定論的な PII マスキングおよびドライラン評価ロジック。
class WeeklyReportPrivacyEvaluator {
  const WeeklyReportPrivacyEvaluator._();

  static final RegExp _emailPattern = RegExp(
    r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b',
  );
  static final RegExp _bearerPattern = RegExp(
    r'\bBearer\s+[A-Za-z0-9._~+/=-]{6,}',
    caseSensitive: false,
  );
  static final RegExp _phonePattern = RegExp(
    r'(?<!\d)(?:\+?\d{1,3}[-.\s]?)?(?:\(?\d{2,4}\)?[-.\s]?)\d{3,4}[-.\s]?\d{3,4}(?!\d)',
  );

  /// クライアント側プレビュー表示や要約メモ送信前に個人情報をマスクする。
  static String redactPiiForPreview(String rawText) {
    return rawText
        .replaceAll(_emailPattern, '[REDACTED_EMAIL]')
        .replaceAll(_bearerPattern, '[REDACTED_TOKEN]')
        .replaceAll(_phonePattern, '[REDACTED_PHONE]');
  }

  static WeeklyPerformanceReport buildDefaultSampleReport({
    DateTime? now,
    String? customNote,
  }) {
    final DateTime anchor = (now ?? DateTime.now()).toUtc();
    final DateTime start = anchor.subtract(const Duration(days: 6));
    String fmt(DateTime dt) =>
        '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

    final String safeNote = redactPiiForPreview((customNote ?? '').trim());
    final String noteSection = safeNote.isEmpty ? '' : '\n\n補足メモ: $safeNote';

    return WeeklyPerformanceReport(
      id: 'local-preview-7d',
      periodStart: fmt(start),
      periodEnd: fmt(anchor),
      activeDays: 5,
      tasksCompleted: 18,
      tasksDeltaPct: 12.5,
      focusMinutes: 420,
      focusDeltaPct: 8.0,
      errorCount: 1,
      anomalies: const <WeeklyPerformanceAnomaly>[
        WeeklyPerformanceAnomaly(
          code: 'focus_consistency',
          severity: 'info',
          title: '安定した稼働ペース',
          detail: '直近7日間で5日稼働・完了タスク+12.5%を維持しています。',
        ),
      ],
      insightMarkdown: '### 週次サマリー (${fmt(start)} 〜 ${fmt(anchor)})\n'
          '- 完了タスク 18件 (+12.5% WoW)、集中時間 420分 (+8.0% WoW)\n'
          '- PII匿名化処理を適用した状態でレポートを生成しました。$noteSection',
      deliveryStatus: WeeklyDeliveryStatus.dryRun,
      piiRedacted: true,
    );
  }
}

typedef WeeklyReportDeliveryRunner = Future<WeeklyDeliveryStatus> Function(
  WeeklyPerformanceReport report,
  bool dryRun,
);

/// 週次パフォーマンスレポート一覧・ドライラン生成・配信トリガー管理サービス。
class WeeklyPerformanceReportService extends ChangeNotifier {
  WeeklyPerformanceReportService({
    SupabaseClient Function()? clientResolver,
    WeeklyReportDeliveryRunner? deliveryRunner,
    DateTime Function()? nowProvider,
    List<WeeklyPerformanceReport>? initialReports,
  })  : _clientResolver = clientResolver,
        _deliveryRunner = deliveryRunner,
        _nowProvider = nowProvider ?? DateTime.now,
        _reports = List<WeeklyPerformanceReport>.from(
          initialReports ?? const <WeeklyPerformanceReport>[],
        );

  final SupabaseClient Function()? _clientResolver;
  final WeeklyReportDeliveryRunner? _deliveryRunner;
  final DateTime Function() _nowProvider;
  final List<WeeklyPerformanceReport> _reports;

  bool _isBusy = false;
  bool _disposed = false;
  String _statusMessage = '';

  List<WeeklyPerformanceReport> get reports =>
      List<WeeklyPerformanceReport>.unmodifiable(_reports);
  WeeklyPerformanceReport? get latestReport =>
      _reports.isEmpty ? null : _reports.first;
  bool get isBusy => _isBusy;
  String get statusMessage => _statusMessage;

  Future<void> loadReports() async {
    _isBusy = true;
    _notifySafely();
    try {
      final SupabaseClient? client = _tryResolveClient();
      final String? userId = client?.auth.currentUser?.id;
      if (client != null && userId != null) {
        final List<Object?> rows = await client
            .from('weekly_performance_reports')
            .select()
            .eq('user_id', userId)
            .order('period_end', ascending: false)
            .limit(12);
        _reports
          ..clear()
          ..addAll(
            rows
                .whereType<Map<String, Object?>>()
                .map(WeeklyPerformanceReport.fromJson),
          );
      }
      if (_reports.isEmpty) {
        _reports.add(
          WeeklyReportPrivacyEvaluator.buildDefaultSampleReport(
            now: _nowProvider(),
          ),
        );
        _statusMessage = '直近7日間のローカルプレビューレポートを表示しています。';
      } else {
        _statusMessage = '週次パフォーマンスレポートを ${_reports.length} 件読み込みました。';
      }
    } catch (_) {
      if (_reports.isEmpty) {
        _reports.add(
          WeeklyReportPrivacyEvaluator.buildDefaultSampleReport(
            now: _nowProvider(),
          ),
        );
      }
      _statusMessage = 'リモート取得に失敗したためローカルサマリーを表示しています。';
    } finally {
      _isBusy = false;
      _notifySafely();
    }
  }

  /// PII マスキング済みのドライランプレビューを生成する。
  Future<WeeklyPerformanceReport> generateDryRunPreview({
    String contextNote = '',
  }) async {
    final WeeklyPerformanceReport generated =
        WeeklyReportPrivacyEvaluator.buildDefaultSampleReport(
      now: _nowProvider(),
      customNote: contextNote,
    );
    _reports
      ..removeWhere((WeeklyPerformanceReport r) => r.id == generated.id)
      ..insert(0, generated);
    _statusMessage = 'PII 匿名化済みのドライランプレビューを生成しました。';
    _notifySafely();
    return generated;
  }

  /// レポート配信（またはドライラン実行）を起動する。
  Future<bool> triggerDelivery({bool dryRun = false}) async {
    final WeeklyPerformanceReport target = latestReport ??
        WeeklyReportPrivacyEvaluator.buildDefaultSampleReport(
          now: _nowProvider(),
        );
    _isBusy = true;
    _notifySafely();
    try {
      final WeeklyReportDeliveryRunner? runner = _deliveryRunner;
      final WeeklyDeliveryStatus nextStatus;
      if (runner != null) {
        nextStatus = await runner(target, dryRun);
      } else {
        nextStatus =
            dryRun ? WeeklyDeliveryStatus.dryRun : WeeklyDeliveryStatus.sent;
      }
      final WeeklyPerformanceReport updated = target.copyWith(
        deliveryStatus: nextStatus,
        piiRedacted: true,
      );
      if (_reports.isEmpty) {
        _reports.add(updated);
      } else {
        _reports[0] = updated;
      }
      _statusMessage = nextStatus == WeeklyDeliveryStatus.sent
          ? '週次レポートの配信を完了しました。'
          : '週次レポートのドライラン検証を完了しました。';
      return true;
    } catch (_) {
      if (_reports.isNotEmpty) {
        _reports[0] = _reports[0].copyWith(
          deliveryStatus: WeeklyDeliveryStatus.failed,
        );
      }
      _statusMessage = 'レポート配信処理でエラーが発生しました。再試行してください。';
      return false;
    } finally {
      _isBusy = false;
      _notifySafely();
    }
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

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    super.dispose();
  }
}
