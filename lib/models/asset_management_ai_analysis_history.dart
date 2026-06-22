class AssetManagementAiAnalysisHistoryEntry {
  final String id;
  final String requestFingerprint;
  final String summaryText;
  final String status;
  final String source;
  final DateTime generatedAt;
  final DateTime createdAt;
  final DateTime? reportBaseDate;
  final String? providerChoiceReason;
  final Map<String, dynamic> providerRoute;
  final Map<String, dynamic> inputPayload;

  const AssetManagementAiAnalysisHistoryEntry({
    required this.id,
    required this.requestFingerprint,
    required this.summaryText,
    required this.status,
    required this.source,
    required this.generatedAt,
    required this.createdAt,
    required this.reportBaseDate,
    required this.providerChoiceReason,
    required this.providerRoute,
    required this.inputPayload,
  });

  factory AssetManagementAiAnalysisHistoryEntry.fromJson(
    Map<String, dynamic> json,
  ) {
    return AssetManagementAiAnalysisHistoryEntry(
      id: json['id']?.toString() ?? '',
      requestFingerprint: json['request_fingerprint']?.toString() ?? '',
      summaryText: json['summary_text']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      generatedAt: _parseDateTime(json['generated_at']),
      createdAt: _parseDateTime(json['created_at']),
      reportBaseDate: _parseNullableDate(json['report_base_date']),
      providerChoiceReason: _emptyToNull(
        json['provider_choice_reason']?.toString(),
      ),
      providerRoute: _mapFrom(json['provider_route']),
      inputPayload: _mapFrom(json['input_payload']),
    );
  }

  Map<String, dynamic> toPromptContextJson() {
    return <String, dynamic>{
      'id': id,
      'request_fingerprint': requestFingerprint,
      'status': status,
      'source': source,
      'generated_at': generatedAt.toIso8601String(),
      'report_base_date': reportBaseDate?.toIso8601String(),
      'provider_choice_reason': providerChoiceReason,
      'provider_route': providerRoute,
      // 過去分析の本文(prose)は LLM へ渡さない。攻撃的ペルソナが当時の負の値・
      // 期限超過・未払いを「現在の事実」として再生産する原因になるため。トレンド把握に
      // 必要な数値メトリクスだけを過去スナップショットとして渡す。
      'metrics_snapshot': _metricsSnapshotFromPayload(),
    };
  }

  /// 過去分析時点の数値スナップショット (= トレンド比較用)。
  /// 保存済み input_payload から純資産・未払い合計・使用可能額のみを抽出する。
  Map<String, dynamic> _metricsSnapshotFromPayload() {
    final workbook = _mapFrom(inputPayload['workbook']);
    final totals = _mapFrom(workbook['totals']);
    final availableMoney = _mapFrom(inputPayload['available_money']);
    return <String, dynamic>{
      'net_worth': _numFrom(totals['net_worth']),
      'liability_total': _numFrom(totals['liability_total']),
      'monthly_unpaid_payment_total':
          _numFrom(totals['monthly_unpaid_payment_total']),
      'monthly_actual_payment_total':
          _numFrom(totals['monthly_actual_payment_total']),
      'today_available_amount': _availableAmount(availableMoney['today']),
      'week_available_amount': _availableAmount(availableMoney['week']),
      'month_available_amount': _availableAmount(availableMoney['month']),
    };
  }

  static num? _availableAmount(Object? windowJson) {
    return _numFrom(_mapFrom(windowJson)['available_amount']);
  }

  static num? _numFrom(Object? value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }

  static DateTime _parseDateTime(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  static DateTime? _parseNullableDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static Map<String, dynamic> _mapFrom(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
