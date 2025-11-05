import '../models/note.dart';
import '../models/sort_type.dart';

/// ノートのフィルタリングとソート機能を提供するサービス
class NoteFilterService {
  /// フィルター条件
  final String searchQuery;
  final String? searchCategoryId;
  final DateTime? searchStartDate;
  final DateTime? searchEndDate;
  final String? selectedCategoryId;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool showFavoritesOnly;
  final String? reminderFilter;

  NoteFilterService({
    this.searchQuery = '',
    this.searchCategoryId,
    this.searchStartDate,
    this.searchEndDate,
    this.selectedCategoryId,
    this.startDate,
    this.endDate,
    this.showFavoritesOnly = false,
    this.reminderFilter,
  });

  /// ノートをフィルタリング
  List<Note> filterNotes(List<Note> notes) {
    List<Note> filtered = List.from(notes);

    // 検索キーワードでフィルター
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((note) {
        final titleLower = note.title.toLowerCase();
        final contentLower = note.content.toLowerCase();
        return titleLower.contains(query) || contentLower.contains(query);
      }).toList();
    }

    // 高度な検索：カテゴリフィルター（検索ダイアログから）
    if (searchCategoryId != null) {
      filtered = filtered
          .where((note) => note.categoryId == searchCategoryId)
          .toList();
    }
    // 通常のカテゴリフィルター（メニューから）
    else if (selectedCategoryId != null) {
      if (selectedCategoryId == 'uncategorized') {
        filtered = filtered.where((note) => note.categoryId == null).toList();
      } else {
        filtered = filtered
            .where((note) => note.categoryId == selectedCategoryId)
            .toList();
      }
    }

    // 高度な検索：日付範囲フィルター（検索ダイアログから）
    if (searchStartDate != null || searchEndDate != null) {
      filtered = filtered.where((note) {
        if (searchStartDate != null &&
            note.createdAt.isBefore(searchStartDate!)) {
          return false;
        }
        if (searchEndDate != null) {
          final endOfDay = DateTime(
            searchEndDate!.year,
            searchEndDate!.month,
            searchEndDate!.day,
            23,
            59,
            59,
          );
          if (note.createdAt.isAfter(endOfDay)) {
            return false;
          }
        }
        return true;
      }).toList();
    }
    // 通常の日付フィルター（メニューから）
    else if (startDate != null || endDate != null) {
      filtered = filtered.where((note) {
        if (startDate != null && note.updatedAt.isBefore(startDate!)) {
          return false;
        }
        if (endDate != null) {
          final endOfDay = DateTime(
            endDate!.year,
            endDate!.month,
            endDate!.day,
            23,
            59,
            59,
          );
          if (note.updatedAt.isAfter(endOfDay)) {
            return false;
          }
        }
        return true;
      }).toList();
    }

    // お気に入りフィルター
    if (showFavoritesOnly) {
      filtered = filtered.where((note) => note.isFavorite).toList();
    }

    // リマインダーフィルター
    if (reminderFilter != null) {
      final now = DateTime.now();
      filtered = filtered.where((note) {
        if (note.reminderDate == null) {
          return false;
        }

        switch (reminderFilter) {
          case 'overdue':
            return note.reminderDate!.isBefore(now);
          case 'today':
            final today = DateTime(now.year, now.month, now.day);
            final tomorrow = today.add(const Duration(days: 1));
            return note.reminderDate!.isAfter(today) &&
                note.reminderDate!.isBefore(tomorrow);
          case 'upcoming':
            final tomorrow = now.add(const Duration(days: 1));
            return note.reminderDate!.isAfter(now) &&
                note.reminderDate!.isBefore(tomorrow);
          default:
            return true;
        }
      }).toList();
    }

    return filtered;
  }

  /// ノートをソート（ピン留めを考慮）
  static void sortNotes(List<Note> notes, SortType sortType) {
    // まず通常のソートを適用
    sortType.sortNotes(notes);

    // ピン留めメモを最上部に移動（安定ソート）
    notes.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return 0;
    });
  }

  /// リマインダー統計を計算
  static Map<String, int> calculateReminderStats(List<Note> notes) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    int overdueCount = 0;
    int dueSoonCount = 0;
    int todayCount = 0;

    for (final note in notes) {
      if (note.reminderDate != null) {
        if (note.isOverdue) {
          overdueCount++;
        }
        if (note.isDueSoon) {
          dueSoonCount++;
        }
        if (note.reminderDate!.isAfter(today) &&
            note.reminderDate!.isBefore(tomorrow)) {
          todayCount++;
        }
      }
    }

    return {
      'overdue': overdueCount,
      'dueSoon': dueSoonCount,
      'today': todayCount,
    };
  }
}
