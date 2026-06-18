/// 収支フローの説明文パース結果(`_parseFlowDescription` の戻り値レコード)。
typedef FlowDescriptionParts = ({
  String source,
  String destination,
  String memo,
  String? wasteCategory,
  bool isTransfer,
});

/// 収支フローの説明文から表示用ラベル/タイトルを組み立てる純関数の置き場。
///
/// 元々ページの `_sourceLabel` / `_flowDisplayTitle` にあった表示ロジックを抽出し、
/// パース([FlowDescriptionParts])の結果から視覚表現を導く部分をテスト可能に
/// したもの(振る舞いは不変)。パース本体(正規表現・浪費マーカー除去)は依存が
/// 重いためページ側に残す。
class AssetFlowDescriptionService {
  const AssetFlowDescriptionService._();

  /// `[口座名]` のような source ラベルから囲み括弧を除いた表示名を返す。
  static String sourceLabel(String source) =>
      source.replaceAll('[', '').replaceAll(']', '').trim();

  /// パース結果から1行の表示タイトルを組み立てる。
  /// 振替は「移動元 → 移動先 ・ メモ」、それ以外は「source ・ メモ」。
  static String displayTitle(FlowDescriptionParts parsed) {
    if (parsed.isTransfer) {
      final fromLabel = sourceLabel(parsed.source);
      final toLabel = sourceLabel(parsed.destination);
      final routeParts = [
        fromLabel,
        toLabel,
      ].where((part) => part.trim().isNotEmpty).toList();
      final routeLabel = routeParts.join(' → ');
      if (routeLabel.isEmpty) {
        return parsed.memo;
      }
      if (parsed.memo.isEmpty) {
        return routeLabel;
      }
      return '$routeLabel ・ ${parsed.memo}';
    }

    final label = sourceLabel(parsed.source);
    if (label.isEmpty) {
      return parsed.memo;
    }
    if (parsed.memo.isEmpty) {
      return label;
    }
    return '$label ・ ${parsed.memo}';
  }
}
