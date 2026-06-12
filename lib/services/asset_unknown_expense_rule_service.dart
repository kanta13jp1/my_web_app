/// 資産記録時の残高減少を「使途不明金」支出として自動記録するかの判定ルール。
/// asset_management_page から切り出した pure logic (UI / Supabase 非依存)。
class AssetUnknownExpenseRuleService {
  const AssetUnknownExpenseRuleService._();

  /// 現金系タイプ。マイナス残高(立替・前借り等)でも減少分を支出として扱う。
  static bool isCashLikeType(String assetType) {
    final key = assetType.toLowerCase();
    return key.contains('現金') || key.contains('cash');
  }

  /// 投資系タイプ。減少が評価損か出金か区別できないため自動記録の対象外。
  static bool isInvestmentLikeType(String assetType) {
    final key = assetType.toLowerCase();
    return key.contains('証券') ||
        key.contains('株') ||
        key.contains('投資') ||
        key.contains('nisa') ||
        key.contains('securities') ||
        key.contains('stock') ||
        key.contains('crypto') ||
        key.contains('coincheck') ||
        key.contains('bitflyer');
  }

  /// 自動記録の条件:
  /// - 減少幅が 1 円以上
  /// - 投資系タイプは対象外
  /// - 残高がマイナス圏 (previousAmount <= 0) のときは現金系のみ対象。
  ///   負の値で記録する負債系タイプの残高悪化を使途不明金と誤認しないため。
  static bool shouldAutoRecordFromAssetDrop({
    required String assetType,
    required double previousAmount,
    required double currentAmount,
  }) {
    final drop = previousAmount - currentAmount;
    if (drop < 1) {
      return false;
    }
    if (previousAmount <= 0 && !isCashLikeType(assetType)) {
      return false;
    }
    if (isInvestmentLikeType(assetType)) {
      return false;
    }
    return true;
  }
}
