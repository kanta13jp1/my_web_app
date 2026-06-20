import '../models/asset_liability_workbook.dart';

/// 重複候補グループ内の 1 サブスク。
typedef SubscriptionDuplicateMember = ({
  String id,
  String name,
  double amount,
  AssetSubscriptionBillingGateway gateway,
});

/// 同じ提供元 (Google/Apple 等) に紐づく 2 件以上のサブスク群。
/// 「内容が重複していないか確認」を促すための soft な提示で、確定的な重複判定ではない。
class SubscriptionDuplicateGroup {
  /// 提供元キー (正規化済み / 無視集合・テストの安定キー)。
  final String providerKey;

  /// 表示用の提供元名 (例: Google)。
  final String providerLabel;

  /// この提供元に該当した 2 件以上のサブスク (登録順)。
  final List<SubscriptionDuplicateMember> members;

  const SubscriptionDuplicateGroup({
    required this.providerKey,
    required this.providerLabel,
    required this.members,
  });

  /// グループの月額合計。
  double get totalAmount {
    var sum = 0.0;
    for (final member in members) {
      sum += member.amount;
    }
    return sum;
  }
}

/// 登録済みサブスクから「同じ提供元の複数契約 = プラン重複の可能性」を検出する純関数。
///
/// クラウドストレージ/AI など**プラン内包で重複が起きやすい提供元**に絞った keyword
/// マッチで誤検出を抑える (例: Google AI Pro 5TB に Google One 100GB が内包される、
/// Apple経由と直接で同種契約が二重、など)。名称に既知 keyword を含むものだけを提供元へ
/// 寄せ、同一提供元に 2 件以上集まったらグループ化する。未知提供元は対象外。
class AssetSubscriptionDuplicateDetector {
  const AssetSubscriptionDuplicateDetector._();

  /// (keyword, providerKey, providerLabel)。keyword は正規化 (小文字/空白除去) 後の
  /// 部分一致。ストレージ/AI/生産性など重複が起きやすい提供元に限定し、'x'/'line' 等の
  /// 過度に一般的な語や 'aws' のような短い部分一致 (「Lawson」に誤当たり) は入れない
  /// (誤検出回避)。
  static const List<(String, String, String)> _providers =
      <(String, String, String)>[
    ('google', 'google', 'Google'),
    ('youtube', 'google', 'Google'),
    ('gemini', 'google', 'Google'),
    ('gcp', 'google', 'Google'),
    ('icloud', 'apple', 'Apple'),
    ('apple', 'apple', 'Apple'),
    ('microsoft', 'microsoft', 'Microsoft'),
    ('office365', 'microsoft', 'Microsoft'),
    ('onedrive', 'microsoft', 'Microsoft'),
    ('amazon', 'amazon', 'Amazon'),
    ('primevideo', 'amazon', 'Amazon'),
    ('kindle', 'amazon', 'Amazon'),
    ('audible', 'amazon', 'Amazon'),
    ('adobe', 'adobe', 'Adobe'),
    ('creativecloud', 'adobe', 'Adobe'),
    ('dropbox', 'dropbox', 'Dropbox'),
    ('openai', 'openai', 'OpenAI'),
    ('chatgpt', 'openai', 'OpenAI'),
    ('anthropic', 'anthropic', 'Anthropic'),
    ('claude', 'anthropic', 'Anthropic'),
  ];

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), '');

  /// 名称が該当する提供元 (キー + 表示名)。未知なら null。
  static ({String key, String label})? providerFor(String name) {
    final normalized = _normalize(name);
    if (normalized.isEmpty) {
      return null;
    }
    for (final provider in _providers) {
      if (normalized.contains(provider.$1)) {
        return (key: provider.$2, label: provider.$3);
      }
    }
    return null;
  }

  /// 同一提供元に 2 件以上集まったサブスク群を返す。[ignoredProviderKeys] の提供元は除外。
  /// グループは合計額の降順 (同額は提供元キー昇順) で安定ソートする。
  static List<SubscriptionDuplicateGroup> detect(
    Iterable<SubscriptionDuplicateMember> subscriptions, {
    Set<String> ignoredProviderKeys = const <String>{},
  }) {
    final byKey = <String, SubscriptionDuplicateGroup>{};
    for (final sub in subscriptions) {
      final provider = providerFor(sub.name);
      if (provider == null || ignoredProviderKeys.contains(provider.key)) {
        continue;
      }
      final group = byKey.putIfAbsent(
        provider.key,
        () => SubscriptionDuplicateGroup(
          providerKey: provider.key,
          providerLabel: provider.label,
          members: <SubscriptionDuplicateMember>[],
        ),
      );
      group.members.add(sub);
    }
    final groups = <SubscriptionDuplicateGroup>[
      for (final group in byKey.values)
        if (group.members.length >= 2) group,
    ];
    groups.sort((a, b) {
      final byTotal = b.totalAmount.compareTo(a.totalAmount);
      if (byTotal != 0) {
        return byTotal;
      }
      return a.providerKey.compareTo(b.providerKey);
    });
    return groups;
  }
}
