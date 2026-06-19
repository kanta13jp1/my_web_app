import 'waste_tracking_service.dart';

/// 収支フローの説明文パース結果(`_parseFlowDescription` の戻り値レコード)。
typedef FlowDescriptionParts = ({
  String source,
  String destination,
  String memo,
  String? wasteCategory,
  bool isTransfer,
});

/// 収支フローの説明文をパースし、表示用ラベル/タイトルを組み立てる純関数の置き場。
///
/// パース本体([parse])= 浪費マーカー抽出/除去 + `[口座名]` 正規表現の純関数。
/// インポートメタデータ(取込/自動資産差分マーカー)の除去だけはページ固有の
/// 正規表現に依存するためページ側に残し、除去済み文字列を [parse] へ渡す。
/// 振る舞いは不変でユニットテスト可能。
class AssetFlowDescriptionService {
  const AssetFlowDescriptionService._();

  static final RegExp _transferPattern = RegExp(
    r'^(\[[^\]]+\])\s*->\s*(\[[^\]]+\])(?:\s+(.*))?$',
  );
  static final RegExp _sourcePattern = RegExp(r'^(\[[^\]]+\])\s*(.*)$');

  /// メタデータ除去済みの説明文を [FlowDescriptionParts] へパースする。
  /// [actionType] が `expense` のときのみ浪費カテゴリを抽出し、マーカーを除去する。
  /// `transfer` は「移動元 -> 移動先 メモ」、それ以外は「[口座名] メモ」を解釈する。
  static FlowDescriptionParts parse(
    String metadataStrippedDescription, {
    String? actionType,
  }) {
    final type = actionType ?? '';
    final isExpense = type == 'expense';
    final isTransfer = type == 'transfer';
    final wasteCategory = isExpense
        ? WasteTrackingService.extractWasteCategory(metadataStrippedDescription)
        : null;
    final normalized = isExpense
        ? WasteTrackingService.stripWasteMarker(metadataStrippedDescription)
        : metadataStrippedDescription;

    if (isTransfer) {
      final transferMatch = _transferPattern.firstMatch(normalized);
      if (transferMatch != null) {
        return (
          source: transferMatch.group(1)?.trim() ?? '',
          destination: transferMatch.group(2)?.trim() ?? '',
          memo: transferMatch.group(3)?.trim() ?? '',
          wasteCategory: wasteCategory,
          isTransfer: true,
        );
      }
    }

    final match = _sourcePattern.firstMatch(normalized);
    if (match != null) {
      return (
        source: match.group(1)?.trim() ?? '',
        destination: '',
        memo: match.group(2)?.trim() ?? '',
        wasteCategory: wasteCategory,
        isTransfer: isTransfer,
      );
    }

    return (
      source: '',
      destination: '',
      memo: normalized,
      wasteCategory: wasteCategory,
      isTransfer: isTransfer,
    );
  }

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
