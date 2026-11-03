/// Pure identity collision detector. It performs no I/O and proves no owner.
const int maxDebtIdentityRows = 1024;

enum DebtKind { revolving, nonRevolving, unknown }

enum SnapshotState { complete, incomplete, unavailable }

enum IdConcern {
  exactDuplicate,
  normalizedCollision,
  blankId,
  blankIdElsewhere,
  duplicateName,
  idNameCross,
  blankName,
  blankNameElsewhere,
  unknownKind,
  incompleteSnapshot,
}

enum ScanLimit {
  rowCount,
  individualIdLength,
  individualNameLength,
  totalFieldLength
}

class DebtRowIdentity {
  const DebtRowIdentity({
    required this.id,
    required this.name,
    required this.kind,
  });
  final String id;
  final String name;
  final DebtKind kind;
}

class IdObservation {
  IdObservation._(Iterable<IdConcern> concerns)
      : concerns = Set.unmodifiable(concerns);
  final Set<IdConcern> concerns;
  // Absence of an ID concern is not a permission or ownership assertion.
  bool get ownershipVerified => false;
}

class IdScan {
  IdScan._({
    required this.snapshotState,
    required this.limit,
    required Iterable<IdObservation> rows,
  }) : rows = List.unmodifiable(rows);
  final SnapshotState snapshotState;
  final ScanLimit? limit;
  final List<IdObservation> rows;
  bool get wasTruncated => limit != null;
  bool get ownershipVerified => false;
}

/// [allRows] must be the full unfiltered workbook snapshot. The caller's
/// snapshotState is not independently verified. This result must never be used
/// to authorize persistence, synchronization, or a stale UI callback.
IdScan inspectDebtRowIds(
  List<DebtRowIdentity> allRows, {
  required SnapshotState snapshotState,
}) {
  IdScan limited(ScanLimit reason) => IdScan._(
        snapshotState: snapshotState,
        limit: reason,
        rows: const [],
      );
  if (allRows.length > maxDebtIdentityRows) return limited(ScanLimit.rowCount);
  var totalChars = 0;
  for (final row in allRows) {
    if (row.id.length > 2048) return limited(ScanLimit.individualIdLength);
    if (row.name.length > 2048) return limited(ScanLimit.individualNameLength);
    totalChars += row.id.length + row.name.length;
    if (totalChars > 65536) return limited(ScanLimit.totalFieldLength);
  }

  final exactCounts = <String, int>{};
  final normalizedCounts = <String, int>{};
  final normalizedNames = <String, int>{};
  var hasBlank = false;
  var hasBlankName = false;
  for (final row in allRows) {
    final normalized = row.id.trim();
    final normalizedName = row.name.trim();
    if (normalizedName.isEmpty) {
      hasBlankName = true;
    } else {
      normalizedNames[normalizedName] =
          (normalizedNames[normalizedName] ?? 0) + 1;
    }
    if (normalized.isEmpty) {
      hasBlank = true;
      continue;
    }
    exactCounts[row.id] = (exactCounts[row.id] ?? 0) + 1;
    normalizedCounts[normalized] = (normalizedCounts[normalized] ?? 0) + 1;
  }
  final observed = <IdObservation>[];
  for (final row in allRows) {
    final normalized = row.id.trim();
    final normalizedName = row.name.trim();
    final concerns = <IdConcern>{};
    if (snapshotState != SnapshotState.complete) {
      concerns.add(IdConcern.incompleteSnapshot);
    }
    if (normalized.isEmpty) {
      concerns.add(IdConcern.blankId);
    } else {
      if (hasBlank) concerns.add(IdConcern.blankIdElsewhere);
      if ((exactCounts[row.id] ?? 0) > 1) {
        concerns.add(IdConcern.exactDuplicate);
      }
      if ((normalizedCounts[normalized] ?? 0) > (exactCounts[row.id] ?? 0)) {
        concerns.add(IdConcern.normalizedCollision);
      }
    }
    if (normalizedName.isEmpty) {
      concerns.add(IdConcern.blankName);
    } else {
      if (hasBlankName) concerns.add(IdConcern.blankNameElsewhere);
      if ((normalizedNames[normalizedName] ?? 0) > 1) {
        concerns.add(IdConcern.duplicateName);
      }
    }
    // Compare other rows only. Trimming is a conservative superset of the
    // different raw/trimmed legacy and ID lookup paths.
    if (normalized.isNotEmpty && normalizedName.isNotEmpty) {
      final otherNamesMatchingId = (normalizedNames[normalized] ?? 0) -
          (normalizedName == normalized ? 1 : 0);
      final otherIdsMatchingName = (normalizedCounts[normalizedName] ?? 0) -
          (normalized == normalizedName ? 1 : 0);
      if (otherNamesMatchingId > 0 || otherIdsMatchingName > 0) {
        concerns.add(IdConcern.idNameCross);
      }
    }
    if (row.kind == DebtKind.unknown) concerns.add(IdConcern.unknownKind);
    observed.add(IdObservation._(concerns));
  }
  return IdScan._(snapshotState: snapshotState, limit: null, rows: observed);
}
