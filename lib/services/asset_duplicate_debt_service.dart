import '../models/asset_liability_workbook.dart';

/// 口座名・ローン名の表記ゆれや類似名称による二重登録（例: 「じぶんローン」と「じぶん銀行カードローン」）の警告。
class AssetLiabilityDebtDuplicateWarning {
  final AssetLiabilityDebtRow rowA;
  final AssetLiabilityDebtRow rowB;
  final double similarity;
  final String message;

  const AssetLiabilityDebtDuplicateWarning({
    required this.rowA,
    required this.rowB,
    required this.similarity,
    required this.message,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'rowAId': rowA.id,
        'rowBId': rowB.id,
        'rowAName': rowA.name,
        'rowBName': rowB.name,
        'similarity': similarity,
        'message': message,
      };
}

/// 負債重複検知サービス。
class AssetDuplicateDebtService {
  const AssetDuplicateDebtService();

  /// 負債名称からストップワードを除去して正規化コアステムを抽出する。
  static String normalizeDebtStem(String name) {
    var s = name.toLowerCase().replaceAll(RegExp(r'[\s　・_-]'), '');
    s = s
        .replaceAll('（', '')
        .replaceAll('）', '')
        .replaceAll('(', '')
        .replaceAll(')', '');
    s = s.replaceAll('株式会社', '').replaceAll('合同会社', '');
    s = s.replaceAll('カードローン', '').replaceAll('ローン', '').replaceAll('loan', '');
    s = s
        .replaceAll('クレジットカード', '')
        .replaceAll('カード', '')
        .replaceAll('card', '');
    s = s.replaceAll('銀行', '').replaceAll('バンク', '').replaceAll('bank', '');
    s = s.replaceAll('リボ', '').replaceAll('割賦', '').replaceAll('キャッシング', '');
    return s.trim();
  }

  /// 2つの負債名間の類似度（0.0〜1.0）を計算する。
  static double calculateSimilarity(String nameA, String nameB) {
    if (nameA.trim() == nameB.trim()) return 1.0;
    final stemA = normalizeDebtStem(nameA);
    final stemB = normalizeDebtStem(nameB);
    if (stemA.isEmpty || stemB.isEmpty) return 0.0;
    if (stemA == stemB) return 0.95;
    if (stemA.contains(stemB) || stemB.contains(stemA)) {
      final minLen = stemA.length < stemB.length ? stemA.length : stemB.length;
      if (minLen >= 2) return 0.85;
    }
    // Bigram Jaccard similarity
    final bigramsA = <String>{};
    for (var i = 0; i < stemA.length - 1; i++) {
      bigramsA.add(stemA.substring(i, i + 2));
    }
    final bigramsB = <String>{};
    for (var i = 0; i < stemB.length - 1; i++) {
      bigramsB.add(stemB.substring(i, i + 2));
    }
    if (bigramsA.isEmpty || bigramsB.isEmpty) return 0.0;
    final intersection = bigramsA.intersection(bigramsB).length;
    final union = bigramsA.union(bigramsB).length;
    return union == 0 ? 0.0 : intersection / union;
  }

  /// 口座名・ローン名の表記ゆれや類似名称による負債の重複を検出する。
  static List<AssetLiabilityDebtDuplicateWarning> detectDuplicates(
    List<AssetLiabilityDebtRow> debtRows,
  ) {
    final warnings = <AssetLiabilityDebtDuplicateWarning>[];
    for (var i = 0; i < debtRows.length; i++) {
      for (var j = i + 1; j < debtRows.length; j++) {
        final a = debtRows[i];
        final b = debtRows[j];
        final sim = calculateSimilarity(a.name, b.name);
        if (sim >= 0.75) {
          warnings.add(
            AssetLiabilityDebtDuplicateWarning(
              rowA: a,
              rowB: b,
              similarity: sim,
              message:
                  '「${a.name}」と「${b.name}」は同一の借入・ローンである可能性があります。二重計上にご注意ください。',
            ),
          );
        }
      }
    }
    return warnings;
  }
}
