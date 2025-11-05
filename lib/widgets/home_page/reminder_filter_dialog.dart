import 'package:flutter/material.dart';
import '../../models/note.dart';

/// リマインダーフィルターダイアログ
class ReminderFilterDialog extends StatelessWidget {
  final String? currentFilter;
  final List<Note> notes;
  final ValueChanged<String?> onFilterChanged;

  const ReminderFilterDialog({
    super.key,
    required this.currentFilter,
    required this.notes,
    required this.onFilterChanged,
  });

  int _countOverdue() {
    return notes.where((n) => n.reminderDate != null && n.isOverdue).length;
  }

  int _countToday() {
    return notes.where((n) {
      if (n.reminderDate == null) return false;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      return n.reminderDate!.isAfter(today) &&
          n.reminderDate!.isBefore(tomorrow);
    }).length;
  }

  int _countUpcoming() {
    return notes.where((n) => n.reminderDate != null && n.isDueSoon).length;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ヘッダー部分
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.alarm, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'リマインダーで絞り込み',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('完了'),
                ),
              ],
            ),
          ),
          const Divider(),

          // スクロール可能なコンテンツ部分
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 全て表示
                  ListTile(
                    leading:
                        const Icon(Icons.all_inclusive, color: Colors.blue),
                    title: const Text('すべて表示'),
                    trailing: currentFilter == null
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      onFilterChanged(null);
                      Navigator.pop(context);
                    },
                  ),
                  // 期限切れ
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.alarm_off, color: Colors.red),
                    ),
                    title: const Text('期限切れ'),
                    subtitle: Text(
                      '${_countOverdue()}件',
                      style: const TextStyle(color: Colors.red),
                    ),
                    trailing: currentFilter == 'overdue'
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      onFilterChanged('overdue');
                      Navigator.pop(context);
                    },
                  ),
                  // 今日
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.today, color: Colors.orange),
                    ),
                    title: const Text('今日'),
                    subtitle: Text(
                      '${_countToday()}件',
                      style: TextStyle(color: Colors.orange[800]),
                    ),
                    trailing: currentFilter == 'today'
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      onFilterChanged('today');
                      Navigator.pop(context);
                    },
                  ),
                  // 24時間以内
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.access_alarm,
                          color: Colors.amber),
                    ),
                    title: const Text('24時間以内'),
                    subtitle: Text(
                      '${_countUpcoming()}件',
                      style: TextStyle(color: Colors.amber[800]),
                    ),
                    trailing: currentFilter == 'upcoming'
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      onFilterChanged('upcoming');
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
