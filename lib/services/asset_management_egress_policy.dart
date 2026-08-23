abstract final class AssetManagementEgressPolicy {
  static const int assetHistoryLookbackDays = 400;
  static const int queryPageSize = 500;
  static const int maxAssetHistoryRows = 10000;
  static const int recentFlowMonthWindow = 24;
  static const int maxRecentFlowRows = 2000;
  static const int maxImportDedupRows = 10000;
  static const int maxMonthlySnapshots = 120;

  static DateTime recentFlowCutoff(DateTime now) {
    final local = now.toLocal();
    return DateTime(
      local.year,
      local.month - recentFlowMonthWindow + 1,
    ).toUtc();
  }

  static bool isMissingAssetHistoryRpcCode(String? code) {
    return code == 'PGRST202' || code == '42883';
  }

  static Future<List<T>> fetchBoundedPages<T>({
    required int maxRows,
    required Future<List<T>> Function(int from, int to) fetchPage,
    List<T>? firstPage,
    int pageSize = queryPageSize,
  }) async {
    if (maxRows < 1 || pageSize < 1) {
      throw ArgumentError('maxRows and pageSize must be positive');
    }

    final rows = <T>[];
    for (var start = 0; start <= maxRows; start += pageSize) {
      final remainingWithOverflowProbe = maxRows + 1 - start;
      final requestedRows = remainingWithOverflowProbe < pageSize
          ? remainingWithOverflowProbe
          : pageSize;
      final page = start == 0 && firstPage != null
          ? firstPage
          : await fetchPage(start, start + requestedRows - 1);
      rows.addAll(page);
      if (rows.length > maxRows) {
        throw StateError('Supabase history exceeded the safe row limit');
      }
      if (page.length < requestedRows) {
        return rows;
      }
    }
    return rows;
  }
}
