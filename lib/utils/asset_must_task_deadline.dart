/// The task form exposes a local calendar date, not a time of day.
DateTime assetMustTaskDate(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// A date-only deadline is overdue starting on the following local day.
bool isAssetMustTaskOverdue({
  required DateTime deadline,
  required DateTime now,
  required bool isCompleted,
}) {
  return !isCompleted &&
      assetMustTaskDate(deadline).isBefore(assetMustTaskDate(now));
}
