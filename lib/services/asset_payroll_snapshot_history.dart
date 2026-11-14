import 'package:supabase_flutter/supabase_flutter.dart';
import 'asset_payroll_snapshot_store.dart';

class PayrollSnapshotHistoryEntry {
  const PayrollSnapshotHistoryEntry({
    required this.id,
    required this.record,
    required this.previousId,
    required this.reason,
    required this.changedAt,
  });
  final int id;
  final PayrollSnapshotRecord record;
  final String? previousId;
  final String reason;
  final DateTime changedAt;
}

class PayrollSnapshotHistoryPage {
  const PayrollSnapshotHistoryPage(this.entries, {required this.hasMore});
  final List<PayrollSnapshotHistoryEntry> entries;
  final bool hasMore;
}

abstract class PayrollSnapshotHistoryReader {
  String get ownerId;
  Future<PayrollSnapshotHistoryPage> read(String accountId, DateTime month);
}

/// Read existing selection audit rows only. Never selects a new observation.
class SupabasePayrollSnapshotHistoryReader
    implements PayrollSnapshotHistoryReader {
  SupabasePayrollSnapshotHistoryReader(this.client, this.ownerId);
  final SupabaseClient client;
  @override
  final String ownerId;

  void _checkOwner() {
    if (ownerId.isEmpty || client.auth.currentUser?.id != ownerId) {
      throw StateError('ログイン状態が変わりました。画面を開き直してください。');
    }
  }

  @override
  Future<PayrollSnapshotHistoryPage> read(
    String accountId,
    DateTime month,
  ) async {
    _checkOwner();
    if (accountId.isEmpty) throw ArgumentError('給与口座が未選択です。');
    final monthKey = payrollDate(DateTime(month.year, month.month));
    final rows = await client
        .from('asset_payroll_balance_selection_history')
        .select('id,user_id,account_id,payroll_month,old_observation_id,'
            'new_observation_id,reason,changed_at')
        .eq('user_id', ownerId)
        .eq('account_id', accountId)
        .eq('payroll_month', monthKey)
        .order('id', ascending: false)
        .limit(51);
    _checkOwner();
    final visible = rows.take(50).toList();
    if (visible.isEmpty) {
      return const PayrollSnapshotHistoryPage([], hasMore: false);
    }
    final ids = visible.map((row) => row['new_observation_id'] as String).toSet();
    final observations = await client
        .from('asset_payroll_balance_observations')
        .select('id,user_id,account_id,payroll_month,balance_yen,'
            'deposit_date,source_note')
        .eq('user_id', ownerId)
        .eq('account_id', accountId)
        .eq('payroll_month', monthKey)
        .inFilter('id', ids.toList());
    _checkOwner();
    final byId = {for (final row in observations) row['id']: row};
    final entries = <PayrollSnapshotHistoryEntry>[];
    for (final row in visible) {
      final observation = byId[row['new_observation_id']];
      if (row['user_id'] != ownerId ||
          row['account_id'] != accountId ||
          row['payroll_month'] != monthKey ||
          observation == null ||
          observation['user_id'] != ownerId ||
          observation['account_id'] != accountId ||
          observation['payroll_month'] != monthKey) {
        throw StateError('履歴の対象を照合できません。再読込してください。');
      }
      final amount = observation['balance_yen'];
      if (amount is! num ||
          !amount.isFinite ||
          amount.abs() > 9007199254740991 ||
          amount != amount.roundToDouble()) {
        throw const FormatException('Unsupported payroll history balance');
      }
      entries.add(PayrollSnapshotHistoryEntry(
        id: (row['id'] as num).toInt(),
        previousId: row['old_observation_id'] as String?,
        reason: row['reason'] as String,
        changedAt: DateTime.parse(row['changed_at'] as String),
        record: PayrollSnapshotRecord(
          id: observation['id'] as String,
          ownerId: ownerId,
          accountId: accountId,
          month: DateTime(month.year, month.month),
          balanceYen: amount.toInt(),
          depositDate: DateTime.parse(observation['deposit_date'] as String),
          note: observation['source_note'] as String,
        ),
      ));
    }
    return PayrollSnapshotHistoryPage(
      List.unmodifiable(entries),
      hasMore: rows.length > 50,
    );
  }
}
