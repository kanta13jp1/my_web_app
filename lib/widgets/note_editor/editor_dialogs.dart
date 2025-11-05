import 'package:flutter/material.dart';
import '../../models/category.dart';

/// リマインダー設定ダイアログを表示
Future<void> showReminderDialog({
  required BuildContext context,
  required DateTime? currentReminder,
  required Function(DateTime?) onReminderSet,
}) async {
  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('リマインダーを設定'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: const Text('日付'),
                subtitle: Text(
                  selectedDate != null
                      ? '${selectedDate!.year}/${selectedDate!.month}/${selectedDate!.day}'
                      : '日付を選択',
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setDialogState(() {
                      selectedDate = date;
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: const Text('時刻'),
                subtitle: Text(
                  selectedTime != null
                      ? '${selectedTime!.hour}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                      : '時刻を選択',
                ),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: selectedTime ?? TimeOfDay.now(),
                  );
                  if (time != null) {
                    setDialogState(() {
                      selectedTime = time;
                    });
                  }
                },
              ),
              if (currentReminder != null) ...[
                const Divider(),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '現在の設定: ${_formatReminderDate(currentReminder)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (currentReminder != null)
              TextButton(
                onPressed: () {
                  onReminderSet(null);
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('削除'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: selectedDate != null && selectedTime != null
                  ? () {
                      final reminderDate = DateTime(
                        selectedDate!.year,
                        selectedDate!.month,
                        selectedDate!.day,
                        selectedTime!.hour,
                        selectedTime!.minute,
                      );
                      onReminderSet(reminderDate);
                      Navigator.pop(context);
                    }
                  : null,
              child: const Text('設定'),
            ),
          ],
        );
      },
    ),
  );
}

/// カテゴリ選択ダイアログを表示
Future<void> showCategoryDialog({
  required BuildContext context,
  required List<Category> categories,
  required String? selectedCategoryId,
  required Function(String?) onCategorySelected,
}) async {
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('カテゴリを選択'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.clear),
              title: const Text('カテゴリなし'),
              trailing: selectedCategoryId == null
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
              onTap: () {
                onCategorySelected(null);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ...categories.map((category) {
              final color = Color(
                  int.parse(category.color.substring(1), radix: 16) + 0xFF000000);
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(category.icon, style: const TextStyle(fontSize: 20)),
                  ),
                ),
                title: Text(category.name),
                trailing: selectedCategoryId == category.id
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  onCategorySelected(category.id);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    ),
  );
}

/// マークダウン記法ヘルプダイアログを表示
void showMarkdownHelp(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('マークダウン記法'),
      content: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('# 見出し1', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('## 見出し2', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('**太字**'),
            Text('*斜体*'),
            Text('~~取り消し線~~'),
            SizedBox(height: 8),
            Text('- リスト項目'),
            Text('1. 番号付きリスト'),
            SizedBox(height: 8),
            Text('[リンク](https://example.com)'),
            SizedBox(height: 8),
            Text('```dart\nコードブロック\n```'),
            Text('`インラインコード`'),
            SizedBox(height: 8),
            Text('> 引用'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          child: const Text('閉じる'),
        ),
      ],
    ),
  );
}

/// リマインダー日時を読みやすくフォーマット
String _formatReminderDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final targetDay = DateTime(date.year, date.month, date.day);

  String dateStr;
  if (targetDay == today) {
    dateStr = '今日';
  } else if (targetDay == tomorrow) {
    dateStr = '明日';
  } else {
    dateStr = '${date.month}/${date.day}';
  }

  return '$dateStr ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
}
