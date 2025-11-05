import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/note.dart';
import '../../models/category.dart';
import '../../models/sort_type.dart';

class FilterChipsArea extends StatelessWidget {
  final bool hasAnyFilter;
  final SortType sortType;
  final bool showFavoritesOnly;
  final String? reminderFilter;
  final String searchText;
  final String? searchCategoryId;
  final DateTime? searchStartDate;
  final DateTime? searchEndDate;
  final String? selectedCategoryId;
  final DateTime? startDate;
  final DateTime? endDate;
  final String selectedDateFilter;
  final List<Note> filteredNotes;
  final List<Note> notes;
  final List<Category> categories;
  final bool isMobile;
  final Function(String?) onClearSearch;
  final Function(String?) onClearSearchCategory;
  final Function(DateTime?, DateTime?) onClearSearchDates;
  final Function(String?) onClearReminderFilter;
  final Function(bool) onClearFavoriteFilter;
  final Function(String?) onClearCategoryFilter;
  final Function(DateTime?, DateTime?, String) onClearDateFilter;
  final Function(SortType sortType) getSortIcon;

  const FilterChipsArea({
    super.key,
    required this.hasAnyFilter,
    required this.sortType,
    required this.showFavoritesOnly,
    required this.reminderFilter,
    required this.searchText,
    required this.searchCategoryId,
    required this.searchStartDate,
    required this.searchEndDate,
    required this.selectedCategoryId,
    required this.startDate,
    required this.endDate,
    required this.selectedDateFilter,
    required this.filteredNotes,
    required this.notes,
    required this.categories,
    required this.isMobile,
    required this.onClearSearch,
    required this.onClearSearchCategory,
    required this.onClearSearchDates,
    required this.onClearReminderFilter,
    required this.onClearFavoriteFilter,
    required this.onClearCategoryFilter,
    required this.onClearDateFilter,
    required this.getSortIcon,
  });

