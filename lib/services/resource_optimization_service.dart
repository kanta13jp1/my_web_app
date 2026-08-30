import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/resource_optimization.dart';

typedef ResourceOptimizerInvoker = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> body,
);

class ResourceOptimizationAnalysis {
  const ResourceOptimizationAnalysis({
    required this.report,
    required this.aiStatus,
  });

  final ResourceOptimizationReport report;
  final String aiStatus;
}

class ResourceOptimizationService {
  const ResourceOptimizationService({
    SupabaseClient? client,
    ResourceOptimizerInvoker? invoker,
  })  : _client = client,
        _invoker = invoker;

  final SupabaseClient? _client;
  final ResourceOptimizerInvoker? _invoker;

  Future<ResourceOptimizationReport> analyze({int days = 90}) async {
    final analysis = await _analyze(
      days: days,
      useAi: false,
      aiDataConsent: false,
    );
    return analysis.report;
  }

  Future<ResourceOptimizationAnalysis> analyzeWithAiConsent({
    int days = 90,
  }) {
    return _analyze(days: days, useAi: true, aiDataConsent: true);
  }

  Future<ResourceOptimizationAnalysis> _analyze({
    required int days,
    required bool useAi,
    required bool aiDataConsent,
  }) async {
    final safeDays = days.clamp(7, 365);
    final payload = await _invoke({
      'days': safeDays,
      'use_ai': useAi,
      'ai_data_consent': aiDataConsent,
    });
    if (payload['success'] != true) {
      throw StateError((payload['error'] ?? 'リソース最適化の分析に失敗しました').toString());
    }
    final report = ResourceOptimizationReport.fromJson(payload);
    return ResourceOptimizationAnalysis(
      report: report,
      aiStatus: (payload['ai_status'] ??
              (report.generatedBy == 'gemini' ? 'generated' : 'not_requested'))
          .toString(),
    );
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final invoker = _invoker;
    if (invoker != null) return invoker(body);
    final response = await (_client ?? Supabase.instance.client)
        .functions
        .invoke('resource-optimizer', body: body);
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'success': false, 'error': data?.toString() ?? '空のレスポンスが返されました'};
  }
}
