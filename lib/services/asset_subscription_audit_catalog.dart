import '../models/asset_liability_workbook.dart';

/// 集計入力用の口座 (id/表示名/種別) の最小ビュー。`AssetLiabilityAccount` 全体に
/// 依存せず純関数 [AssetSubscriptionAuditCatalog.bucketUnregisteredCounts] を単体
/// テスト可能にするための型。
typedef SubscriptionAuditAccountView = ({
  String id,
  String name,
  AssetLiabilityAccountKind kind,
});

/// サブスク棚卸しで確認する「支払い元(ソース)」の種別。
enum SubscriptionAuditSourceKind {
  /// アプリ側が個別サブスクを把握できない集約請求 (Apple/au/Google 等)。
  /// 確認手順を提示し、ユーザーに手動確認を促す。
  manualCheck,

  /// 取引フロー (定期支出検出) からアプリが候補を提示できる支払い元
  /// (銀行引き落とし・各クレジットカード)。
  autoAssisted,
}

/// 棚卸し対象の支払い元 1 件 (静的定義)。確認状況 (最終確認日時) は本モデルには
/// 持たせず、`AssetSubscriptionAuditStore` 側で sourceId をキーに永続化する。
class SubscriptionAuditSource {
  /// 安定した一意 ID。永続化キー (ミラー) になるためリネーム不可。
  /// manual ソースは固定文字列、カード別ソースは `card_<accountId>`。
  final String id;

  /// 表示名 (例: Apple (iOS) サブスク)。
  final String name;

  /// 種別 (手動確認 / 自動補助)。
  final SubscriptionAuditSourceKind kind;

  /// 手動確認ソースに提示する確認手順 (順序付き)。autoAssisted では空でよい。
  final List<String> checkSteps;

  const SubscriptionAuditSource({
    required this.id,
    required this.name,
    required this.kind,
    this.checkSteps = const <String>[],
  });
}

/// サブスク棚卸しの静的カタログ。
///
/// Apple/au/Google は「集約請求」で個別サブスクがアプリから不可視なため、確認手順を
/// 提示してユーザーに棚卸しを促す (manualCheck)。銀行・各カードは取引フローから定期
/// 支出を検出できるため候補を提示する (autoAssisted / カード別ソースは実行時に導出)。
class AssetSubscriptionAuditCatalog {
  const AssetSubscriptionAuditCatalog._();

  /// 「要再確認」とみなす最終確認からの経過日数。
  static const int staleDays = 30;

  /// カード別ソースの ID 接頭辞 (口座 ID と連結して安定 ID にする)。
  static const String cardSourceIdPrefix = 'card_';

  /// 取引フローに記録される銀行引き落としをまとめる autoAssisted ソース ID。
  static const String bankSourceId = 'bank_direct_debit';

  /// アプリが個別サブスクを把握できない手動確認ソース (Apple/au/Google)。
  static const List<SubscriptionAuditSource> manualSources =
      <SubscriptionAuditSource>[
    SubscriptionAuditSource(
      id: 'apple_id',
      name: 'Apple (iOS) サブスク',
      kind: SubscriptionAuditSourceKind.manualCheck,
      checkSteps: <String>[
        'iPhone/iPad で「設定」アプリを開く',
        '上部の自分の名前 (Apple Account) をタップ',
        '「サブスクリプション」をタップ',
        '有効なサブスクの更新日・金額を確認 (Mac は App Store > 名前 > アカウント設定)',
      ],
    ),
    SubscriptionAuditSource(
      id: 'au_kantan',
      name: 'auかんたん決済',
      kind: SubscriptionAuditSourceKind.manualCheck,
      checkSteps: <String>[
        'My au アプリ または My au (web) にログイン',
        '「ご利用明細」→「auかんたん決済・au PAY」の利用履歴を確認',
        'または「会員情報・各種設定」→「ご契約中の有料サービス」を確認',
        '毎月課金されている定期サービスを洗い出す',
      ],
    ),
    SubscriptionAuditSource(
      id: 'google_play',
      name: 'Google Play 定期購入',
      kind: SubscriptionAuditSourceKind.manualCheck,
      checkSteps: <String>[
        'Google Play ストアアプリを開く',
        '右上のプロフィールアイコン →「お支払いと定期購入」',
        '「定期購入」をタップして有効な定期購入を確認',
        'web は play.google.com/store/account/subscriptions',
      ],
    ),
  ];

  /// 取引フローから定期支出を検出できる「銀行引き落とし」ソース。
  static const SubscriptionAuditSource bankSource = SubscriptionAuditSource(
    id: bankSourceId,
    name: '銀行引き落とし',
    kind: SubscriptionAuditSourceKind.autoAssisted,
  );

  /// 口座 ID からカード別ソースの安定 ID を作る。
  static String cardSourceId(String accountId) =>
      '$cardSourceIdPrefix$accountId';

  /// 検出した定期支出 ([suggestedSourceNames] = 各検出の引落元口座名) を支払い元
  /// ソース ID ごとに集計する純関数。
  ///
  /// クレカ口座名は `card_<id>`、現金/預金口座名は銀行ソース、未知・不明 (null) は
  /// 銀行ソースへ寄せる (取りこぼし防止)。検出器は口座名しか持たないため、同名口座が
  /// 複数あると最後に走査した口座へ寄る (件数自体は失わない / 既存 register 経路と同仕様)。
  static Map<String, int> bucketUnregisteredCounts({
    required Iterable<SubscriptionAuditAccountView> accounts,
    required Iterable<String?> suggestedSourceNames,
  }) {
    final nameToSourceId = <String, String>{};
    for (final account in accounts) {
      if (account.kind == AssetLiabilityAccountKind.creditCard) {
        nameToSourceId[account.name] = cardSourceId(account.id);
      } else if (account.kind == AssetLiabilityAccountKind.cash ||
          account.kind == AssetLiabilityAccountKind.deposit) {
        nameToSourceId[account.name] = bankSourceId;
      }
    }
    final counts = <String, int>{};
    for (final name in suggestedSourceNames) {
      final sourceId =
          (name != null ? nameToSourceId[name] : null) ?? bankSourceId;
      counts[sourceId] = (counts[sourceId] ?? 0) + 1;
    }
    return counts;
  }
}
