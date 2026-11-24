import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../pages/admin_dashboard_signals.dart';

class AdminFeatureRequestsCard extends StatelessWidget {
  const AdminFeatureRequestsCard({
    super.key,
    required this.requests,
    required this.loading,
    required this.onRefresh,
    required this.onReply,
    required this.onEditFields,
    required this.onUpdateStatus,
  });

  final List<Map<String, dynamic>> requests;
  final bool loading;
  final VoidCallback onRefresh;
  final void Function(Map<String, dynamic> req) onReply;
  final void Function(Map<String, dynamic> req) onEditFields;
  final void Function(
    String id,
    String newStatus,
    String title,
    String? email,
  ) onUpdateStatus;

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
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
                const Icon(Icons.lightbulb_outline, color: Color(0xFFFFC107)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '機能リクエスト管理',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                ),
                Text(
                  '${requests.length}件',
                  style: const TextStyle(color: Color(0xFF9CA3AF), height: 1.5),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: onRefresh,
                  tooltip: '更新',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (requests.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'リクエストはまだありません',
                  style: TextStyle(color: Color(0xFF9CA3AF), height: 1.5),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: requests.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final isDarkFR =
                      Theme.of(context).brightness == Brightness.dark;
                  final req = requests[index];
                  final id = req['id']?.toString() ?? '';
                  final title = req['title']?.toString() ?? '';
                  final email = req['email']?.toString();
                  final votes = _toInt(req['votes']);
                  final status = req['status']?.toString() ?? 'open';
                  final createdAt = req['created_at']?.toString() ?? '';
                  final adminReply = req['admin_reply']?.toString();
                  final adminRepliedAt = req['admin_replied_at']?.toString();
                  // R20: 年なし MM/dd は3か月前(04月)の要望を「今月」に見せる。
                  // 1か月超/別年は yyyy/ を前置して年齢を明示する。
                  final dateStr = formatAgeAwareDate(createdAt, DateTime.now());
                  String? repliedAtStr;
                  if (adminRepliedAt != null) {
                    try {
                      repliedAtStr = DateFormat(
                        'MM/dd HH:mm',
                      ).format(DateTime.parse(adminRepliedAt).toLocal());
                    } catch (_) {}
                  }

                  Color statusColor;
                  switch (status) {
                    case 'in_progress':
                      statusColor = const Color(0xFF6366F1);
                    case 'done':
                      statusColor = const Color(0xFF0D9488);
                    default:
                      statusColor = const Color(0xFFFF6B35);
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: index < 3
                              ? (isDarkFR
                                  ? const Color(0xFF2A1C06)
                                  : const Color(0xFFFEF3C7))
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          child: Text(
                            '$votes',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: index < 3
                                  ? (isDarkFR
                                      ? const Color(0xFFFDE68A)
                                      : const Color(0xFF92400E))
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(fontSize: 13, height: 1.6),
                        ),
                        subtitle: Row(
                          children: [
                            Text(
                              dateStr,
                              style: const TextStyle(fontSize: 11, height: 1.5),
                            ),
                            if (adminReply != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF6366F1,
                                  ).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF6366F1,
                                    ).withValues(alpha: 0.24),
                                  ),
                                ),
                                child: Text(
                                  'AI返信済 $repliedAtStr',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF6366F1),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: adminReply == null ? '返信する' : '返信を編集',
                              onPressed: () => onReply(req),
                              icon: Icon(
                                adminReply == null
                                    ? Icons.reply_outlined
                                    : Icons.edit_note_outlined,
                                size: 18,
                                color: const Color(0xFF4338CA),
                              ),
                            ),
                            IconButton(
                              tooltip: '優先度・工数・期日を設定',
                              onPressed: () => onEditFields(req),
                              icon: const Icon(
                                Icons.tune,
                                size: 18,
                                color: Color(0xFF3D5AFE),
                              ),
                            ),
                            PopupMenuButton<String>(
                              initialValue: status,
                              onSelected: (newStatus) => onUpdateStatus(
                                id,
                                newStatus,
                                title,
                                email,
                              ),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'open',
                                  child: Text('open'),
                                ),
                                PopupMenuItem(
                                  value: 'in_progress',
                                  child: Text('in_progress'),
                                ),
                                PopupMenuItem(
                                  value: 'done',
                                  child: Text('done'),
                                ),
                                PopupMenuItem(
                                  value: 'rejected',
                                  child: Text('rejected'),
                                ),
                              ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.31),
                                  ),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (adminReply != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF6366F1,
                              ).withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(
                                  0xFF6366F1,
                                ).withValues(alpha: 0.16),
                              ),
                            ),
                            child: Text(
                              'AI: $adminReply',
                              // R20: 数百字の返信が50件リストを支配する wall-of-text
                              // を抑制。全文は返信編集ダイアログで到達可能=無損失。
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF4338CA),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
