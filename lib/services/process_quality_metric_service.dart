import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/process_quality_metric.dart';

abstract class ProcessQualityMetricRepository {
  Future<List<ProcessQualityMetric>> list();

  Future<ProcessQualityMetric> add(ProcessQualityMetricDraft draft);
}

class SupabaseProcessQualityMetricRepository
    implements ProcessQualityMetricRepository {
  final SupabaseClient _client;

  SupabaseProcessQualityMetricRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<List<ProcessQualityMetric>> list() async {
    _requireUserId();
    final rows = await _client
        .from('process_quality_metrics')
        .select()
        .order('reviewed_at', ascending: false)
        .limit(100);
    return rows
        .map(ProcessQualityMetric.fromJson)
        .toList(growable: false);
  }

  @override
  Future<ProcessQualityMetric> add(ProcessQualityMetricDraft draft) async {
    final userId = _requireUserId();
    final row = await _client
        .from('process_quality_metrics')
        .insert(draft.toInsertRow(userId))
        .select()
        .single();
    return ProcessQualityMetric.fromJson(row);
  }

  String _requireUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('ログインが必要です。');
    }
    return userId;
  }
}
