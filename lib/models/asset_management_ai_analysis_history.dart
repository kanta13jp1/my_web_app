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

  Map<String, dynamic> toPromptContextJson({
    int maxSummaryCharacters = 1800,
  }) {
    final trimmed = summaryText.trim();
    return <String, dynamic>{
      'id': id,
      'request_fingerprint': requestFingerprint,
      'status': status,
      'source': source,
      'generated_at': generatedAt.toIso8601String(),
      'report_base_date': reportBaseDate?.toIso8601String(),
      'provider_choice_reason': providerChoiceReason,
      'provider_route': providerRoute,
      'summary_excerpt': _truncate(trimmed, maxSummaryCharacters),
    };
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

  static String _truncate(String value, int maxCharacters) {
    if (value.length <= maxCharacters) {
      return value;
    }
    return '${value.substring(0, maxCharacters)}...';
  }
}
