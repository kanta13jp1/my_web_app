import 'package:flutter_test/flutter_test.dart';
// Synthetic standalone cases: no network, storage, or IDs/names in logs.
import 'package:my_web_app/services/asset_debt_id_conflict.dart';

void check(bool value, String label) {
  if (!value) throw StateError('synthetic case failed: $label');
}

void runSyntheticIdCases() {
  const non = DebtKind.nonRevolving;
  const rev = DebtKind.revolving;
  const complete = SnapshotState.complete;
  final input = <DebtRowIdentity>[
    const DebtRowIdentity(id: 'a', name: 'first', kind: non),
    const DebtRowIdentity(id: 'b', name: 'second', kind: non),
    const DebtRowIdentity(id: 'a', name: 'third', kind: non),
    const DebtRowIdentity(id: 'c', name: 'fourth', kind: non),
  ];
  final snapshot = List<DebtRowIdentity>.of(input);
  final found = inspectDebtRowIds(input, snapshotState: complete);
  check(
      found.rows[0].concerns.contains(IdConcern.exactDuplicate) &&
          found.rows[2].concerns.contains(IdConcern.exactDuplicate),
      'duplicate-all-rows');
  check(
      found.rows[1].concerns.isEmpty &&
          found.rows[3].concerns.isEmpty &&
          !found.ownershipVerified,
      'independent-row');
  check(identical(input[0], snapshot[0]) && input.length == snapshot.length,
      'input-unchanged');
  final mixed = inspectDebtRowIds([
    const DebtRowIdentity(id: 'x', name: 'first', kind: rev),
    const DebtRowIdentity(id: 'x', name: 'second', kind: non),
  ], snapshotState: complete);
  check(mixed.rows.every((r) => r.concerns.contains(IdConcern.exactDuplicate)),
      'mixed-kind');
  final whitespace = inspectDebtRowIds([
    const DebtRowIdentity(id: 'x', name: 'first', kind: rev),
    const DebtRowIdentity(id: ' x ', name: 'second', kind: non),
  ], snapshotState: complete);
  check(
      whitespace.rows.every(
              (r) => r.concerns.contains(IdConcern.normalizedCollision)) &&
          whitespace.rows
              .every((r) => !r.concerns.contains(IdConcern.exactDuplicate)),
      'trim-id-collision');
  final sameName = inspectDebtRowIds([
    const DebtRowIdentity(id: 'x', name: 'same', kind: rev),
    const DebtRowIdentity(id: 'y', name: 'same', kind: non),
  ], snapshotState: complete);
  check(
      sameName.rows.every((r) => r.concerns.contains(IdConcern.duplicateName)),
      'same-name');
  final trimName = inspectDebtRowIds([
    const DebtRowIdentity(id: 'x', name: ' same ', kind: rev),
    const DebtRowIdentity(id: 'y', name: 'same', kind: non),
  ], snapshotState: complete);
  check(
      trimName.rows.every((r) => r.concerns.contains(IdConcern.duplicateName)),
      'trim-name');
  final crossRows = [
    const DebtRowIdentity(id: 'custom_a', name: 'a', kind: non),
    const DebtRowIdentity(id: 'custom_custom_a', name: ' custom_a ', kind: non),
  ];
  for (final rows in [crossRows, crossRows.reversed.toList()]) {
    final cross = inspectDebtRowIds(rows, snapshotState: complete);
    check(cross.rows.every((r) => r.concerns.contains(IdConcern.idNameCross)),
        'cross-both-orders');
  }
  final twoWay = inspectDebtRowIds([
    const DebtRowIdentity(id: 'x', name: 'y', kind: rev),
    const DebtRowIdentity(id: 'y', name: 'x', kind: non),
  ], snapshotState: complete);
  check(twoWay.rows.every((r) => r.concerns.contains(IdConcern.idNameCross)),
      'two-way-cross');
  final self = inspectDebtRowIds([
    const DebtRowIdentity(id: 'x', name: ' x ', kind: non),
  ], snapshotState: complete);
  check(
      !self.rows.single.concerns.contains(IdConcern.idNameCross) &&
          !self.ownershipVerified,
      'self-not-cross');
  final selfAndOther = inspectDebtRowIds([
    const DebtRowIdentity(id: 'x', name: 'x', kind: non),
    const DebtRowIdentity(id: 'y', name: 'x', kind: non),
  ], snapshotState: complete);
  check(
      selfAndOther.rows.every((r) =>
          r.concerns.contains(IdConcern.idNameCross) &&
          r.concerns.contains(IdConcern.duplicateName)),
      'self-plus-other');
  final blank = inspectDebtRowIds([
    const DebtRowIdentity(id: ' ', name: 'first', kind: non),
    const DebtRowIdentity(id: 'x', name: 'second', kind: non),
  ], snapshotState: complete);
  check(
      blank.rows.first.concerns.contains(IdConcern.blankId) &&
          blank.rows.last.concerns.contains(IdConcern.blankIdElsewhere),
      'blank-id');
  final blankName = inspectDebtRowIds([
    const DebtRowIdentity(id: 'x', name: ' ', kind: non),
    const DebtRowIdentity(id: 'y', name: 'second', kind: non),
  ], snapshotState: complete);
  check(
      blankName.rows.first.concerns.contains(IdConcern.blankName) &&
          blankName.rows.last.concerns.contains(IdConcern.blankNameElsewhere),
      'blank-name');
  final unknown = inspectDebtRowIds([
    const DebtRowIdentity(id: 'x', name: 'first', kind: DebtKind.unknown),
  ], snapshotState: complete);
  check(unknown.rows.single.concerns.contains(IdConcern.unknownKind),
      'unknown-kind');
  for (final state in [SnapshotState.incomplete, SnapshotState.unavailable]) {
    final report = inspectDebtRowIds(
        [const DebtRowIdentity(id: 'x', name: 'first', kind: non)],
        snapshotState: state);
    check(report.rows.single.concerns.contains(IdConcern.incompleteSnapshot),
        'snapshot-not-complete');
  }
  final empty = inspectDebtRowIds([], snapshotState: complete);
  final absent =
      inspectDebtRowIds([], snapshotState: SnapshotState.unavailable);
  check(
      empty.rows.isEmpty &&
          empty.snapshotState != absent.snapshotState &&
          !empty.ownershipVerified,
      'empty-not-unavailable');
  final reverse =
      inspectDebtRowIds(input.reversed.toList(), snapshotState: complete);
  check(
      reverse.rows[0].concerns.isEmpty &&
          reverse.rows[1].concerns.contains(IdConcern.exactDuplicate) &&
          reverse.rows[2].concerns.isEmpty &&
          reverse.rows[3].concerns.contains(IdConcern.exactDuplicate),
      'order');
  final maxRows = List<DebtRowIdentity>.filled(
      1024, const DebtRowIdentity(id: 'x', name: 'y', kind: non));
  check(!inspectDebtRowIds(maxRows, snapshotState: complete).wasTruncated,
      'row-boundary');
  final tooMany =
      inspectDebtRowIds([...maxRows, maxRows.first], snapshotState: complete);
  check(
      tooMany.limit == ScanLimit.rowCount && tooMany.rows.isEmpty, 'row-limit');
  final exactLength = inspectDebtRowIds(
      [DebtRowIdentity(id: 'x' * 2048, name: 'n', kind: non)],
      snapshotState: complete);
  check(!exactLength.wasTruncated, 'id-length-boundary');
  final tooLong = inspectDebtRowIds(
      [DebtRowIdentity(id: 'x' * 2049, name: 'n', kind: non)],
      snapshotState: complete);
  check(tooLong.limit == ScanLimit.individualIdLength && tooLong.rows.isEmpty,
      'id-length-limit');
  final tooLongName = inspectDebtRowIds(
      [DebtRowIdentity(id: 'x', name: 'n' * 2049, kind: non)],
      snapshotState: complete);
  check(
      tooLongName.limit == ScanLimit.individualNameLength &&
          tooLongName.rows.isEmpty,
      'name-length-limit');
  final totalBoundary = inspectDebtRowIds(
      List<DebtRowIdentity>.generate(32,
          (_) => DebtRowIdentity(id: 'x' * 1024, name: 'y' * 1024, kind: non)),
      snapshotState: complete);
  check(!totalBoundary.wasTruncated, 'total-length-boundary');
  final totalLimit = inspectDebtRowIds(
      List<DebtRowIdentity>.generate(33,
          (_) => DebtRowIdentity(id: 'x' * 1024, name: 'y' * 1024, kind: non)),
      snapshotState: complete);
  check(
      totalLimit.limit == ScanLimit.totalFieldLength && totalLimit.rows.isEmpty,
      'total-length-limit');
  final blankIncomplete = inspectDebtRowIds([
    const DebtRowIdentity(id: '', name: '', kind: non),
  ], snapshotState: SnapshotState.incomplete);
  check(
      blankIncomplete.rows.single.concerns.contains(IdConcern.blankId) &&
          blankIncomplete.rows.single.concerns.contains(IdConcern.blankName) &&
          blankIncomplete.rows.single.concerns
              .contains(IdConcern.incompleteSnapshot),
      'blank-incomplete');
}

void main() {
  test('synthetic debt identities fail closed when ambiguous',
      runSyntheticIdCases);
}
