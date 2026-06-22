import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/grow_together_share.dart';

/// 「みんなでアプリを育てる」を X (旧 Twitter) で共有するためのカード。
///
/// 自分株式会社の体験 — ユーザーが要望・不具合を送ると AI が自動で
/// 対応に着手する — を広めるための共有導線。本文は [GrowTogetherShare] に
/// 正本として置き、ここでは表示と起動のみを担う。
///
/// テスト時に外部リンクを実際に開かないよう、[onShareToX] / [onCopyMessage]
/// を差し替え可能にしている。
class GrowTogetherShareCard extends StatelessWidget {
  const GrowTogetherShareCard({
    super.key,
    this.isDark = false,
    this.isCompact = false,
    this.onShareToX,
    this.onCopyMessage,
  });

  final bool isDark;
  final bool isCompact;

  /// X 共有のフック。未指定時は実際に X の投稿画面を開く。
  final Future<bool> Function()? onShareToX;

  /// クリップボードコピーのフック。未指定時は本文をコピーする。
  final Future<void> Function()? onCopyMessage;

  Future<void> _handleShare(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await (onShareToX ?? GrowTogetherShare.launchXShare)();
    if (!context.mounted) return;
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Xの投稿画面を開けませんでした。本文をコピーして共有してください。'),
        ),
      );
    }
  }

  Future<void> _handleCopy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final copy = onCopyMessage ??
        () => Clipboard.setData(
              const ClipboardData(text: GrowTogetherShare.fullShareMessage),
            );
    await copy();
    if (!context.mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('共有用の本文をコピーしました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: const Key('grow_together_share_card'),
      elevation: 0,
      color: isDark ? const Color(0xFF0B1220) : const Color(0xFFF8FAFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.14)
              : const Color(0xFFD7DEF5),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF000000),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      '𝕏',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'みんなでアプリを育てる',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '要望・不具合を送るとAIが自動で対応に着手します。'
                        'この仕組みをXで広めて、一緒に育てる仲間を増やしましょう。',
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                GrowTogetherShare.fullShareMessage,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  key: const Key('grow_together_share_x_button'),
                  onPressed: () => _handleShare(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF000000),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Text(
                    '𝕏',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  label: const Text('Xでシェア'),
                ),
                OutlinedButton.icon(
                  key: const Key('grow_together_copy_button'),
                  onPressed: () => _handleCopy(context),
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  label: const Text('本文をコピー'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
