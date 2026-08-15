import 'package:flutter/material.dart';

/// R24: 公開データトラッカーの着地点に置くプロダクト導線。
///
/// 実測 (X analytics 2026-04-27〜07-25 / 350 投稿): サイトへの URL クリック
/// 304 件のうち 286 件 (94%) が公開ダッシュボードへ着地していたが、着地後に
/// 「何のサイトか」「次に何をすればいいか」を示す導線が 1 つも無く、アカウント
/// 最大の流入がそのまま行き止まりになっていた。
///
/// 売り込みではなく「この数字を作っている仕組みの説明 + 低摩擦の次の一手」を
/// 置く。公開トラッカーは今後増える想定 (家計/AIツール定点観測) なので、
/// ページ内の private メソッドではなく再利用可能なウィジェットにする。
class PublicTrackerCtaCard extends StatelessWidget {
  /// 「この集計は〜」の見出し。トラッカーごとに主語を変えられる。
  final String headline;

  /// 仕組みの説明。誇張せず、実際に動いている処理を書く。
  final String description;

  /// 低摩擦の次の一手。押下時にプロダクト本体へ送る。
  final String actionLabel;

  /// 押下ハンドラ。計測はここで fire-and-forget にし、遷移を待たせないこと。
  final VoidCallback onActionPressed;

  const PublicTrackerCtaCard({
    super.key,
    required this.headline,
    required this.description,
    required this.onActionPressed,
    this.actionLabel = '5分だけ試す',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              headline,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onActionPressed,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(actionLabel),
                ),
                Text(
                  '登録なしで中身を見られます',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer
                        .withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
