/// 国民民主党公式の地方自治体各級選挙一覧に掲載された、公認予定候補者の
/// 都道府県別スナップショット。
///
/// 「公認」と明記された掲載行だけを集計し、「推薦」は含めない。
/// 公式表に同一人物と思われる表記違いがあっても独自補正はせず、掲載行単位で
/// 集計する。候補者の追加・修正時は全県の値と公式一覧の基準日を同時に更新する。
library;

class DpjOfficialEndorsement {
  final String prefecture;
  final int totalCount;
  final int incumbentCount;
  final int newcomerCount;
  final int formerCount;

  const DpjOfficialEndorsement(
    this.prefecture, {
    required this.totalCount,
    this.incumbentCount = 0,
    this.newcomerCount = 0,
    this.formerCount = 0,
  });

  bool get hasBreakdown =>
      incumbentCount > 0 || newcomerCount > 0 || formerCount > 0;

  String get breakdownLabel {
    final parts = <String>[
      if (incumbentCount > 0) '現職$incumbentCount',
      if (newcomerCount > 0) '新人$newcomerCount',
      if (formerCount > 0) '元$formerCount',
    ];
    return parts.join(' / ');
  }
}

/// 2026-08-05現在の公式一覧に掲載された推薦件数。公認集計には含めない。
const int dpjOfficialRecommendationEntryCount = 9;

/// 2026-08-05現在。都道府県順は公式PDFの掲載順。
const List<DpjOfficialEndorsement> dpjOfficialEndorsements =
    <DpjOfficialEndorsement>[
  DpjOfficialEndorsement(
    '北海道',
    totalCount: 6,
    incumbentCount: 2,
    newcomerCount: 4,
  ),
  DpjOfficialEndorsement(
    '青森',
    totalCount: 5,
    incumbentCount: 2,
    newcomerCount: 2,
    formerCount: 1,
  ),
  DpjOfficialEndorsement(
    '秋田',
    totalCount: 3,
    incumbentCount: 1,
    newcomerCount: 2,
  ),
  DpjOfficialEndorsement('福島', totalCount: 1, newcomerCount: 1),
  DpjOfficialEndorsement(
    '茨城',
    totalCount: 6,
    incumbentCount: 5,
    newcomerCount: 1,
  ),
  DpjOfficialEndorsement('栃木', totalCount: 1, incumbentCount: 1),
  DpjOfficialEndorsement(
    '群馬',
    totalCount: 3,
    incumbentCount: 2,
    newcomerCount: 1,
  ),
  DpjOfficialEndorsement(
    '埼玉',
    totalCount: 5,
    incumbentCount: 2,
    newcomerCount: 2,
    formerCount: 1,
  ),
  DpjOfficialEndorsement(
    '千葉',
    totalCount: 8,
    incumbentCount: 2,
    newcomerCount: 4,
    formerCount: 2,
  ),
  DpjOfficialEndorsement(
    '東京',
    totalCount: 33,
    incumbentCount: 28,
    newcomerCount: 4,
    formerCount: 1,
  ),
  DpjOfficialEndorsement(
    '神奈川',
    totalCount: 39,
    incumbentCount: 11,
    newcomerCount: 28,
  ),
  DpjOfficialEndorsement('新潟', totalCount: 1, newcomerCount: 1),
  DpjOfficialEndorsement('石川', totalCount: 1, incumbentCount: 1),
  DpjOfficialEndorsement(
    '岐阜',
    totalCount: 9,
    incumbentCount: 2,
    newcomerCount: 7,
  ),
  DpjOfficialEndorsement(
    '静岡',
    totalCount: 7,
    incumbentCount: 6,
    newcomerCount: 1,
  ),
  DpjOfficialEndorsement(
    '愛知',
    totalCount: 10,
    incumbentCount: 9,
    newcomerCount: 1,
  ),
  DpjOfficialEndorsement(
    '京都',
    totalCount: 10,
    incumbentCount: 8,
    newcomerCount: 2,
  ),
  DpjOfficialEndorsement(
    '大阪',
    totalCount: 9,
    incumbentCount: 7,
    newcomerCount: 2,
  ),
  DpjOfficialEndorsement('兵庫', totalCount: 1, incumbentCount: 1),
  DpjOfficialEndorsement('奈良', totalCount: 1, newcomerCount: 1),
  DpjOfficialEndorsement('岡山', totalCount: 2, incumbentCount: 2),
  DpjOfficialEndorsement(
    '広島',
    totalCount: 3,
    incumbentCount: 1,
    newcomerCount: 2,
  ),
  DpjOfficialEndorsement(
    '山口',
    totalCount: 2,
    incumbentCount: 1,
    newcomerCount: 1,
  ),
  DpjOfficialEndorsement('香川', totalCount: 1, newcomerCount: 1),
  DpjOfficialEndorsement(
    '愛媛',
    totalCount: 4,
    incumbentCount: 2,
    newcomerCount: 1,
    formerCount: 1,
  ),
  DpjOfficialEndorsement(
    '高知',
    totalCount: 3,
    newcomerCount: 2,
    formerCount: 1,
  ),
  DpjOfficialEndorsement(
    '福岡',
    totalCount: 12,
    incumbentCount: 1,
    newcomerCount: 11,
  ),
  DpjOfficialEndorsement(
    '長崎',
    totalCount: 7,
    incumbentCount: 3,
    newcomerCount: 4,
  ),
  DpjOfficialEndorsement('熊本', totalCount: 5, newcomerCount: 5),
  DpjOfficialEndorsement('大分', totalCount: 1, incumbentCount: 1),
  DpjOfficialEndorsement(
    '宮崎',
    totalCount: 14,
    newcomerCount: 13,
    formerCount: 1,
  ),
  DpjOfficialEndorsement(
    '沖縄',
    totalCount: 4,
    incumbentCount: 1,
    newcomerCount: 2,
    formerCount: 1,
  ),
];

int get dpjOfficialEndorsementPrefectureCount => dpjOfficialEndorsements.length;

int get dpjOfficialEndorsementTotal => dpjOfficialEndorsements.fold<int>(
      0,
      (sum, item) => sum + item.totalCount,
    );

int get dpjOfficialEndorsementIncumbentTotal =>
    dpjOfficialEndorsements.fold<int>(
      0,
      (sum, item) => sum + item.incumbentCount,
    );

int get dpjOfficialEndorsementNewcomerTotal =>
    dpjOfficialEndorsements.fold<int>(
      0,
      (sum, item) => sum + item.newcomerCount,
    );

int get dpjOfficialEndorsementFormerTotal => dpjOfficialEndorsements.fold<int>(
      0,
      (sum, item) => sum + item.formerCount,
    );

DpjOfficialEndorsement? dpjOfficialEndorsementFor(String prefecture) {
  for (final item in dpjOfficialEndorsements) {
    if (item.prefecture == prefecture) {
      return item;
    }
  }
  return null;
}
