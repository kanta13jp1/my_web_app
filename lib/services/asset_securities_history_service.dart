import '../models/asset_liability_workbook.dart';

/// 証券評価額の時系列 1 点。
class AssetSecuritiesPoint {
  /// `yyyy-MM` 形式。
  final String monthKey;

  /// その月末時点の証券評価額合計。
  final double securitiesTotal;

  const AssetSecuritiesPoint({
    required this.monthKey,
    required this.securitiesTotal,
  });

  int get year => int.tryParse(monthKey.split('-').first) ?? 0;
}

/// 投資評価額の推移 (#2469 の土台) 。
class AssetSecuritiesHistory {
  /// monthKey 昇順。**追跡済み (非 null) の月だけ**を含む。
  final List<AssetSecuritiesPoint> points;

  /// 評価額が未追跡だった月数 (= グラフに描けない月)。
  final int untrackedMonthCount;

  const AssetSecuritiesHistory({
    required this.points,
    required this.untrackedMonthCount,
  });

  static const AssetSecuritiesHistory empty = AssetSecuritiesHistory(
    points: <AssetSecuritiesPoint>[],
    untrackedMonthCount: 0,
  );

  bool get hasData => points.isNotEmpty;

  /// 折れ線として意味を持つ点数があるか。
  bool get hasSeries => points.length >= 2;

  /// 未追跡の月が混ざっているか (UI の注意書き用)。
  bool get hasUntrackedMonths => untrackedMonthCount > 0;

  double? get latest => points.isEmpty ? null : points.last.securitiesTotal;

  double? get earliest => points.isEmpty ? null : points.first.securitiesTotal;

  /// 期間内の増減額。点が 2 未満なら null。
  double? get changeAmount {
    if (!hasSeries) return null;
    return points.last.securitiesTotal - points.first.securitiesTotal;
  }
}

/// 投資評価額推移グラフ (#2469) が参照する期間。
enum AssetSecuritiesRange {
  oneYear(12),
  threeYears(36),
  lifetime(null);

  const AssetSecuritiesRange(this.months);

  /// 遡る月数。null は全期間。
  final int? months;
}

/// 月次スナップショットから証券評価額の時系列を組み立てる純サービス。
///
/// 金額はすべてローカルで deterministic に扱い、AI は関与しない。
///
/// **未追跡 (null) の月は 0 円へ落とさず、点そのものを作らない。**
/// 0 円に落とすと「保有していたはずの資産が消えた」ように見え、下落を捏造して
/// しまうため ([AssetLiabilityMonthlySnapshot.securitiesTotal] の doc 参照)。
class AssetSecuritiesHistoryService {
  const AssetSecuritiesHistoryService();

  /// [snapshots] から時系列を構築する。
  ///
  /// [currentMonthSnapshot] は同一 monthKey の履歴より優先する (ライブの当月)。
  /// [range] で遡る期間を絞る。[asOf] は期間計算の基準 (既定は最新月)。
  AssetSecuritiesHistory build({
    required List<AssetLiabilityMonthlySnapshot> snapshots,
    AssetLiabilityMonthlySnapshot? currentMonthSnapshot,
    AssetSecuritiesRange range = AssetSecuritiesRange.lifetime,
    DateTime? asOf,
  }) {
    final byMonth = <String, AssetLiabilityMonthlySnapshot>{};
    for (final s in snapshots) {
      final key = s.monthKey.trim();
      if (key.isEmpty) continue;
      byMonth[key] = s;
    }
    if (currentMonthSnapshot != null) {
      final key = currentMonthSnapshot.monthKey.trim();
      if (key.isNotEmpty) byMonth[key] = currentMonthSnapshot;
    }
    if (byMonth.isEmpty) return AssetSecuritiesHistory.empty;

    final keys = byMonth.keys.toList()..sort();

    // 期間の下限を決める。基準は asOf、無ければ最新月。
    String? windowStartKey;
    final months = range.months;
    if (months != null) {
      final base = asOf ?? _parseMonthKey(keys.last);
      if (base != null) {
        windowStartKey = _formatMonthKey(
          DateTime(base.year, base.month - (months - 1)),
        );
      }
    }

    final points = <AssetSecuritiesPoint>[];
    var untracked = 0;
    for (final key in keys) {
      if (windowStartKey != null && key.compareTo(windowStartKey) < 0) {
        continue;
      }
      final total = byMonth[key]!.securitiesTotal;
      if (total == null) {
        untracked += 1; // 未追跡は点を作らない。
        continue;
      }
      points.add(AssetSecuritiesPoint(monthKey: key, securitiesTotal: total));
    }

    return AssetSecuritiesHistory(
      points: points,
      untrackedMonthCount: untracked,
    );
  }

  static DateTime? _parseMonthKey(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length < 2) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null) return null;
    return DateTime(y, m);
  }

  static String _formatMonthKey(DateTime date) {
    final normalized = DateTime(date.year, date.month);
    return '${normalized.year}-${normalized.month.toString().padLeft(2, '0')}';
  }
}
