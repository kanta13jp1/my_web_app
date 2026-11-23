import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminWaitlistCard extends StatelessWidget {
  const AdminWaitlistCard({
    super.key,
    required this.waitlistEmails,
    required this.loading,
    required this.sendingNotification,
    required this.onSendNotification,
    required this.onRefresh,
  });

  final List<Map<String, dynamic>> waitlistEmails;
  final bool loading;
  final bool sendingNotification;
  final VoidCallback onSendNotification;
  final VoidCallback onRefresh;

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
                const Icon(Icons.mail_outline, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'メールウェイトリスト (${waitlistEmails.length}件)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ),
                if (sendingNotification)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton.icon(
                    onPressed:
                        waitlistEmails.isEmpty ? null : onSendNotification,
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('通知送信'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6366F1),
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
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (waitlistEmails.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '登録者はまだいません',
                  style: TextStyle(color: Color(0xFF9CA3AF), height: 1.5),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: waitlistEmails.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = waitlistEmails[index];
                  final email = entry['email']?.toString() ?? '';
                  final source = entry['source']?.toString() ?? '';
                  final createdAt = entry['created_at']?.toString() ?? '';
                  String dateStr = createdAt;
                  try {
                    dateStr = DateFormat(
                      'MM/dd HH:mm',
                    ).format(DateTime.parse(createdAt).toLocal());
                  } catch (_) {}

                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.person_outline,
                      size: 20,
                      color: Color(0xFF6366F1),
                    ),
                    title: Text(
                      email,
                      style: const TextStyle(fontSize: 13, height: 1.6),
                    ),
                    subtitle: Text(
                      '$source  $dateStr',
                      style: const TextStyle(fontSize: 11, height: 1.5),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
