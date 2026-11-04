import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/salary_balance_history_state.dart';

void main() {
  SalaryBalanceHistoryRow row(int id, String owner, double amount) =>
      SalaryBalanceHistoryRow(
        rowId: id,
        sourceOwnerId: owner,
        accountName: 'synthetic-bank',
        recordedAt: DateTime.utc(2026, 6, 20, 9),
        amount: amount,
      );

  SalaryBalanceHistoryState seeded() {
    final state = SalaryBalanceHistoryState()..observeAuth('a');
    final token = state.beginRead('a')!;
    expect(state.acceptRead(token, currentOwnerId: 'a', rows: [row(1, 'a', 100)]), isTrue);
    return state;
  }

  test('empty owner has no read or write access', () {
    final state = SalaryBalanceHistoryState()..observeAuth(' ');
    expect(state.beginRead(' '), isNull);
    expect(state.beginMutation(' '), isNull);
    expect(state.rowsFor(' '), isNull);
  });

  test('A to B to A invalidates an old A response and clears rows', () {
    final state = seeded();
    final oldA = state.beginRead('a')!;
    final firstGeneration = state.authGeneration;
    state.observeAuth('b');
    expect(state.rowsFor('a'), isNull);
    expect(state.rowsFor('b'), isNull);
    state.observeAuth('a');
    expect(state.authGeneration, greaterThan(firstGeneration));
    expect(state.acceptRead(oldA, currentOwnerId: 'a', rows: [row(2, 'a', 200)]), isFalse);
    expect(state.rowsFor('a'), isNull);
  });

  for (final operation in ['save', 'delete']) {
    test('$operation before a pending read completes rejects the old response', () {
      final state = seeded();
      final pending = state.beginRead('a')!;
      final mutation = state.beginMutation('a')!;
      expect(state.rowsFor('a'), isNull);
      expect(state.beginRead('a'), isNull);
      expect(state.finishMutation(mutation, currentOwnerId: 'a', outcome: SalaryHistoryMutationOutcome.committed), isTrue);
      expect(state.revision, 1);
      expect(state.acceptRead(pending, currentOwnerId: 'a', rows: [row(2, 'a', 200)]), isFalse);
      expect(state.rowsFor('a'), isNull);
      final fresh = state.beginRead('a')!;
      expect(state.acceptRead(fresh, currentOwnerId: 'a', rows: [row(3, 'a', 300)]), isTrue);
      expect(state.rowsFor('a')!.single.rowId, 3);
    });
  }

  test('failed mutation retains the previous snapshot but invalidates old reads', () {
    final state = seeded();
    final mutation = state.beginMutation('a')!;
    expect(state.rowsFor('a'), isNull);
    expect(state.finishMutation(mutation, currentOwnerId: 'a', outcome: SalaryHistoryMutationOutcome.notCommitted), isTrue);
    expect(state.revision, 0);
    expect(state.rowsFor('a')!.single.amount, 100);
  });

  test('even a confirmed failed write invalidates an earlier pending read', () {
    final state = seeded();
    final pending = state.beginRead('a')!;
    final mutation = state.beginMutation('a')!;
    expect(state.finishMutation(mutation, currentOwnerId: 'a', outcome: SalaryHistoryMutationOutcome.notCommitted), isTrue);
    expect(state.acceptRead(pending, currentOwnerId: 'a', rows: [row(2, 'a', 200)]), isFalse);
    expect(state.rowsFor('a'), isNull);
  });

  test('an old owner mutation cannot modify a new session', () {
    final state = seeded();
    final oldMutation = state.beginMutation('a')!;
    state.observeAuth('b');
    final token = state.beginRead('b')!;
    expect(state.acceptRead(token, currentOwnerId: 'b', rows: [row(3, 'b', 300)]), isTrue);
    expect(state.finishMutation(oldMutation, currentOwnerId: 'b', outcome: SalaryHistoryMutationOutcome.committed), isTrue);
    expect(state.rowsFor('b')!.single.amount, 300);
    expect(state.rowsFor('a'), isNull);
    state.observeAuth('a');
    expect(state.revision, 1);
  });

  test('a completed A mutation does not invalidate an in-flight B read', () {
    final state = seeded();
    final oldMutation = state.beginMutation('a')!;
    state.observeAuth('b');
    final b = state.beginRead('b')!;
    expect(state.finishMutation(oldMutation, currentOwnerId: 'b', outcome: SalaryHistoryMutationOutcome.committed), isTrue);
    expect(state.acceptRead(b, currentOwnerId: 'b', rows: [row(3, 'b', 300)]), isTrue);
    expect(state.rowsFor('b')!.single.amount, 300);
  });

  test('newer read wins and invalid batches fail closed', () {
    final state = seeded();
    final first = state.beginRead('a')!;
    final later = state.beginRead('a')!;
    expect(state.acceptRead(first, currentOwnerId: 'a', rows: [row(2, 'a', 200)]), isFalse);
    expect(state.acceptRead(later, currentOwnerId: 'a', rows: [row(3, 'b', 300)]), isFalse);
    expect(state.rowsFor('a'), isNull);
    final duplicate = state.beginRead('a')!;
    expect(state.acceptRead(duplicate, currentOwnerId: 'a', rows: [row(4, 'a', 400), row(4, 'a', 500)]), isFalse);
    expect(state.acceptRead(duplicate, currentOwnerId: 'a', rows: [row(4, 'a', 400)]), isFalse);
    expect(state.rowsFor('a'), isNull);
  });

  test('a late older response cannot replace a newer accepted snapshot', () {
    final state = seeded();
    final first = state.beginRead('a')!;
    final later = state.beginRead('a')!;
    expect(state.acceptRead(later, currentOwnerId: 'a', rows: [row(3, 'a', 300)]), isTrue);
    expect(state.acceptRead(first, currentOwnerId: 'a', rows: [row(2, 'a', 200)]), isFalse);
    expect(state.rowsFor('a')!.single.amount, 300);
  });

  test('verified empty differs from unavailable and read tokens are single use', () {
    final state = SalaryBalanceHistoryState()..observeAuth('a');
    expect(state.rowsFor('a'), isNull);
    final token = state.beginRead('a')!;
    expect(state.acceptRead(token, currentOwnerId: 'a', rows: []), isTrue);
    expect(state.rowsFor('a'), isEmpty);
    expect(state.acceptRead(token, currentOwnerId: 'a', rows: [row(2, 'a', 200)]), isFalse);
    expect(state.rowsFor('a'), isEmpty);
  });

  test('one successful mutation invalidates the snapshot despite another failing', () {
    final state = seeded();
    final first = state.beginMutation('a')!;
    final second = state.beginMutation('a')!;
    expect(state.finishMutation(first, currentOwnerId: 'a', outcome: SalaryHistoryMutationOutcome.committed), isTrue);
    expect(state.rowsFor('a'), isNull);
    expect(state.finishMutation(second, currentOwnerId: 'a', outcome: SalaryHistoryMutationOutcome.notCommitted), isTrue);
    expect(state.rowsFor('a'), isNull);
    expect(state.revision, 1);
  });

  test('unknown write outcome blocks reads until the operation is resolved', () {
    final state = seeded();
    final mutation = state.beginMutation('a')!;
    expect(state.finishMutation(mutation, currentOwnerId: 'a', outcome: SalaryHistoryMutationOutcome.unknown), isTrue);
    expect(state.revision, 0);
    expect(state.rowsFor('a'), isNull);
    expect(state.beginRead('a'), isNull);
    // Only an authoritative completion outcome may clear the pending write.
    expect(state.finishMutation(mutation, currentOwnerId: 'a', outcome: SalaryHistoryMutationOutcome.committed), isTrue);
    expect(state.revision, 1);
    final fresh = state.beginRead('a')!;
    expect(state.acceptRead(fresh, currentOwnerId: 'a', rows: [row(2, 'a', 200)]), isTrue);
    expect(state.rowsFor('a')!.single.amount, 200);
  });

  test('uncertain A write survives A to B to A until authoritative resolution', () {
    final state = seeded();
    final mutation = state.beginMutation('a')!;
    expect(state.finishMutation(mutation, currentOwnerId: 'a', outcome: SalaryHistoryMutationOutcome.unknown), isTrue);
    state.observeAuth('b');
    final b = state.beginRead('b')!;
    expect(state.acceptRead(b, currentOwnerId: 'b', rows: [row(3, 'b', 300)]), isTrue);
    state.observeAuth('a');
    expect(state.beginRead('a'), isNull);
    expect(state.rowsFor('a'), isNull);
    expect(state.finishMutation(mutation, currentOwnerId: 'a', outcome: SalaryHistoryMutationOutcome.notCommitted), isTrue);
    final fresh = state.beginRead('a')!;
    expect(state.acceptRead(fresh, currentOwnerId: 'a', rows: [row(2, 'a', 200)]), isTrue);
    expect(state.rowsFor('a')!.single.amount, 200);
  });

  test('a pending write still blocks its owner after switching away and back', () {
    final state = seeded();
    final mutation = state.beginMutation('a')!;
    state.observeAuth('b');
    expect(state.beginRead('b'), isNotNull);
    state.observeAuth('a');
    expect(state.beginRead('a'), isNull);
    expect(state.finishMutation(mutation, currentOwnerId: 'a', outcome: SalaryHistoryMutationOutcome.committed), isTrue);
    expect(state.beginRead('a'), isNotNull);
  });

  test('an owned write can complete while signed out without exposing rows', () {
    final state = seeded();
    final mutation = state.beginMutation('a')!;
    state.observeAuth(null);
    expect(state.finishMutation(mutation, currentOwnerId: null, outcome: SalaryHistoryMutationOutcome.committed), isTrue);
    expect(state.rowsFor(null), isNull);
    state.observeAuth('a');
    expect(state.revision, 1);
    expect(state.rowsFor('a'), isNull);
    expect(state.beginRead('a'), isNotNull);
  });

  test('tokens from a different state instance cannot settle a pending write', () {
    final first = seeded();
    final second = seeded();
    final firstRead = first.beginRead('a')!;
    final secondRead = second.beginRead('a')!;
    expect(second.acceptRead(firstRead, currentOwnerId: 'a', rows: [row(5, 'a', 500)]), isFalse);
    expect(second.acceptRead(secondRead, currentOwnerId: 'a', rows: [row(6, 'a', 600)]), isTrue);
    final firstMutation = first.beginMutation('a')!;
    final secondMutation = second.beginMutation('a')!;
    expect(second.finishMutation(firstMutation, currentOwnerId: 'a', outcome: SalaryHistoryMutationOutcome.notCommitted), isFalse);
    expect(second.beginRead('a'), isNull);
    expect(second.finishMutation(secondMutation, currentOwnerId: 'a', outcome: SalaryHistoryMutationOutcome.notCommitted), isTrue);
    expect(second.rowsFor('a')!.single.amount, 600);
  });

  test('separate instances do not share the pending ledger (integration gap)', () {
    final first = seeded();
    final mutation = first.beginMutation('a')!;
    expect(first.finishMutation(mutation, currentOwnerId: 'a', outcome: SalaryHistoryMutationOutcome.unknown), isTrue);
    expect(first.beginRead('a'), isNull);

    // Characterizes a limitation, not a safety guarantee: a page recreation
    // must use a longer-lived owner coordinator or prove write quiescence.
    final recreated = SalaryBalanceHistoryState()..observeAuth('a');
    expect(recreated.beginRead('a'), isNotNull);
  });

  test('a failed refresh does not expose an old snapshot', () {
    final state = seeded();
    final token = state.beginRead('a')!;
    Iterable<SalaryBalanceHistoryRow> brokenRows() sync* {
      yield row(2, 'a', 200);
      throw StateError('synthetic decoding failure');
    }
    expect(() => state.acceptRead(token, currentOwnerId: 'a', rows: brokenRows()), throwsStateError);
    expect(state.rowsFor('a'), isNull);
    expect(state.acceptRead(token, currentOwnerId: 'a', rows: []), isFalse);
  });

  test('same-time distinct rows survive and snapshots cannot be mutated', () {
    final state = SalaryBalanceHistoryState()..observeAuth('a');
    final token = state.beginRead('a')!;
    expect(state.acceptRead(token, currentOwnerId: 'a', rows: [row(1, 'a', 200), row(2, 'a', 100)]), isTrue);
    final rows = state.rowsFor('a')!;
    expect(rows.map((item) => item.rowId), [1, 2]);
    expect(() => rows.clear(), throwsUnsupportedError);
    expect(state.rowsFor('a')!.length, 2);
  });
}
