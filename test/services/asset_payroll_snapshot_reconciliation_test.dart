import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_payroll_snapshot_store.dart';

void main() {
  const ownerId = 'aaaaaaaa-0000-0000-0000-000000000001';
  const accountId = 'aaaaaaaa-1111-1111-1111-111111111111';
  const requestId = 'aaaaaaaa-2222-2222-2222-222222222222';
  const previousId = 'aaaaaaaa-3333-3333-3333-333333333333';
  final draft = PayrollSnapshotDraft(
    accountId: accountId,
    month: DateTime(2020, 1),
    depositDate: DateTime(2020, 1, 25),
    balanceYen: 120000,
    note: 'synthetic source',
    reason: 'synthetic correction',
    requestId: requestId,
    previousId: previousId,
  );
  final matching = <String, dynamic>{
    'id': 'aaaaaaaa-4444-4444-4444-444444444444',
    'user_id': ownerId,
    'request_id': requestId,
    'account_id': accountId,
    'payroll_month': '2020-01-01',
    'deposit_reference': 'owner-confirmation:$requestId',
    'deposit_date': '2020-01-25',
    'date_precision': 'day',
    'deposited_at': null,
    'observed_at': null,
    'balance_yen': 120000,
    'source_note': 'synthetic source',
    'selection_reason': 'synthetic correction',
    'expected_previous_id': previousId,
    'evidence_kind': 'owner_confirmed_at_deposit',
    'confirmation_version': 'immediate-balance-v1',
  };

  test('complete matching owner-bound record is accepted', () {
    expect(
      payrollObservationMatchesDraft(matching, draft, ownerId),
      isTrue,
    );
  });

  test('initial observation accepts only an explicit null predecessor', () {
    final initial = PayrollSnapshotDraft(
      accountId: accountId,
      month: DateTime(2020, 1),
      depositDate: DateTime(2020, 1, 25),
      balanceYen: 120000,
      note: 'synthetic source',
      reason: 'synthetic correction',
      requestId: requestId,
      previousId: null,
    );
    final firstRecord = <String, dynamic>{
      ...matching,
      'expected_previous_id': null,
    };
    expect(
      payrollObservationMatchesDraft(firstRecord, initial, ownerId),
      isTrue,
    );
    expect(
      payrollObservationMatchesDraft(matching, initial, ownerId),
      isFalse,
    );
  });

  test('every conflicting payload field is rejected', () {
    final conflicts = <String, dynamic>{
      'user_id': 'bbbbbbbb-0000-0000-0000-000000000002',
      'request_id': 'bbbbbbbb-2222-2222-2222-222222222222',
      'account_id': 'bbbbbbbb-1111-1111-1111-111111111111',
      'payroll_month': '2020-02-01',
      'deposit_reference': 'synthetic-other-reference',
      'deposit_date': '2020-01-26',
      'date_precision': 'instant',
      'deposited_at': '2020-01-25T00:00:00Z',
      'observed_at': '2020-01-25T00:01:00Z',
      'balance_yen': 120001,
      'source_note': 'synthetic other source',
      'selection_reason': 'synthetic other reason',
      'expected_previous_id': null,
      'evidence_kind': 'bank_verified',
      'confirmation_version': 'other-version',
    };
    for (final entry in conflicts.entries) {
      final row = <String, dynamic>{...matching, entry.key: entry.value};
      expect(
        payrollObservationMatchesDraft(row, draft, ownerId),
        isFalse,
        reason: 'Conflicting ${entry.key} must not reconcile a request.',
      );
    }
  });

  test('a missing field is not equivalent to an explicit null', () {
    for (final key in matching.keys) {
      final row = Map<String, dynamic>.of(matching)..remove(key);
      expect(
        payrollObservationMatchesDraft(row, draft, ownerId),
        isFalse,
        reason: 'Missing $key must not reconcile a request.',
      );
    }
  });
}
