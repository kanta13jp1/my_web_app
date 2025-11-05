import 'package:flutter/material.dart';
import '../../models/note.dart';
import '../../models/category.dart';
import '../../services/attachment_cache_service.dart';
import '../../utils/date_formatter.dart';

class NoteCardItem extends StatelessWidget {
  final Note note;
  final Category? category;
  final String searchQuery;
  final bool isMobile;
  final VoidCallback onTap;
  final Function(Note) onTogglePin;
  final Function(Note) onArchive;
  final Function(Note) onShare;
  final Function(Note) onSetReminder;
  final Function(Note) onToggleFavorite;
  final Function(Note) onDelete;

  const NoteCardItem({
    super.key,
    required this.note,
    required this.category,
    required this.searchQuery,
    required this.isMobile,
    required this.onTap,
    required this.onTogglePin,
    required this.onArchive,
    required this.onShare,
    required this.onSetReminder,
    required this.onToggleFavorite,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    Color? categoryColor;
    if (category != null) {
      categoryColor = Color(
        int.parse(category!.color.substring(1), radix: 16) + 0xFF000000,
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: note.isPinned
          ? (Theme.of(context).brightness == Brightness.dark
              ? Colors.amber.withValues(alpha: 0.15)
              : Colors.amber.withValues(alpha: 0.1))
          : note.reminderDate != null && note.isOverdue
              ? (Theme.of(context).brightness == Brightness.dark
                  ? Colors.red.withValues(alpha: 0.15)
                  : Colors.red.withValues(alpha: 0.05))
              : null,
      shape: note.reminderDate != null && note.isOverdue
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: const BorderSide(color: Colors.red, width: 2),
            )
          : note.isPinned
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.amber.shade600
                        : Colors.amber.shade700,
                    width: 2,
                  ),
                )
              : null,
      child: ListTile(
        leading: _buildLeading(categoryColor),
        title: _buildTitle(),
        subtitle: _buildSubtitle(categoryColor),
        trailing: _buildTrailing(context),
        onTap: onTap,
      ),
    );
  }

  Widget? _buildLeading(Color? categoryColor) {
    if (category != null) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: categoryColor!.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(color: categoryColor, width: 2),
        ),
        child: Center(
          child: Text(
            category!.icon,
            style: const TextStyle(fontSize: 20),
          ),
        ),
      );
    } else if (note.isFavorite) {
      return const Icon(Icons.star, color: Colors.amber, size: 32);
    }
    return null;
  }

  Widget _buildTitle() {
    return Row(
      children: [
        if (note.isPinned) ...[
          Icon(Icons.push_pin, color: Colors.amber.shade700, size: 18),
          const SizedBox(width: 4),
        ],
        if (note.reminderDate != null) ...[
          Icon(
            note.isOverdue
                ? Icons.alarm_off
                : note.isDueSoon
                    ? Icons.alarm_on
                    : Icons.alarm,
            color: note.isOverdue
                ? Colors.red
                : note.isDueSoon
                    ? Colors.orange
                    : Colors.grey,
            size: 18,
          ),
          const SizedBox(width: 4),
        ],
        if (note.isFavorite && category != null) ...[
          const Icon(Icons.star, color: Colors.amber, size: 18),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: _buildHighlightedText(
            note.title.isEmpty ? '(タイトルなし)' : note.title,
            searchQuery,
            isTitle: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitle(Color? categoryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (note.content.isNotEmpty) ...[
          SizedBox(height: isMobile ? 2 : 4),
          _buildHighlightedText(
            note.content,
            searchQuery,
            maxLines: isMobile ? 1 : 2,
          ),
        ],
        SizedBox(height: isMobile ? 2 : 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1行目：ピン留め、リマインダー、カテゴリ
            Row(
              children: [
                if (note.isPinned) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.push_pin, size: 10, color: Colors.white),
                        SizedBox(width: 2),
                        Text(
                          'ピン留め',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (note.reminderDate != null) ...[
                  Icon(
                    Icons.alarm,
                    size: 12,
                    color: note.isOverdue
                        ? Colors.red
                        : note.isDueSoon
                            ? Colors.orange
                            : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatReminderDate(note.reminderDate!),
                    style: TextStyle(
                      fontSize: 12,
                      color: note.isOverdue
                          ? Colors.red
                          : note.isDueSoon
                              ? Colors.orange
                              : Colors.grey[600],
                      fontWeight: note.isOverdue || note.isDueSoon
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('•', style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(width: 8),
                ],
                if (category != null) ...[
                  Text(category!.icon, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      category!.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: categoryColor,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ],
            ),
            // 2行目：添付ファイル数と更新日時
            SizedBox(height: isMobile ? 2 : 4),
            Row(
              children: [
                FutureBuilder<int>(
                  future: AttachmentCacheService.getAttachmentCount(note.id),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    if (count == 0) {
                      return const SizedBox.shrink();
                    }
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.attach_file, size: 12, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          '$count',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('•', style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(width: 8),
                      ],
                    );
                  },
                ),
                Flexible(
                  child: Text(
                    '更新: ${DateFormatter.formatRelative(note.updatedAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrailing(BuildContext context) {
    if (isMobile) {
      return PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          switch (value) {
            case 'pin':
              onTogglePin(note);
              break;
            case 'archive':
              onArchive(note);
              break;
            case 'share':
              onShare(note);
              break;
            case 'reminder':
              onSetReminder(note);
              break;
            case 'favorite':
              onToggleFavorite(note);
              break;
            case 'delete':
              onDelete(note);
              break;
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'pin',
            child: Row(
              children: [
                Icon(
                  note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: note.isPinned ? Colors.amber : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(note.isPinned ? 'ピン留め解除' : 'ピン留め'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'favorite',
            child: Row(
              children: [
                Icon(
                  note.isFavorite ? Icons.star : Icons.star_border,
                  color: note.isFavorite ? Colors.amber : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(note.isFavorite ? 'お気に入り解除' : 'お気に入り'),
              ],
            ),
          ),
          if (note.reminderDate == null)
            const PopupMenuItem(
              value: 'reminder',
              child: Row(
                children: [
                  Icon(Icons.alarm_add, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('リマインダー'),
                ],
              ),
            ),
          const PopupMenuItem(
            value: 'share',
            child: Row(
              children: [
                Icon(Icons.share, color: Colors.blue),
                SizedBox(width: 8),
                Text('共有'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'archive',
            child: Row(
              children: [
                Icon(Icons.archive, color: Colors.grey),
                SizedBox(width: 8),
                Text('アーカイブ'),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, color: Colors.red),
                SizedBox(width: 8),
                Text('削除'),
              ],
            ),
          ),
        ],
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: note.isPinned ? Colors.amber.shade700 : Colors.grey,
            ),
            onPressed: () => onTogglePin(note),
            tooltip: note.isPinned ? 'ピン留めを解除' : 'ピン留め',
          ),
          IconButton(
            icon: const Icon(Icons.archive, color: Colors.grey),
            onPressed: () => onArchive(note),
            tooltip: 'アーカイブ',
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.blue),
            onPressed: () => onShare(note),
            tooltip: 'メモを共有',
          ),
          if (note.reminderDate == null)
            IconButton(
              icon: const Icon(Icons.alarm_add, color: Colors.grey),
              onPressed: () => onSetReminder(note),
              tooltip: 'リマインダーを設定',
            ),
          IconButton(
            icon: Icon(
              note.isFavorite ? Icons.star : Icons.star_border,
              color: note.isFavorite ? Colors.amber : Colors.grey,
            ),
            onPressed: () => onToggleFavorite(note),
            tooltip: note.isFavorite ? 'お気に入りから削除' : 'お気に入りに追加',
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => onDelete(note),
          ),
        ],
      );
    }
  }

  Widget _buildHighlightedText(
    String text,
    String query, {
    bool isTitle = false,
    int? maxLines,
  }) {
    if (query.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontWeight: isTitle ? FontWeight.bold : FontWeight.normal,
          fontSize: isMobile ? (isTitle ? 14 : 12) : (isTitle ? 16 : 14),
        ),
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start)));
        }
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: const TextStyle(
            backgroundColor: Colors.yellow,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      start = index + query.length;
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: Colors.black87,
          fontWeight: isTitle ? FontWeight.bold : FontWeight.normal,
          fontSize: isMobile ? (isTitle ? 14 : 12) : (isTitle ? 16 : 14),
        ),
        children: spans,
      ),
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
    );
  }

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
}
