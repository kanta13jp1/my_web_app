import 'package:flutter/material.dart';

class AdminUserFeedbackCard extends StatelessWidget {
  const AdminUserFeedbackCard({
    super.key,
    required this.feedbacks,
    required this.loading,
    required this.onRefresh,
    required this.onUpdateStatus,
    required this.onOpenManageAll,
  });

  final List<Map<String, dynamic>> feedbacks;
  final bool loading;
  final VoidCallback onRefresh;
  final void Function(int id, String status) onUpdateStatus;
  final VoidCallback onOpenManageAll;

  @override
  Widget build(BuildContext context) {
    final newCount = feedbacks.where((f) => f['status'] == 'new').length;
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー行
            Row(
              children: [
                const Icon(
                  Icons.feedback_outlined,
                  color: Color(0xFF6366F1),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'ユーザーフィードバック',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
                if (newCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB91C1C),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '未対応 $newCount',
                      style: const TextStyle(
                        color: Color(0xFFE5E7EB),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onRefresh,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 件数サマリー
            if (!loading) ...[
              Row(
                children: [
                  _feedbackCountChip('未対応', newCount, const Color(0xFFB91C1C)),
                  const SizedBox(width: 8),
                  _feedbackCountChip(
                    '確認済',
                    feedbacks.where((f) => f['status'] == 'reviewed').length,
                    const Color(0xFFFF6B35),
                  ),
                  const SizedBox(width: 8),
                  _feedbackCountChip(
                    '対応完',
                    feedbacks.where((f) => f['status'] == 'implemented').length,
                    const Color(0xFF0D9488),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // 最新フィードバックインライン表示
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (feedbacks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'フィードバックはまだありません',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
              )
            else
              ...(feedbacks
                  .take(5)
                  .map((fb) => _buildFeedbackInlineRow(context, fb))),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text('全${feedbacks.length}件を管理する'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: onOpenManageAll,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feedbackCountChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildFeedbackInlineRow(
    BuildContext context,
    Map<String, dynamic> fb,
  ) {
    final status = fb['status'] as String? ?? 'new';
    final category = fb['category'] as String? ?? 'other';
    final content = fb['content'] as String? ?? '';
    final issueUrl = fb['github_issue_url'] as String?;
    final id = fb['id'] as int;

    final statusColor = status == 'new'
        ? const Color(0xFFB91C1C)
        : status == 'reviewed'
            ? const Color(0xFFFF6B35)
            : const Color(0xFF0D9488);
    final categoryIcon = category == 'feature'
        ? Icons.lightbulb_outline
        : category == 'bug'
            ? Icons.bug_report_outlined
            : Icons.chat_bubble_outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: statusColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  categoryIcon,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status == 'new'
                        ? '未対応'
                        : status == 'reviewed'
                            ? '確認済'
                            : '対応完',
                    style: TextStyle(
                      fontSize: 10,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            if (issueUrl != null) ...[
              const SizedBox(height: 4),
              Text(
                'Issue: $issueUrl',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.primary,
                  height: 1.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (status == 'new') ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => onUpdateStatus(id, 'reviewed'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '確認済にする',
                      style: TextStyle(fontSize: 11, height: 1.5),
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () => onUpdateStatus(id, 'implemented'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: const Color(0xFF0D9488),
                    ),
                    child: const Text(
                      '対応完了',
                      style: TextStyle(fontSize: 11, height: 1.5),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
