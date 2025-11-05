import 'package:flutter/material.dart';
import '../../models/note.dart';
import '../../models/category.dart';
import '../share_note_card_dialog.dart';
import '../../pages/note_editor_page.dart';

/// アーカイブ確認ダイアログを表示
void showArchiveDialog({
  required BuildContext context,
  required Note note,
  required VoidCallback onArchive,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('メモをアーカイブ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '「${note.title.isEmpty ? '(タイトルなし)' : note.title}」をアーカイブしますか？',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'アーカイブから復元できます',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onArchive();
          },
          child: const Text('アーカイブ'),
        ),
      ],
    ),
  );
}

/// 削除確認ダイアログを表示
void showDeleteDialog({
  required BuildContext context,
  required Note note,
  required VoidCallback onDelete,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('メモを削除'),
      content: const Text('このメモを削除しますか？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onDelete();
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('削除'),
        ),
      ],
    ),
  );
}

/// 共有オプションダイアログを表示
void showShareOptionsDialog({
  required BuildContext context,
  required Note note,
  required Category? category,
  required VoidCallback onShareAsCard,
  required VoidCallback onShareAsLink,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('共有方法を選択'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.image, color: Colors.blue),
            title: const Text('メモカードとして共有'),
            subtitle: const Text('SNSで映える画像を作成'),
            onTap: () {
              Navigator.pop(context);
              onShareAsCard();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.link, color: Colors.green),
            title: const Text('リンクとして共有'),
            subtitle: const Text('テキストURLで共有'),
            onTap: () {
              Navigator.pop(context);
              onShareAsLink();
            },
          ),
        ],
      ),
    ),
  );
}

/// クイックリマインダー設定ダイアログを表示
Future<void> showQuickReminderDialog({
  required BuildContext context,
  required Note note,
  required Function(DateTime?) onReminderSet,
  required VoidCallback onLoadNotes,
}) async {
  final now = DateTime.now();

  await showModalBottomSheet(
    context: context,
    builder: (context) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'クイックリマインダー',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.access_time, color: Colors.blue),
              title: const Text('1時間後'),
              onTap: () async {
                final reminderDate = now.add(const Duration(hours: 1));
                Navigator.pop(context);
                await onReminderSet(reminderDate);
              },
            ),
            ListTile(
              leading: const Icon(Icons.today, color: Colors.orange),
              title: const Text('今日の18:00'),
              onTap: () async {
                final reminderDate = DateTime(now.year, now.month, now.day, 18, 0);
                Navigator.pop(context);
                await onReminderSet(reminderDate);
              },
            ),
            ListTile(
              leading: const Icon(Icons.event, color: Colors.green),
              title: const Text('明日の9:00'),
              onTap: () async {
                final tomorrow = now.add(const Duration(days: 1));
                final reminderDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);
                Navigator.pop(context);
                await onReminderSet(reminderDate);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month, color: Colors.purple),
              title: const Text('カスタム設定'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NoteEditorPage(note: note),
                  ),
                ).then((_) => onLoadNotes());
              },
            ),
            if (note.reminderDate != null)
              ListTile(
                leading: const Icon(Icons.alarm_off, color: Colors.red),
                title: const Text('リマインダーを削除'),
                onTap: () async {
                  Navigator.pop(context);
                  await onReminderSet(null);
                },
              ),
          ],
        ),
      );
    },
  );
}

/// メモカード共有ダイアログを表示
void showNoteCardDialog({
  required BuildContext context,
  required Note note,
  required Category? category,
}) {
  showDialog(
    context: context,
    builder: (context) => ShareNoteCardDialog(
      note: note,
      category: category,
    ),
  );
}
