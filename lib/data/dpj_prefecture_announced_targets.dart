/// 国民民主党「Road to 700」に向けた都道府県別の
/// 地方議員増加・候補者擁立目標の静的データ。
///
/// 注意: 県によって数字の意味が異なる。
/// - 統一地方選での候補者擁立数の目標
/// - 統一地方選終了時点の所属地方議員総数の目標
/// - 統一地方選以外の選挙も含めた擁立数の目標
/// が混在しており、いずれも「目標当選人数」ではない。
/// 「○人擁立」を「○人当選」に置き換えると意味が大きく変わるため、
/// [DpjAnnouncedTargetKind] で種別を必ず区別して表示する。
/// 県連公式発表・報道で数字と定義を確認できたものだけ verified とし、
/// 裏づけを確認できていない数字は種別未確認の参考値として扱う。
library;

/// 公表・報道された目標数値の種別。
enum DpjAnnouncedTargetKind {
  /// 統一地方選での候補者擁立数の目標(当選数の目標ではない)。
  candidateFielding,

  /// 統一地方選終了時点の所属地方議員総数の目標。
  totalLocalMembers,

  /// 統一地方選以外の地方選挙も含めた公認候補擁立数の目標。
  allLocalElectionsFielding,

  /// 数字の定義(擁立/当選/所属総数)を裏づける公式発表・報道を確認できていない。
  unconfirmed,
}

class DpjPrefectureAnnouncedTarget {
  final String prefecture;
  final int minCount;
  final int maxCount;
  final DpjAnnouncedTargetKind kind;

  /// 県連公式発表・報道で数字とその定義を確認できたか。
  final bool verified;
  final String note;

  const DpjPrefectureAnnouncedTarget({
    required this.prefecture,
    required this.minCount,
    int? maxCount,
    required this.kind,
    this.verified = false,
    this.note = '',
  }) : maxCount = maxCount ?? minCount;

  bool get isRange => maxCount > minCount;

  String get countLabel => isRange ? '$minCount〜$maxCount人' : '$minCount人';

  String get kindLabel => dpjAnnouncedTargetKindLabel(kind);
}

String dpjAnnouncedTargetKindLabel(DpjAnnouncedTargetKind kind) {
  switch (kind) {
    case DpjAnnouncedTargetKind.candidateFielding:
      return '擁立目標';
    case DpjAnnouncedTargetKind.totalLocalMembers:
      return '所属議員総数目標';
    case DpjAnnouncedTargetKind.allLocalElectionsFielding:
      return '地方選全体の擁立目標';
    case DpjAnnouncedTargetKind.unconfirmed:
      return '種別未確認';
  }
}

/// セクション表題。「目標当選人数」は不正確なため使わない。
const String dpjAnnouncedTargetSectionTitle =
    'Road to 700　都道府県別の地方議員増加・候補者擁立目標';

/// 全体注記。表示側で必ず添える。
const String dpjAnnouncedTargetCaveat =
    '数字の意味は県によって異なります。候補者の擁立数目標・所属地方議員の総数目標などが混在しており、'
    'いずれも「目標当選人数」ではありません。「○人擁立」を「○人当選」と読み替えないでください。'
    '種別未確認の数字は、定義を裏づける県連公式発表・報道をまだ確認できていない参考値です。';

