import 'package:supabase_flutter/supabase_flutter.dart';

String payrollDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class PayrollSnapshotAccount {
  const PayrollSnapshotAccount(this.id, this.label);
  final String id;
  final String label;
}

class PayrollSnapshotRecord {
  const PayrollSnapshotRecord({
    required this.id,
    required this.balanceYen,
    required this.depositDate,
    required this.note,
  });
  final String id;
  final int balanceYen;
  final DateTime depositDate;
  final String note;
}

class PayrollSnapshotDraft {
  const PayrollSnapshotDraft({
    required this.accountId,
    required this.month,
    required this.depositDate,
    required this.balanceYen,
    required this.note,
    required this.reason,
    required this.requestId,
    required this.previousId,
  });
  final String accountId;
  final DateTime month;
  final DateTime depositDate;
  final int balanceYen;
  final String note;
  final String reason;
  final String requestId;
  final String? previousId;

  Map<String, dynamic> toRpc() => {
        'p_account_id': accountId,
        'p_payroll_month': payrollDate(DateTime(month.year, month.month)),
        'p_deposit_reference': 'owner-confirmation:$requestId',
        'p_deposit_date': payrollDate(depositDate),
        'p_date_precision': 'day',
        'p_deposited_at': null,
        'p_observed_at': null,
        'p_balance_yen': balanceYen,
        'p_source_note': note,
        'p_request_id': requestId,
        'p_expected_previous_id': previousId,
        'p_reason': reason,
        'p_confirm_immediate': true,
      };
}

abstract class PayrollSnapshotStore {
  Future<List<PayrollSnapshotAccount>> accounts();
  Future<void> createAccount(String label);
  Future<PayrollSnapshotRecord?> selected(String accountId, DateTime month);
  Future<PayrollSnapshotRecord?> byRequest(PayrollSnapshotDraft draft);
  Future<void> confirm(PayrollSnapshotDraft draft);
}

/// Owner-bound storage. Does not alter current balances or financial flows.
class SupabasePayrollSnapshotStore implements PayrollSnapshotStore {
  SupabasePayrollSnapshotStore(this.client, this.ownerId);
  final SupabaseClient client;
  final String ownerId;

  void _checkOwner() {
    if (ownerId.isEmpty || client.auth.currentUser?.id != ownerId) {
      throw StateError('ログイン状態が変わりました。画面を開き直してください。');
    }
  }

  @override
  Future<List<PayrollSnapshotAccount>> accounts() async {
    _checkOwner();
    final rows = await client.from('asset_payroll_accounts')
        .select('id,display_label').eq('user_id', ownerId)
        .eq('archived', false).order('display_label');
    _checkOwner();
    return [for (final row in rows)
      PayrollSnapshotAccount(row['id'] as String, row['display_label'] as String)];
  }

  @override
  Future<void> createAccount(String label) async {
    _checkOwner();
    if (label.trim().isEmpty || label.trim().length > 120) {
      throw ArgumentError('口座の呼び名は1〜120文字です。');
    }
    await client.from('asset_payroll_accounts').insert({
      'user_id': ownerId, 'display_label': label.trim(),
    });
    _checkOwner();
  }

  PayrollSnapshotRecord _record(Map<String, dynamic> row) => PayrollSnapshotRecord(
    id: row['id'] as String,
    balanceYen: (row['balance_yen'] as num).toInt(),
    depositDate: DateTime.parse(row['deposit_date'] as String),
    note: row['source_note'] as String,
  );

  @override
  Future<PayrollSnapshotRecord?> selected(String accountId, DateTime month) async {
    _checkOwner();
    final selection = await client.from('asset_payroll_balance_selections')
        .select('observation_id').eq('user_id', ownerId)
        .eq('account_id', accountId)
        .eq('payroll_month', payrollDate(DateTime(month.year, month.month)))
        .maybeSingle();
    _checkOwner();
    if (selection == null) return null;
    final row = await client.from('asset_payroll_balance_observations')
        .select('id,balance_yen,deposit_date,source_note')
        .eq('user_id', ownerId).eq('id', selection['observation_id'])
        .eq('account_id', accountId).maybeSingle();
    _checkOwner();
    return row == null ? null : _record(row);
  }

  @override
  Future<PayrollSnapshotRecord?> byRequest(PayrollSnapshotDraft draft) async {
    _checkOwner();
    final row = await client.from('asset_payroll_balance_observations')
        .select('id,balance_yen,deposit_date,source_note,account_id,payroll_month,selection_reason,expected_previous_id')
        .eq('user_id', ownerId).eq('request_id', draft.requestId).maybeSingle();
    _checkOwner();
    if (row == null) return null;
    if (row['account_id'] != draft.accountId ||
        row['payroll_month'] != payrollDate(DateTime(draft.month.year, draft.month.month)) ||
        row['deposit_date'] != payrollDate(draft.depositDate) ||
        row['balance_yen'] != draft.balanceYen || row['source_note'] != draft.note ||
        row['selection_reason'] != draft.reason ||
        row['expected_previous_id'] != draft.previousId) {
      throw StateError('保存内容が一致しません。再登録せず確認してください。');
    }
    return _record(row);
  }

  @override
  Future<void> confirm(PayrollSnapshotDraft draft) async {
    _checkOwner();
    if (draft.note.trim().isEmpty || draft.note.length > 300 ||
        draft.reason.trim().isEmpty || draft.reason.length > 300) {
      throw ArgumentError('確認資料メモと理由は1〜300文字です。');
    }
    await client.rpc('confirm_payroll_balance_observation', params: draft.toRpc());
    _checkOwner();
  }
}
