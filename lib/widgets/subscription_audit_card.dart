import 'package:flutter/material.dart';

import '../services/asset_subscription_audit_catalog.dart';

/// サブスク棚卸しの確認状況。
enum SubscriptionAuditStatus {
  /// 一度も確認していない。
  unchecked,

  /// 最近確認済み (staleDays 以内)。
  recentlyChecked,

  /// 前回確認から staleDays を超過 (要再確認)。
  needsRecheck,
}

/// サブスクの支払い元 (銀行・各カード・Apple・auかんたん決済・Google) を一覧し、
/// 「確認したか」を棚卸しする自己完結カード。
///
/// Apple/au/Google は個別サブスクがアプリから不可視なため確認手順を提示し、ユーザーが
/// 確認したら「確認した」で最終確認日時を記録する。銀行・カードは取引フローから検出した
/// 未登録の定期支出件数を提示する。状態・永続化・同期は資産管理ページが持ち、本ウィジェットは
/// 表示とコールバックのみを担う (他の資産管理カードと同じ設計)。
class SubscriptionAuditCard extends StatelessWidget {
  const SubscriptionAuditCard({
    super.key,
    required this.sources,
    required this.lastCheckedAt,
    required this.now,
    required this.onMarkChecked,
    required this.onRegisterSubscription,
    this.unregisteredCountBySourceId = const <String, int>{},
    this.staleDays = AssetSubscriptionAuditCatalog.staleDays,
  });

  /// 表示する支払い元 (manual を先頭に、その後 autoAssisted の想定)。
  final List<SubscriptionAuditSource> sources;

  /// sourceId → 最終確認日時 (UTC 保存)。
  final Map<String, DateTime> lastCheckedAt;

  /// autoAssisted ソースの未登録定期支出件数 (情報表示用)。
  final Map<String, int> unregisteredCountBySourceId;

  /// ステータス判定の基準時刻 (テスト決定性のため注入)。
  final DateTime now;

  final int staleDays;

  final void Function(SubscriptionAuditSource source) onMarkChecked;
  final void Function(SubscriptionAuditSource source) onRegisterSubscription;

  /// 最終確認日時と現在時刻からステータスを判定する (純関数)。
  static SubscriptionAuditStatus statusFor(
    DateTime? last,
    DateTime now, {
    int staleDays = AssetSubscriptionAuditCatalog.staleDays,
  }) {
    if (last == null) {
      return SubscriptionAuditStatus.unchecked;
    }
    if (now.difference(last).inDays > staleDays) {
      return SubscriptionAuditStatus.needsRecheck;
    }
    return SubscriptionAuditStatus.recentlyChecked;
  }

  String _statusLabel(SubscriptionAuditStatus status, DateTime? last) {
    switch (status) {
      case SubscriptionAuditStatus.unchecked:
        return '未確認';
      case SubscriptionAuditStatus.recentlyChecked:
        return '確認済み (${_agoLabel(last!)})';
      case SubscriptionAuditStatus.needsRecheck:
        return '要再確認 (${_agoLabel(last!)})';
    }
  }

  String _agoLabel(DateTime last) {
    final days = now.difference(last).inDays;
    if (days <= 0) {
      return '今日';
    }
    return '$days日前';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final needsRecheckCount = sources
        .where(
          (s) =>
              statusFor(lastCheckedAt[s.id], now, staleDays: staleDays) !=
              SubscriptionAuditStatus.recentlyChecked,
        )
        .length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.fact_check_outlined, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'サブスク棚卸し',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (needsRecheckCount > 0)
                    Semantics(
                      label: '$needsRecheckCount件の支払い元が要確認',
                      child: Chip(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: scheme.errorContainer,
                        label: Text(
                          '要確認 $needsRecheckCount',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '銀行・各カードに加え、Apple(iOS)・auかんたん決済・Google など'
                '内訳が見えない支払い元も含めて、サブスクの契約状況を定期的に確認しましょう。'
                '確認できないものは手順に沿って確認し、見つけたサブスクを登録します。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              for (final source in sources)
                _SourceTile(
                  key: Key('asset_subscription_audit_${source.id}'),
                  source: source,
                  status: statusFor(
                    lastCheckedAt[source.id],
                    now,
                    staleDays: staleDays,
                  ),
                  statusLabel: _statusLabel(
                    statusFor(
                      lastCheckedAt[source.id],
                      now,
                      staleDays: staleDays,
                    ),
                    lastCheckedAt[source.id],
                  ),
                  unregisteredCount:
                      unregisteredCountBySourceId[source.id] ?? 0,
                  onMarkChecked: () => onMarkChecked(source),
                  onRegister: () => onRegisterSubscription(source),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    super.key,
    required this.source,
    required this.status,
    required this.statusLabel,
    required this.unregisteredCount,
    required this.onMarkChecked,
    required this.onRegister,
  });

  final SubscriptionAuditSource source;
  final SubscriptionAuditStatus status;
  final String statusLabel;
  final int unregisteredCount;
  final VoidCallback onMarkChecked;
  final VoidCallback onRegister;

  Color _statusColor(ColorScheme scheme) {
    switch (status) {
      case SubscriptionAuditStatus.unchecked:
        return scheme.secondaryContainer;
      case SubscriptionAuditStatus.recentlyChecked:
        return scheme.primaryContainer;
      case SubscriptionAuditStatus.needsRecheck:
        return scheme.errorContainer;
    }
  }

  Color _onStatusColor(ColorScheme scheme) {
    switch (status) {
      case SubscriptionAuditStatus.unchecked:
        return scheme.onSecondaryContainer;
      case SubscriptionAuditStatus.recentlyChecked:
        return scheme.onPrimaryContainer;
      case SubscriptionAuditStatus.needsRecheck:
        return scheme.onErrorContainer;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isManual = source.kind == SubscriptionAuditSourceKind.manualCheck;
    final actions = Wrap(
      spacing: 8,
      children: [
        TextButton.icon(
          onPressed: onMarkChecked,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('確認した'),
        ),
        TextButton.icon(
          onPressed: onRegister,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('サブスクを登録'),
        ),
      ],
    );
    final header = Row(
      children: [
        Expanded(
          child: Text(
            source.name,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Semantics(
          label: '${source.name}、$statusLabel',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _statusColor(scheme),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              statusLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: _onStatusColor(scheme),
              ),
            ),
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          if (isManual && source.checkSteps.isNotEmpty)
            Theme(
              // ExpansionTile の区切り線を消してリスト内に馴染ませる。
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(left: 8, bottom: 4),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                title: Text(
                  '確認手順',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.primary,
                  ),
                ),
                children: [
                  for (var i = 0; i < source.checkSteps.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${i + 1}. ${source.checkSteps[i]}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            )
          else if (!isManual)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                unregisteredCount > 0
                    ? '未登録の定期支出 $unregisteredCount件 (提案カードから登録できます)'
                    : '未登録の定期支出は検出されていません',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: unregisteredCount > 0
                      ? scheme.error
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          Align(alignment: Alignment.centerRight, child: actions),
        ],
      ),
    );
  }
}
