/// Resolves a legacy payment-day override in the same order as the planner.
int? resolveAssetDebtPaymentDayOverride({
  required Map<String, int> overrides,
  required String accountId,
  required String accountName,
}) {
  final day =
      overrides[accountId] ??
      overrides[accountName.trim()] ??
      overrides[accountName];
  if (day == null || day < 1 || day > 31) return null;
  return day;
}

/// Whether removing the ID key would expose a valid name-keyed override.
bool hasAssetDebtLegacyNameOverride({
  required Map<String, int> overrides,
  required String accountId,
  required String accountName,
}) {
  final withoutId = Map<String, int>.from(overrides)..remove(accountId);
  return resolveAssetDebtPaymentDayOverride(
        overrides: withoutId,
        accountId: accountId,
        accountName: accountName,
      ) !=
      null;
}
