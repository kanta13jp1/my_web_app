abstract final class AssetManagementEgressPolicy {
  static const int assetHistoryLookbackDays = 400;
  static const int queryPageSize = 500;
  static const int recentFlowMonthWindow = 24;
  static const int maxRecentFlowRows = 2000;
  static const int maxMonthlySnapshots = 120;

  static DateTime recentFlowCutoff(DateTime now) {
    final utc = now.toUtc();
    return DateTime.utc(utc.year, utc.month - recentFlowMonthWindow + 1);
  }
}