  @override
  Widget build(BuildContext context) {
    final hasDateFilter = startDate != null || endDate != null;
    final hasCategoryFilter = selectedCategoryId != null;

    if (!hasAnyFilter &&
        sortType == SortType.updatedDesc &&
        !showFavoritesOnly &&
        reminderFilter == null &&
        searchCategoryId == null &&
        searchStartDate == null &&
        searchEndDate == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      color: Colors.blue.withValues(alpha: 0.1),
      child: Wrap(
        spacing: isMobile ? 6 : 8,
        runSpacing: isMobile ? 6 : 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // 検索キーワード
          if (searchText.isNotEmpty)
            Chip(
              avatar: const Icon(Icons.search, size: 16),
              label: Text(
                '検索: "$searchText"',
                style: TextStyle(fontSize: isMobile ? 11 : 13),
              ),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => onClearSearch(null),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),

          // 高度な検索カテゴリフィルター
          if (searchCategoryId != null)
            _buildSearchCategoryChip(context),

          // 高度な検索日付フィルター
          if (searchStartDate != null || searchEndDate != null)
            Chip(
              avatar: const Icon(Icons.tune, size: 16, color: Colors.purple),
              label: Text(
                _getAdvancedDateFilterLabel(),
                style: TextStyle(fontSize: isMobile ? 11 : 13),
              ),
              backgroundColor: Colors.purple.withValues(alpha: 0.1),
              side: const BorderSide(color: Colors.purple, width: 2),
              deleteIcon: Icon(Icons.close, size: isMobile ? 14 : 16),
              onDeleted: () => onClearSearchDates(null, null),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),

          // リマインダーフィルターチップ
          if (reminderFilter != null)
            Chip(
              avatar: Icon(
                reminderFilter == 'overdue'
                    ? Icons.alarm_off
                    : reminderFilter == 'today'
                        ? Icons.today
                        : Icons.access_alarm,
                size: 16,
                color: reminderFilter == 'overdue' ? Colors.red : Colors.orange,
              ),
              label: Text(
                reminderFilter == 'overdue'
                    ? '期限切れ'
                    : reminderFilter == 'today'
                        ? '今日'
                        : '24時間以内',
                style: TextStyle(fontSize: isMobile ? 11 : 13),
              ),
              backgroundColor:
                  (reminderFilter == 'overdue' ? Colors.red : Colors.orange)
                      .withValues(alpha: 0.1),
              deleteIcon: Icon(Icons.close, size: isMobile ? 14 : 16),
              onDeleted: () => onClearReminderFilter(null),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),

          // お気に入りフィルター
          if (showFavoritesOnly)
            Chip(
              avatar: const Icon(Icons.star, size: 16, color: Colors.amber),
              label: Text(
                'お気に入りのみ',
                style: TextStyle(fontSize: isMobile ? 11 : 13),
              ),
              backgroundColor: Colors.amber.withValues(alpha: 0.1),
              deleteIcon: Icon(Icons.close, size: isMobile ? 14 : 16),
              onDeleted: () => onClearFavoriteFilter(false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),

          // カテゴリフィルター
          if (hasCategoryFilter) _buildCategoryChip(context),

          // 日付フィルター
          if (hasDateFilter)
            Chip(
              avatar: const Icon(Icons.calendar_today, size: 16),
              label: Text(
                _getDateFilterLabel(),
                style: TextStyle(fontSize: isMobile ? 11 : 13),
              ),
              deleteIcon: Icon(Icons.close, size: isMobile ? 14 : 16),
              onDeleted: () => onClearDateFilter(null, null, '全期間'),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),

          // ソート表示
          if (sortType != SortType.updatedDesc)
            Chip(
              avatar: Icon(getSortIcon(sortType), size: 16),
              label: Text(
                sortType.label,
                style: TextStyle(fontSize: isMobile ? 11 : 13),
              ),
              backgroundColor: Colors.green.withValues(alpha: 0.1),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),

          // 件数表示
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${filteredNotes.length}件',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 11 : 13,
                ),
              ),
              if (!showFavoritesOnly && reminderFilter == null) ...[
                Text(
                  ' / ',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: isMobile ? 11 : 13,
                  ),
                ),
                Icon(Icons.push_pin,
                    color: Colors.amber, size: isMobile ? 14 : 16),
                Text(
                  ' ${notes.where((n) => n.isPinned).length}',
                  style: TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 11 : 13,
                  ),
                ),
                Text(
                  ' / ',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: isMobile ? 11 : 13,
                  ),
                ),
                Icon(Icons.star, color: Colors.amber, size: isMobile ? 14 : 16),
                Text(
                  ' ${notes.where((n) => n.isFavorite).length}',
                  style: TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 11 : 13,
                  ),
                ),
                if (notes.where((n) => n.reminderDate != null).isNotEmpty) ...[
                  Text(
                    ' / ',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: isMobile ? 11 : 13,
                    ),
                  ),
                  Icon(Icons.alarm,
                      color: Colors.orange, size: isMobile ? 14 : 16),
                  Text(
                    ' ${notes.where((n) => n.reminderDate != null).length}',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 11 : 13,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCategoryChip(BuildContext context) {
    final category = _getCategoryById(searchCategoryId);
    if (category == null) {
      return const SizedBox.shrink();
    }
    final color = Color(
      int.parse(category.color.substring(1), radix: 16) + 0xFF000000,
    );
    return Chip(
      avatar: Text(
        category.icon,
        style: TextStyle(fontSize: isMobile ? 14 : 16),
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            category.name,
            style: TextStyle(fontSize: isMobile ? 11 : 13),
          ),
          const SizedBox(width: 4),
          Icon(Icons.tune, size: isMobile ? 12 : 14),
        ],
      ),
      backgroundColor: color.withValues(alpha: 0.2),
      side: BorderSide(color: color, width: 2),
      deleteIcon: Icon(Icons.close, size: isMobile ? 14 : 16),
      onDeleted: () => onClearSearchCategory(null),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildCategoryChip(BuildContext context) {
    if (selectedCategoryId == 'uncategorized') {
      return Chip(
        avatar: const Icon(Icons.inbox, size: 16),
        label: Text(
          '未分類',
          style: TextStyle(fontSize: isMobile ? 11 : 13),
        ),
        backgroundColor: Colors.grey.withValues(alpha: 0.1),
        deleteIcon: Icon(Icons.close, size: isMobile ? 14 : 16),
        onDeleted: () => onClearCategoryFilter(null),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      );
    }
    final category = _getCategoryById(selectedCategoryId);
    if (category == null) {
      return const SizedBox.shrink();
    }
    final color = Color(
      int.parse(category.color.substring(1), radix: 16) + 0xFF000000,
    );
    return Chip(
      avatar: Text(
        category.icon,
        style: TextStyle(fontSize: isMobile ? 14 : 16),
      ),
      label: Text(
        category.name,
        style: TextStyle(fontSize: isMobile ? 11 : 13),
      ),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color, width: 1),
      deleteIcon: Icon(Icons.close, size: isMobile ? 14 : 16),
      onDeleted: () => onClearCategoryFilter(null),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Category? _getCategoryById(String? categoryId) {
    if (categoryId == null) return null;
    try {
      return categories.firstWhere((c) => c.id == categoryId);
    } catch (e) {
      return null;
    }
  }

  String _getDateFilterLabel() {
    if (selectedDateFilter == 'カスタム' || selectedDateFilter == '全期間') {
      final label = _getDateRangeLabel(startDate, endDate);
      if (label.isNotEmpty) return label;
    }
    return selectedDateFilter;
  }

  String _getDateRangeLabel(DateTime? start, DateTime? end) {
    if (start != null && end != null) {
      return '${DateFormat('MM/dd').format(start)} 〜 ${DateFormat('MM/dd').format(end)}';
    } else if (start != null) {
      return '${DateFormat('MM/dd').format(start)} 以降';
    } else if (end != null) {
      return '${DateFormat('MM/dd').format(end)} まで';
    }
    return '';
  }

  String _getAdvancedDateFilterLabel() {
    if (searchStartDate != null && searchEndDate != null) {
      return '${DateFormat('MM/dd').format(searchStartDate!)} 〜 ${DateFormat('MM/dd').format(searchEndDate!)}';
    } else if (searchStartDate != null) {
      return '${DateFormat('MM/dd').format(searchStartDate!)} 以降';
    } else if (searchEndDate != null) {
      return '${DateFormat('MM/dd').format(searchEndDate!)} まで';
    }
    return '日付';
  }
}
