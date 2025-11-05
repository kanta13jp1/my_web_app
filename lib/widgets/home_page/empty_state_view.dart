import 'package:flutter/material.dart';
import '../../models/note.dart';

/// ホームページの空状態表示ウィジェット
/// メモがない場合やフィルター結果が空の場合に表示
class EmptyStateView extends StatelessWidget {
  final bool hasAnyFilter;
  final bool showFavoritesOnly;
  final String? reminderFilter;
  final List<Note> allNotes;
  final VoidCallback onClearReminderFilter;
  final VoidCallback onClearFavoritesFilter;

  const EmptyStateView({
    Key? key,
    required this.hasAnyFilter,
    required this.showFavoritesOnly,
    required this.reminderFilter,
    required this.allNotes,
    required this.onClearReminderFilter,
    required this.onClearFavoritesFilter,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasAnyFilter || showFavoritesOnly
                ? Icons.search_off
                : Icons.note_add_outlined,
            size: 80,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[700]
                : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            hasAnyFilter || showFavoritesOnly
                ? '該当するメモが見つかりません'
                : 'メモがありません',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasAnyFilter || showFavoritesOnly
                ? 'フィルター条件を変更してみてください'
                : '右下の + ボタンから新しいメモを作成\n📌でピン留めして重要なメモを上部に固定',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          // リマインダーフィルター時の特別メッセージ
          if (reminderFilter != null && allNotes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              reminderFilter == 'overdue'
                  ? '期限切れのメモはありません'
                  : reminderFilter == 'today'
                      ? '今日のリマインダーはありません'
                      : '24時間以内のリマインダーはありません',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.alarm_add),
              label: const Text('メモにリマインダーを設定'),
              onPressed: onClearReminderFilter,
            ),
          ],
          if (showFavoritesOnly && allNotes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'お気に入りメモがまだありません',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.star_border),
              label: const Text('メモにスターをつけてみましょう'),
              onPressed: onClearFavoritesFilter,
            ),
          ],
        ],
      ),
    );
  }
}