/// 都道府県別の公表・報道ベース目標一覧(北から南の順)。
const List<DpjPrefectureAnnouncedTarget> dpjPrefectureAnnouncedTargets =
    <DpjPrefectureAnnouncedTarget>[
  DpjPrefectureAnnouncedTarget(
    prefecture: '北海道',
    minCount: 20,
    maxCount: 30,
    kind: DpjAnnouncedTargetKind.unconfirmed,
  ),
  DpjPrefectureAnnouncedTarget(
    prefecture: '青森',
    minCount: 10,
    kind: DpjAnnouncedTargetKind.unconfirmed,
  ),
  DpjPrefectureAnnouncedTarget(
    prefecture: '宮城',
    minCount: 10,
    kind: DpjAnnouncedTargetKind.unconfirmed,
    note: '仙台3・県議5との情報あり',
  ),
  DpjPrefectureAnnouncedTarget(
    prefecture: '群馬',
    minCount: 10,
    kind: DpjAnnouncedTargetKind.unconfirmed,
    note: '17人擁立との情報あり',
  ),
  DpjPrefectureAnnouncedTarget(
    prefecture: '千葉',
    minCount: 40,
    kind: DpjAnnouncedTargetKind.unconfirmed,
  ),
  DpjPrefectureAnnouncedTarget(
    prefecture: '神奈川',
    minCount: 50,
    kind: DpjAnnouncedTargetKind.candidateFielding,
    verified: true,
    note: '50人以上の候補者擁立目標(当選50人の目標ではない)。'
        '2026年6月25日時点で第1次公認30人(現職11・新人19)。',
  ),
  DpjPrefectureAnnouncedTarget(
    prefecture: '山梨',
    minCount: 10,
    kind: DpjAnnouncedTargetKind.unconfirmed,
    note: '2ケタとの情報あり',
  ),
  DpjPrefectureAnnouncedTarget(
    prefecture: '新潟',
    minCount: 10,
    kind: DpjAnnouncedTargetKind.unconfirmed,
  ),
  DpjPrefectureAnnouncedTarget(
    prefecture: '富山',
    minCount: 7,
    kind: DpjAnnouncedTargetKind.unconfirmed,
  ),
  DpjPrefectureAnnouncedTarget(
    prefecture: '石川',
    minCount: 10,
    kind: DpjAnnouncedTargetKind.unconfirmed,
  ),
  DpjPrefectureAnnouncedTarget(
    prefecture: '長野',
    minCount: 18,
    kind: DpjAnnouncedTargetKind.unconfirmed,
  ),
  DpjPrefectureAnnouncedTarget(
    prefecture: '岐阜',
    minCount: 16,
    kind: DpjAnnouncedTargetKind.unconfirmed,
    note: 'うち県議8との情報あり',
  ),
  DpjPrefectureAnnouncedTarget(
    prefecture: '静岡',
    minCount: 29,
    kind: DpjAnnouncedTargetKind.totalLocalMembers,
    verified: true,
    note: '統一地方選終了までに所属地方議員を29人にする目標(当選者29人の意味ではない)。',
  ),
  DpjPrefectureAnnouncedTarget(
    prefecture: '三重',
    minCount: 10,
    kind: DpjAnnouncedTargetKind.unconfirmed,
  ),
  DpjPrefectureAnnouncedTarget(
    prefecture: '滋賀',
    minCount: 12,
    kind: DpjAnnouncedTargetKind.unconfirmed,
  ),
  DpjPrefectureAnnouncedTarget(
    prefecture: '奈良',
    minCount: 10,
    kind: DpjAnnouncedTargetKind.unconfirmed,
    note: '2ケタとの情報あり',
  ),
  DpjPrefectureAnnouncedTarget(
    prefecture: '和歌山',
    minCount: 9,
    kind: DpjAnnouncedTargetKind.unconfirmed,
  ),
  DpjPrefectureAnnouncedTarget(
    prefecture: '大阪',
    minCount: 35,
    kind: DpjAnnouncedTargetKind.candidateFielding,
    verified: true,
    note: '35人以上の候補者擁立目標(当選目標ではない)。',
  ),
  DpjPrefectureAnnouncedTarget(
    prefecture: '兵庫',
    minCount: 20,
    kind: DpjAnnouncedTargetKind.unconfirmed,
    note: '1年前から3倍増との情報あり',
  ),
  DpjPrefectureAnnouncedTarget(
    prefecture: '広島',
    minCount: 20,
    kind: DpjAnnouncedTargetKind.unconfirmed,
  ),
  DpjPrefectureAnnouncedTarget(
    prefecture: '徳島',
    minCount: 10,
    kind: DpjAnnouncedTargetKind.unconfirmed,
    note: '10人擁立との情報あり',
  ),
  DpjPrefectureAnnouncedTarget(
    prefecture: '香川',
    minCount: 56,
    kind: DpjAnnouncedTargetKind.totalLocalMembers,
    verified: true,
    note: '現在26人の自治体議員を統一地方選までに56人へ増やす所属議員総数の目標。',
  ),
  DpjPrefectureAnnouncedTarget(
    prefecture: '福岡',
    minCount: 30,
    kind: DpjAnnouncedTargetKind.candidateFielding,
    verified: true,
    note: '統一地方選で約30人を擁立する方針(当選30人の目標ではない)。',
  ),
  DpjPrefectureAnnouncedTarget(
    prefecture: '熊本',
    minCount: 9,
    kind: DpjAnnouncedTargetKind.unconfirmed,
    note: '9人擁立との情報あり',
  ),
  DpjPrefectureAnnouncedTarget(
    prefecture: '宮崎',
    minCount: 25,
    kind: DpjAnnouncedTargetKind.allLocalElectionsFielding,
    verified: true,
    note: '統一地方選に加え、その他の地方議員選挙も含めて公認候補25人を擁立する目標。',
  ),
  DpjPrefectureAnnouncedTarget(
    prefecture: '鹿児島',
    minCount: 10,
    kind: DpjAnnouncedTargetKind.unconfirmed,
  ),
  DpjPrefectureAnnouncedTarget(
    prefecture: '沖縄',
    minCount: 10,
    kind: DpjAnnouncedTargetKind.unconfirmed,
    note: '10人擁立との情報あり',
  ),
];

int get dpjAnnouncedTargetVerifiedCount =>
    dpjPrefectureAnnouncedTargets.where((item) => item.verified).length;

int get dpjAnnouncedTargetUnconfirmedCount => dpjPrefectureAnnouncedTargets
    .where((item) => item.kind == DpjAnnouncedTargetKind.unconfirmed)
    .length;
