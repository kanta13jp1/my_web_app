import 'package:flutter/material.dart';

class AdminAutomationOpsCard extends StatelessWidget {
  const AdminAutomationOpsCard({
    super.key,
    required this.digest,
    required this.supportTickets,
    required this.loading,
    required this.postingX,
    required this.error,
    required this.onRefresh,
    required this.onPostX,
    required this.onReplyTicket,
  });

  final Map<String, dynamic>? digest;
  final List<Map<String, dynamic>> supportTickets;
  final bool loading;
  final bool postingX;
  final String? error;
  final VoidCallback onRefresh;
  final VoidCallback onPostX;
  final void Function(Map<String, dynamic> ticket) onReplyTicket;

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final resolvedDigest = digest ?? <String, dynamic>{};
    final users = resolvedDigest['users'] is Map
        ? Map<String, dynamic>.from(resolvedDigest['users'] as Map)
        : <String, dynamic>{};
    final featureRequests = resolvedDigest['featureRequests'] is Map
        ? Map<String, dynamic>.from(resolvedDigest['featureRequests'] as Map)
        : <String, dynamic>{};
    final recentAchievements =
        resolvedDigest['recentAchievements'] as List? ?? const [];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF4338CA)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '自動化オペレーション',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton.icon(
                    onPressed: postingX ? null : onPostX,
                    icon: const Icon(Icons.send, size: 16),
                    label: Text(postingX ? '投稿中...' : 'X投稿テスト'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF4338CA),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: onRefresh,
                  tooltip: '更新',
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Claude Schedule の定期実行に合わせた CS キューと日次ダイジェストをここで手動確認できます。',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            if (error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFB91C1C).withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFB91C1C).withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  error!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB91C1C),
                    height: 1.5,
                  ),
                ),
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildAutomationMetricChip(
                    label: '総ユーザー',
                    value: '${_toInt(users['total'])}人',
                    color: const Color(0xFF6366F1),
                  ),
                  _buildAutomationMetricChip(
                    label: '新規要望',
                    value: '${_toInt(featureRequests['newToday'])}件',
                    color: const Color(0xFFFF6B35),
                  ),
                  _buildAutomationMetricChip(
                    label: '未対応要望',
                    value: '${_toInt(featureRequests['openCount'])}件',
                    color: const Color(0xFF6366F1),
                  ),
                  _buildAutomationMetricChip(
                    label: '直近実績',
                    value: '${recentAchievements.length}件',
                    color: const Color(0xFF0D9488),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'CSキュー (${supportTickets.length}件)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              if (supportTickets.isEmpty)
                const Text(
                  '未返信チケットはありません',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                    height: 1.5,
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount:
                      supportTickets.length > 5 ? 5 : supportTickets.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final ticket = supportTickets[index];
                    final title = ticket['title']?.toString() ?? '(無題)';
                    final votes = _toInt(ticket['votes']);
                    final email = ticket['email']?.toString();
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(
                          0xFF6366F1,
                        ).withValues(alpha: 0.07),
                        child: Text(
                          '$votes',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4338CA),
                            height: 1.5,
                          ),
                        ),
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(fontSize: 12, height: 1.5),
                      ),
                      subtitle: Text(
                        email == null || email.isEmpty ? 'メール未登録' : email,
                        style: const TextStyle(fontSize: 11, height: 1.5),
                      ),
                      trailing: TextButton(
                        onPressed: () => onReplyTicket(ticket),
                        child: const Text('返信'),
                      ),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAutomationMetricChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color, height: 1.5),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
