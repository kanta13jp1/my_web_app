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
}
