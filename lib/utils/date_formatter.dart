/// 日付フォーマットユーティリティ
class DateFormatter {
  /// 相対的な時間表示（例: "たった今", "3分前", "2日前"）
  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'たった今';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分前';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}時間前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}日前';
    } else {
      return '${date.year}/${date.month}/${date.day}';
    }
  }

  /// 短い日付表示（例: "12/25"）
  static String formatShort(DateTime date) {
    return '${date.month}/${date.day}';
  }

  /// 完全な日付表示（例: "2024年12月25日"）
  static String formatFull(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  /// 日時表示（例: "2024/12/25 14:30"）
  static String formatDateTime(DateTime date) {
    return '${date.year}/${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// 日付範囲のラベルを取得
  static String getDateRangeLabel(DateTime? startDate, DateTime? endDate) {
    if (startDate != null && endDate != null) {
      return '${formatShort(startDate)} 〜 ${formatShort(endDate)}';
    } else if (startDate != null) {
      return '${formatShort(startDate)} 以降';
    } else if (endDate != null) {
      return '${formatShort(endDate)} まで';
    }
    return '';
  }

  /// リマインダーの日付を表示（例: "今日 14:30", "明日 10:00", "12/25 15:00"）
  static String formatReminder(DateTime date) {
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
