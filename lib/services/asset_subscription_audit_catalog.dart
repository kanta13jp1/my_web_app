import '../models/asset_liability_workbook.dart';

/// 集計入力用の口座 (id/表示名/種別) の最小ビュー。`AssetLiabilityAccount` 全体に
/// 依存せず純関数 [AssetSubscriptionAuditCatalog.bucketUnregisteredCounts] を単体
/// テスト可能にするための型。
typedef SubscriptionAuditAccountView = ({
  String id,
  String name,
  AssetLiabilityAccountKind kind,
});

/// 経路ソース内の「請求先カード別」内訳 1 件。[fundingAccountId] が null のときは
/// 請求先カード未設定 (どのカードに請求されるか未登録)。
typedef GatewayCardTotal = ({
  String? fundingAccountId,
  int count,
  double total,
});

/// [AssetSubscriptionAuditCatalog.gatewayCardBreakdownBySourceId] への入力 1 件
/// (請求経路 + 月額 + 請求先カード ID)。
typedef SubscriptionGatewayInput = ({
  AssetSubscriptionBillingGateway gateway,
  double amount,
  String? sourceAccountId,
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
      id: appleSourceId,
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
      id: auKantanSourceId,
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
      id: googlePlaySourceId,
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

  /// 各 manual ソースの安定 ID (請求経路との対応に使う / リネーム不可)。
  static const String appleSourceId = 'apple_id';
  static const String googlePlaySourceId = 'google_play';
  static const String auKantanSourceId = 'au_kantan';

  /// サブスクの請求経路 → 対応する棚卸し manual ソース ID。direct は対応なし (null)。
  static String? sourceIdForGateway(AssetSubscriptionBillingGateway gateway) {
    switch (gateway) {
      case AssetSubscriptionBillingGateway.direct:
        return null;
      case AssetSubscriptionBillingGateway.apple:
        return appleSourceId;
      case AssetSubscriptionBillingGateway.googlePlay:
        return googlePlaySourceId;
      case AssetSubscriptionBillingGateway.auKantan:
        return auKantanSourceId;
    }
  }

  /// 棚卸し manual ソース ID → 対応する請求経路 (登録ダイアログの既定経路に使う)。
  static AssetSubscriptionBillingGateway? gatewayForSourceId(String sourceId) {
    switch (sourceId) {
      case appleSourceId:
        return AssetSubscriptionBillingGateway.apple;
      case googlePlaySourceId:
        return AssetSubscriptionBillingGateway.googlePlay;
      case auKantanSourceId:
        return AssetSubscriptionBillingGateway.auKantan;
      default:
        return null;
    }
  }

  /// 登録済みサブスク (請求経路 + 月額) を、経由ソース ID ごとに件数・合計額へ集計する
  /// 純関数。direct (経由なし) は集計対象外。棚卸しで「Apple 経由の合計」を集約請求
  /// (例 `APPLE.COM/BILL`) と突き合わせるための表示に使う。
  static Map<String, ({int count, double total})> gatewayTotalsBySourceId({
    required Iterable<
            ({AssetSubscriptionBillingGateway gateway, double amount})>
        subscriptions,
  }) {
    final result = <String, ({int count, double total})>{};
    for (final sub in subscriptions) {
      final sourceId = sourceIdForGateway(sub.gateway);
      if (sourceId == null || sub.amount <= 0) {
        continue;
      }
      final existing = result[sourceId];
      result[sourceId] = (
        count: (existing?.count ?? 0) + 1,
        total: (existing?.total ?? 0) + sub.amount,
      );
    }
    return result;
  }

  /// 登録済みサブスクを「経由ソース × 請求先カード」で集計する純関数。
  ///
  /// 同じ Apple経由でもサブスクごとに請求先カードが分かれる場合 (例: ChatGPT は
  /// ファミペイ・LINEスタンプは PayPay)、各カードの集約請求 (APPLE.COM/BILL) は
  /// 別々に出る。経路ソース ID ごとに、請求先カード ([sourceAccountId]) 別の件数・
  /// 合計を合計額の降順 (同額は accountId 昇順 / null は末尾) で返す。
  static Map<String, List<GatewayCardTotal>> gatewayCardBreakdownBySourceId({
    required Iterable<SubscriptionGatewayInput> subscriptions,
  }) {
    final byGateway = <String, Map<String?, ({int count, double total})>>{};
    for (final sub in subscriptions) {
      final sourceId = sourceIdForGateway(sub.gateway);
      if (sourceId == null || sub.amount <= 0) {
        continue;
      }
      final rawCard = sub.sourceAccountId;
      final cardId = (rawCard == null || rawCard.isEmpty) ? null : rawCard;
      final cards = byGateway.putIfAbsent(
        sourceId,
        () => <String?, ({int count, double total})>{},
      );
      final existing = cards[cardId];
      cards[cardId] = (
        count: (existing?.count ?? 0) + 1,
        total: (existing?.total ?? 0) + sub.amount,
      );
    }
    final result = <String, List<GatewayCardTotal>>{};
    byGateway.forEach((sourceId, cards) {
      final list = <GatewayCardTotal>[
        for (final entry in cards.entries)
          (
            fundingAccountId: entry.key,
            count: entry.value.count,
            total: entry.value.total,
          ),
      ];
      list.sort((a, b) {
        final byTotal = b.total.compareTo(a.total);
        if (byTotal != 0) {
          return byTotal;
        }
        // null (未設定) は末尾へ。
        if (a.fundingAccountId == null) {
          return b.fundingAccountId == null ? 0 : 1;
        }
        if (b.fundingAccountId == null) {
          return -1;
        }
        return a.fundingAccountId!.compareTo(b.fundingAccountId!);
      });
      result[sourceId] = list;
    });
    return result;
  }

  /// 請求先カード ID を「既知の口座だけ採用」に正規化する。null/空/未知 (削除済み口座等)
  /// はすべて null (=請求先未設定) へ寄せる。これにより内訳で「未設定」が二重に出るのを
  /// 防ぎ、未知 ID が単独グループとして見えるのを避ける。
  static String? normalizeFundingCard(
    String? sourceAccountId,
    Set<String> knownAccountIds,
  ) {
    if (sourceAccountId == null || sourceAccountId.isEmpty) {
      return null;
    }
    return knownAccountIds.contains(sourceAccountId) ? sourceAccountId : null;
  }

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
