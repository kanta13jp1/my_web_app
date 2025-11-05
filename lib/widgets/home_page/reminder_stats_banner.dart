import 'package:flutter/material.dart';
import '../../models/note.dart';

class ReminderStatsBanner extends StatelessWidget {
  final List<Note> notes;
  final int overdueCount;
  final int dueSoonCount;
  final int todayCount;
  final bool isMobile;
  final Function(String?) onFilterChanged;

  const ReminderStatsBanner({
    super.key,
    required this.notes,
    required this.overdueCount,
    required this.dueSoonCount,
    required this.todayCount,
    required this.isMobile,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (overdueCount == 0 && dueSoonCount == 0 && todayCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 8 : 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: overdueCount > 0
              ? (Theme.of(context).brightness == Brightness.dark
                  ? [Colors.red.shade900, Colors.red.shade800]
                  : [Colors.red.shade50, Colors.red.shade100])
              : (Theme.of(context).brightness == Brightness.dark
                  ? [Colors.orange.shade900, Colors.orange.shade800]
                  : [Colors.orange.shade50, Colors.orange.shade100]),
        ),
        border: Border(
          bottom: BorderSide(
            color: overdueCount > 0 ? Colors.red : Colors.orange,
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                overdueCount > 0 ? Icons.warning : Icons.info_outline,
                color: overdueCount > 0 ? Colors.red : Colors.orange,
                size: isMobile ? 18 : 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  overdueCount > 0
                      ? 'リマインダー通知があります'
                      : '期限が近いメモがあります',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: overdueCount > 0
                        ? Colors.red
                        : Colors.orange.shade900,
                  ),
                ),
              ),
              if (!isMobile)
                TextButton(
                  onPressed: () => onFilterChanged(null),
                  child: const Text('すべて表示'),
                ),
            ],
          ),
          SizedBox(height: isMobile ? 6 : 8),
          Wrap(
            spacing: isMobile ? 8 : 12,
            runSpacing: isMobile ? 6 : 8,
            children: [
              if (overdueCount > 0)
                _buildReminderStatChip(
                  icon: Icons.alarm_off,
                  label: '期限切れ',
                  count: overdueCount,
                  color: Colors.red,
                  onTap: () => onFilterChanged('overdue'),
                ),
              if (todayCount > 0)
                _buildReminderStatChip(
                  icon: Icons.today,
                  label: '今日',
                  count: todayCount,
                  color: Colors.orange,
                  onTap: () => onFilterChanged('today'),
                ),
              if (dueSoonCount > 0)
                _buildReminderStatChip(
                  icon: Icons.access_alarm,
                  label: '24時間以内',
                  count: dueSoonCount,
                  color: Colors.amber,
                  onTap: () => onFilterChanged('upcoming'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReminderStatChip({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
