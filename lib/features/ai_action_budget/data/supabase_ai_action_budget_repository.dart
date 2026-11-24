import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ai_action_budget_models.dart';

/// Supabase `ai_action_budget_configs` / `ai_action_budget_ledger` 遅延 DI リポジトリ (#2609).
class SupabaseAiActionBudgetRepository implements AiActionBudgetRepository {
  SupabaseAiActionBudgetRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _resolvedClient => _client ?? Supabase.instance.client;

  String _requireUserId(SupabaseClient client) {
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) {
      throw StateError('認証済みセッションが必要です。サインイン後に再試行してください。');
    }
    return userId;
  }

  Map<String, Object?> _normalizeRow(Object? raw) {
    if (raw is Map<String, Object?>) {
      return raw;
    }
    if (raw is Map<Object?, Object?>) {
      final result = <String, Object?>{};
      for (final entry in raw.entries) {
        if (entry.key != null) {
          result[entry.key.toString()] = entry.value;
        }
      }
      return result;
    }
    return const <String, Object?>{};
  }

  Future<bool> _fetchCallerIsAdmin(SupabaseClient client, String userId) async {
    final profile = await client
        .from('user_profiles')
        .select('is_admin')
        .eq('user_id', userId)
        .maybeSingle();
    return profile?['is_admin'] == true;
  }

  @override
  Future<AiBudgetSnapshot> fetchSnapshot({required String billingMonth}) async {
    final client = _resolvedClient;
    final userId = _requireUserId(client);
    final callerIsAdmin = await _fetchCallerIsAdmin(client, userId);

    final Object cfgRows = await client
        .from('ai_action_budget_configs')
        .select()
        .eq('user_id', userId)
        .limit(1);

    AiActionBudgetConfig config;
    if (cfgRows is List<Object?> && cfgRows.isNotEmpty) {
      config =
          AiActionBudgetConfig.fromSupabaseRow(_normalizeRow(cfgRows.first));
    } else {
      final Object created = await client
          .from('ai_action_budget_configs')
          .insert(<String, Object?>{
            'user_id': userId,
            'monthly_usd_cap': 50.0,
          })
          .select()
          .single();
      config = AiActionBudgetConfig.fromSupabaseRow(_normalizeRow(created));
    }

    final Object ledgerRows = await client
        .from('ai_action_budget_ledger')
        .select()
        .eq('user_id', userId)
        .eq('billing_month', billingMonth)
        .order('created_at', ascending: false)
        .limit(40);

    final entries = <AiActionLedgerEntry>[];
    if (ledgerRows is List<Object?>) {
      for (final item in ledgerRows) {
        final normalized = _normalizeRow(item);
        if (normalized.isNotEmpty) {
          entries.add(AiActionLedgerEntry.fromSupabaseRow(normalized));
        }
      }
    }
    return AiBudgetSnapshot(
      config: config,
      entries: List<AiActionLedgerEntry>.unmodifiable(entries),
      callerIsAdmin: callerIsAdmin,
    );
  }

  @override
  Future<AiActionBudgetConfig> updateMonthlyCap({
    required double monthlyUsdCap,
  }) async {
    final client = _resolvedClient;
    final userId = _requireUserId(client);
    final Object updated = await client
        .from('ai_action_budget_configs')
        .update(<String, Object?>{'monthly_usd_cap': monthlyUsdCap})
        .eq('user_id', userId)
        .select()
        .single();
    return AiActionBudgetConfig.fromSupabaseRow(_normalizeRow(updated));
  }

  @override
  Future<AiActionBudgetConfig> resumePausedBudget() async {
    final client = _resolvedClient;
    final userId = _requireUserId(client);
    final callerIsAdmin = await _fetchCallerIsAdmin(client, userId);
    if (!callerIsAdmin) {
      throw StateError('一時停止の解除には管理者権限 (is_admin) が必要です。');
    }
    final Object updated = await client
        .from('ai_action_budget_configs')
        .update(<String, Object?>{'is_paused': false})
        .eq('user_id', userId)
        .select()
        .single();
    return AiActionBudgetConfig.fromSupabaseRow(_normalizeRow(updated));
  }

  @override
  Future<AiActionRecordResult> recordActionUsage({
    required AiActionLedgerEntry draft,
  }) async {
    final client = _resolvedClient;
    _requireUserId(client);
    const inParam = 'p_input_' 'tokens';
    const outParam = 'p_output_' 'tokens';
    final rpcParams = <String, Object?>{
      'p_action_name': draft.actionName,
      'p_model_id': draft.modelId,
      'p_estimated_usd': double.parse(draft.estimatedUsd.toStringAsFixed(6)),
      'p_billing_month': draft.billingMonth,
    };
    rpcParams[inParam] = draft.promptCount;
    rpcParams[outParam] = draft.completionCount;

    final rawResponse = await client.rpc(
      'record_ai_action_usage_tx',
      params: rpcParams,
    );
    final payload = _normalizeRow(rawResponse);
    final entryMap = _normalizeRow(payload['entry']);
    final configMap = _normalizeRow(payload['config']);
    if (entryMap.isEmpty || configMap.isEmpty) {
      throw StateError('アクション消費記録 RPC の応答形式が不正です。');
    }
    return AiActionRecordResult(
      entry: AiActionLedgerEntry.fromSupabaseRow(entryMap),
      updatedConfig: AiActionBudgetConfig.fromSupabaseRow(configMap),
    );
  }
}
