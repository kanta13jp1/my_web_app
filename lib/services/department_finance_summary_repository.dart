import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/department_finance_summary.dart';

abstract interface class DepartmentFinanceSummaryRepository {
  Future<DepartmentFinanceSummary> loadCurrentMonth();
}

class SupabaseDepartmentFinanceSummaryRepository
    implements DepartmentFinanceSummaryRepository {
  SupabaseDepartmentFinanceSummaryRepository({SupabaseClient? client})
      : _injectedClient = client;

  final SupabaseClient? _injectedClient;

  SupabaseClient get _client => _injectedClient ?? Supabase.instance.client;

  @override
  Future<DepartmentFinanceSummary> loadCurrentMonth() async {
    if (_client.auth.currentUser == null) {
      throw const DepartmentFinanceSummaryRepositoryException(
        'ログインが必要です。',
      );
    }
    final response = await _client.functions.invoke(
      'ai-hub',
      body: const {'action': 'ai_hub.department_finance_summary'},
    );
    return DepartmentFinanceSummary.fromJson(_record(response.data));
  }

  static Map<String, dynamic> _record(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const DepartmentFinanceSummaryRepositoryException(
      '資産サマリの応答形式が不正です。',
    );
  }
}

class DepartmentFinanceSummaryRepositoryException implements Exception {
  const DepartmentFinanceSummaryRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
