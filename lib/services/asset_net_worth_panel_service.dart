import '../models/asset_liability_workbook.dart';

/// スパークライン 1 点分の純資産。
class AssetNetWorthPoint {
  /// `yyyy-MM` 形式。
  final String monthKey;
  final double netWorth;

  const AssetNetWorthPoint({required this.monthKey, required this.netWorth});
}

/// 純資産パネル (Issue #2473) の集計結果。
///
/// 「資産合計 − 負債合計 = 純資産」「前月比 ±¥ / ±%」「直近 N 月のスパークライン」
/// を 1 つにまとめる。
class AssetNetWorthPanel {
  /// 最新月の純資産。データが無ければ null。
  final double? netWorth;

  /// 最新月の資産合計 / 負債合計 (内訳表示用)。
  final double? positiveAssetTotal;
  final double? liabilityTotal;

  /// 最新月の monthKey。
  final String? monthKey;

  /// 前月の純資産。前月データが無ければ null。
  final double? previousNetWorth;

  /// 前月比 (±¥)。前月データが無ければ null。
  final double? deltaAmount;

  /// 前月比 (±%)。**前月が正の値のときだけ**算出する。
  ///
  /// 前月が 0 だと除算不能、負だと符号の意味が反転する
  /// (例: -100万 → -50万 は改善だが比率計算では -50% と出て誤読される)。
  /// そうした場合は null を返し、UI 側は「—」を出して ±¥ のみで判断させる。
  final double? deltaPercent;

  /// スパークライン用の系列 (monthKey 昇順 / 最大 [AssetNetWorthPanelService.sparklineMonths] 件)。
  final List<AssetNetWorthPoint> sparkline;

  const AssetNetWorthPanel({
    required this.netWorth,
    required this.positiveAssetTotal,
    required this.liabilityTotal,
    required this.monthKey,
    required this.previousNetWorth,
    required this.deltaAmount,
    required this.deltaPercent,
    required this.sparkline,
  });

  static const AssetNetWorthPanel empty = AssetNetWorthPanel(
    netWorth: null,
    positiveAssetTotal: null,
    liabilityTotal: null,
    monthKey: null,
    previousNetWorth: null,
    deltaAmount: null,
    deltaPercent: null,
    sparkline: <AssetNetWorthPoint>[],
  );

  bool get hasData => netWorth != null;

  bool get hasDelta => deltaAmount != null;

  bool get hasDeltaPercent => deltaPercent != null;

  /// 前月比がプラス (据え置き含む)。delta が無い場合は false。
  bool get isImproved => (deltaAmount ?? 0) >= 0 && hasDelta;

  /// スパークラインを描画するに足る点数があるか。
  bool get hasSparkline => sparkline.length >= 2;
}

/// 月次スナップショットから純資産パネルを組み立てる純サービス。
///
/// 金額・変化率はすべてローカルで deterministic に算出し、AI は関与しない
/// (issue 注意事項準拠)。
class AssetNetWorthPanelService {
  const AssetNetWorthPanelService();

  /// スパークラインに用いる直近月数。
  static const int sparklineMonths = 6;

  /// [snapshots] (順不同可) から最新月を基準にパネルを構築する。
  ///
  /// [currentMonthSnapshot] を渡すと同一 monthKey の履歴より優先する
  /// (ライブの当月を未保存でも反映するため)。
  AssetNetWorthPanel build({
    required List<AssetLiabilityMonthlySnapshot> snapshots,
    AssetLiabilityMonthlySnapshot? currentMonthSnapshot,
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
    if (byMonth.isEmpty) {
      return AssetNetWorthPanel.empty;
    }

    final keys = byMonth.keys.toList()..sort();
    final latest = byMonth[keys.last]!;
    final previous = keys.length >= 2 ? byMonth[keys[keys.length - 2]] : null;

    final delta = previous == null ? null : latest.netWorth - previous.netWorth;
    // 前月が正のときだけ変化率を出す (0 除算 / 負の基準での符号反転を回避)。
    final percent = (previous != null && previous.netWorth > 0 && delta != null)
        ? delta / previous.netWorth * 100
        : null;

    final tail = keys.length <= sparklineMonths
        ? keys
        : keys.sublist(keys.length - sparklineMonths);

    return AssetNetWorthPanel(
      netWorth: latest.netWorth,
      positiveAssetTotal: latest.positiveAssetTotal,
      liabilityTotal: latest.liabilityTotal,
      monthKey: latest.monthKey,
      previousNetWorth: previous?.netWorth,
      deltaAmount: delta,
      deltaPercent: percent,
      sparkline: [
        for (final k in tail)
          AssetNetWorthPoint(monthKey: k, netWorth: byMonth[k]!.netWorth),
      ],
    );
  }
}
