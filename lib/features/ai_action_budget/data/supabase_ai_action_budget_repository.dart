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

  @override
  Future<AiBudgetSnapshot> fetchSnapshot({required String billingMonth}) async {
    final client = _resolvedClient;
    final userId = _requireUserId(client);
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
    final Object updated = await client
        .from('ai_action_budget_configs')
        .update(<String, Object?>{'is_paused': false})
        .eq('user_id', userId)
        .select()
        .single();
    return AiActionBudgetConfig.fromSupabaseRow(_normalizeRow(updated));
  }

  @override
  Future<AiActionLedgerEntry> recordActionUsage({
    required AiActionLedgerEntry draft,
    required bool triggerPauseAfterSave,
  }) async {
    final client = _resolvedClient;
    final userId = _requireUserId(client);
    final Object inserted = await client
        .from('ai_action_budget_ledger')
        .insert(draft.toInsertPayload(userId: userId))
        .select()
        .single();
    final created =
        AiActionLedgerEntry.fromSupabaseRow(_normalizeRow(inserted));

    if (triggerPauseAfterSave) {
      await client
          .from('ai_action_budget_configs')
          .update(<String, Object?>{'is_paused': true}).eq('user_id', userId);
    }
    return created;
  }
}
