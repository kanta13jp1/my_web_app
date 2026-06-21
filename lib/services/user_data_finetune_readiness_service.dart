import 'package:supabase_flutter/supabase_flutter.dart';

class UserDataFineTuneReadinessSnapshot {
  const UserDataFineTuneReadinessSnapshot({
    required this.method,
    required this.totalRecords,
    required this.eligibleRecords,
    required this.blockedRecords,
    required this.qualityScore,
    required this.readyForEvalBatch,
    required this.readyForFineTune,
    required this.piiRisk,
    required this.sourceCounts,
    required this.signalSummary,
    required this.kgi,
    required this.csf,
    required this.kpi,
    required this.nextAction,
  });

  factory UserDataFineTuneReadinessSnapshot.empty() {
    return const UserDataFineTuneReadinessSnapshot(
      method: 'scale_egp_first_party_data_engine_v1',
      totalRecords: 0,
      eligibleRecords: 0,
      blockedRecords: 0,
      qualityScore: 0,
      readyForEvalBatch: false,
      readyForFineTune: false,
      piiRisk: 'low',
      sourceCounts: {},
      signalSummary: {},
      kgi: '自社プロダクトのデータでAIの回答品質を高めます。',
      csf: [
        'Collect consent-aware feedback',
        'De-identify before export',
        'Evaluate before fine-tuning',
      ],
      kpi: {},
      nextAction: 'チューニング前に、「役に立った／改善が必要」の明示的なフィードバックをさらに集めましょう。',
    );
  }

  factory UserDataFineTuneReadinessSnapshot.fromJson(
    Map<String, dynamic> json,
  ) {
    return UserDataFineTuneReadinessSnapshot(
      method: _stringValue(
        json['method'],
        fallback: 'scale_egp_first_party_data_engine_v1',
      ),
      totalRecords: _intValue(json['total_records']),
      eligibleRecords: _intValue(json['eligible_records']),
      blockedRecords: _intValue(json['blocked_records']),
      qualityScore: _intValue(json['quality_score']),
      readyForEvalBatch: json['ready_for_eval_batch'] == true,
      readyForFineTune: json['ready_for_fine_tune'] == true,
      piiRisk: _stringValue(json['pii_risk'], fallback: 'unknown'),
      sourceCounts: _intMap(json['source_counts']),
      signalSummary: _intMap(json['signal_summary']),
      kgi: _stringValue(json['kgi']),
      csf: _stringList(json['csf']),
      kpi: _intMap(json['kpi']),
      nextAction: _stringValue(
        json['next_action'],
        fallback: UserDataFineTuneReadinessSnapshot.empty().nextAction,
      ),
    );
  }

  final String method;
  final int totalRecords;
  final int eligibleRecords;
  final int blockedRecords;
  final int qualityScore;
  final bool readyForEvalBatch;
  final bool readyForFineTune;
  final String piiRisk;
  final Map<String, int> sourceCounts;
  final Map<String, int> signalSummary;
  final String kgi;
  final List<String> csf;
  final Map<String, int> kpi;
  final String nextAction;

  int get eligibleTarget => kpi['eligible_records_target'] ?? 100;

  double get eligibleProgress {
    if (eligibleTarget <= 0) return 0;
    return (eligibleRecords / eligibleTarget).clamp(0.0, 1.0).toDouble();
  }
}

class UserDataFineTuneReadinessService {
  UserDataFineTuneReadinessService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<UserDataFineTuneReadinessSnapshot?> loadSnapshot() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return UserDataFineTuneReadinessSnapshot.empty();

    try {
      final response = await _supabase.functions.invoke(
        'ai-hub',
        body: {'action': 'user_data.finetune_readiness'},
      );
      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) return null;
      final snapshot = data['snapshot'] as Map<String, dynamic>? ?? {};
      return UserDataFineTuneReadinessSnapshot.fromJson(snapshot);
    } catch (_) {
      return null;
    }
  }
}

String _stringValue(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _intValue(Object? value, {int fallback = 0}) {
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

Map<String, int> _intMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      entry.key.toString(): _intValue(entry.value),
  };
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
