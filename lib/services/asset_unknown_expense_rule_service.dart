/// 資産記録時の残高減少を「使途不明金」支出として自動記録するかの判定ルール。
/// asset_management_page から切り出した pure logic (UI / Supabase 非依存)。
class AssetUnknownExpenseRuleService {
  const AssetUnknownExpenseRuleService._();

  /// 現金系タイプ。マイナス残高(立替・前借り等)でも減少分を支出として扱う。
  static bool isCashLikeType(String assetType) {
    final key = assetType.toLowerCase();
    return key.contains('現金') || key.contains('cash');
  }

  /// プリペイド/電子マネー/QR決済の残高タイプ。ファミペイのように
  /// 残高がマイナス(あと払い・チャージ不足)へさらに進む=支出なので、
  /// 現金系と同様にマイナス圏の減少も自動記録の対象にする。
  /// ただしカード/ローン等の負債名は除外(残高悪化=借入で、カード請求側と
  /// 二重計上になるため)。
  static bool isPrepaidLikeType(String assetType) {
    final key = assetType.toLowerCase();
    if (key.contains('カード') ||
        key.contains('card') ||
        key.contains('ローン') ||
        key.contains('loan') ||
        key.contains('クレジット') ||
        key.contains('credit')) {
      return false;
    }
    const keywords = <String>[
      'ファミペイ',
      'famipay',
      'paypay',
      'ペイペイ',
      'aupay',
      'au pay',
      '楽天ペイ',
      'rakuten pay',
      'd払い',
      'linepay',
      'line pay',
      'ラインペイ',
      'メルペイ',
      'merpay',
      'suica',
      'スイカ',
      'pasmo',
      'パスモ',
      'icoca',
      'nanaco',
      'ナナコ',
      'waon',
      'ワオン',
      'edy',
      'エディ',
      '電子マネー',
      'プリペイド',
      'prepaid',
      'スマホ決済',
    ];
    for (final keyword in keywords) {
      if (key.contains(keyword)) {
        return true;
      }
    }
    return false;
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
  /// - 残高がマイナス圏 (previousAmount <= 0) のときは現金系・プリペイド系
  ///   (ファミペイ等の電子マネー残高) のみ対象。負の値で記録する負債系
  ///   タイプの残高悪化を使途不明金と誤認しないため。
  static bool shouldAutoRecordFromAssetDrop({
    required String assetType,
    required double previousAmount,
    required double currentAmount,
  }) {
    final drop = previousAmount - currentAmount;
    if (drop < 1) {
      return false;
    }
    if (previousAmount <= 0 &&
        !isCashLikeType(assetType) &&
        !isPrepaidLikeType(assetType)) {
      return false;
    }
    if (isInvestmentLikeType(assetType)) {
      return false;
    }
    return true;
  }
}
