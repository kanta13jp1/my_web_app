import 'package:flutter/material.dart';
import '../../pages/archive_page.dart';
import '../../pages/categories_page.dart';
import '../../pages/stats_page.dart';
import '../../pages/leaderboard_page.dart';
import '../../pages/settings_page.dart';
import '../../services/search_history_service.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isSearching;
  final TextEditingController searchController;
  final VoidCallback onToggleSearch;
  final VoidCallback onShowAdvancedSearch;
  final VoidCallback onShowReminderFilter;
  final VoidCallback onShowCategoryFilter;
  final VoidCallback onShowSortDialog;
  final VoidCallback onShowDateFilter;
  final VoidCallback onToggleFavorites;
  final VoidCallback onRefresh;
  final VoidCallback onSignOut;
  final VoidCallback onLoadUserStats;
  final bool isMobile;
  final bool hasActiveAdvancedFilters;
  final String? reminderFilter;
  final bool showFavoritesOnly;
  final bool hasCategoryFilter;
  final bool hasDateFilter;

  const HomeAppBar({
    Key? key,
    required this.isSearching,
    required this.searchController,
    required this.onToggleSearch,
    required this.onShowAdvancedSearch,
    required this.onShowReminderFilter,
    required this.onShowCategoryFilter,
    required this.onShowSortDialog,
    required this.onShowDateFilter,
    required this.onToggleFavorites,
    required this.onRefresh,
    required this.onSignOut,
    required this.onLoadUserStats,
    required this.isMobile,
    required this.hasActiveAdvancedFilters,
    required this.reminderFilter,
    required this.showFavoritesOnly,
    required this.hasCategoryFilter,
    required this.hasDateFilter,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: isSearching
          ? TextField(
              controller: searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'メモを検索...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 18),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  SearchHistoryService.saveSearch(value);
                }
              },
            )
          : const Text('マイメモ'),
      actions: [
        if (isSearching)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              searchController.clear();
            },
            tooltip: 'クリア',
          ),
        IconButton(
          icon: Icon(isSearching ? Icons.close : Icons.search),
          onPressed: onToggleSearch,
          tooltip: isSearching ? '検索を閉じる' : '検索',
        ),
        if (!isMobile) ...[
          IconButton(
            icon: Icon(
              Icons.tune,
              color: hasActiveAdvancedFilters ? Colors.purple : null,
            ),
            tooltip: '詳細検索',
            onPressed: onShowAdvancedSearch,
          ),
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  reminderFilter != null ? Icons.alarm_on : Icons.alarm,
                  color: reminderFilter != null ? Colors.orange : null,
                ),
                onPressed: onShowReminderFilter,
                tooltip: 'リマインダーで絞り込み',
              ),
              if (reminderFilter != null)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  showFavoritesOnly ? Icons.star : Icons.star_border,
                  color: showFavoritesOnly ? Colors.amber : null,
                ),
                onPressed: onToggleFavorites,
                tooltip: showFavoritesOnly ? 'すべて表示' : 'お気に入りのみ表示',
              ),
              if (showFavoritesOnly)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.category),
                onPressed: onShowCategoryFilter,
                tooltip: 'カテゴリで絞り込み',
              ),
              if (hasCategoryFilter)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: onShowSortDialog,
            tooltip: '並び替え',
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: onShowDateFilter,
                tooltip: '日付で絞り込み',
              ),
              if (hasDateFilter)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: onRefresh,
          tooltip: '更新',
        ),
        _buildPopupMenu(context),
      ],
    );
  }

  Widget _buildPopupMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'advanced_search') {
          onShowAdvancedSearch();
        } else if (value == 'reminder_filter') {
          onShowReminderFilter();
        } else if (value == 'favorite_filter') {
          onToggleFavorites();
        } else if (value == 'category_filter') {
          onShowCategoryFilter();
        } else if (value == 'sort') {
          onShowSortDialog();
        } else if (value == 'date_filter') {
          onShowDateFilter();
        } else if (value == 'categories') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CategoriesPage()),
          ).then((_) {
            onRefresh();
          });
        } else if (value == 'archive') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ArchivePage()),
          ).then((_) {
            onRefresh();
          });
        } else if (value == 'stats') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StatsPage()),
          ).then((_) {
            onLoadUserStats();
          });
        } else if (value == 'leaderboard') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LeaderboardPage()),
          ).then((_) {
            onLoadUserStats();
          });
        } else if (value == 'settings') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          );
        } else if (value == 'logout') {
          onSignOut();
        }
      },
      itemBuilder: (context) => [
        if (isMobile) ...[
          const PopupMenuItem(
            value: 'advanced_search',
            child: Row(
              children: [
                Icon(Icons.tune, color: Colors.purple),
                SizedBox(width: 8),
                Text('詳細検索'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'reminder_filter',
            child: Row(
              children: [
                Icon(Icons.alarm, color: Colors.orange),
                SizedBox(width: 8),
                Text('リマインダー'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'favorite_filter',
            child: Row(
              children: [
                Icon(
                  showFavoritesOnly ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
                const SizedBox(width: 8),
                Text(showFavoritesOnly ? 'すべて表示' : 'お気に入り'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'category_filter',
            child: Row(
              children: [
                Icon(Icons.category, color: Colors.green),
                SizedBox(width: 8),
                Text('カテゴリ'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'sort',
            child: Row(
              children: [
                Icon(Icons.sort, color: Colors.blue),
                SizedBox(width: 8),
                Text('並び替え'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'date_filter',
            child: Row(
              children: [
                Icon(Icons.filter_list, color: Colors.red),
                SizedBox(width: 8),
                Text('日付'),
              ],
            ),
          ),
          const PopupMenuDivider(),
        ],
        const PopupMenuItem(
          value: 'categories',
          child: Row(
            children: [
              Icon(Icons.category_outlined),
              SizedBox(width: 8),
              Text('カテゴリ管理'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'archive',
          child: Row(
            children: [
              Icon(Icons.archive_outlined),
              SizedBox(width: 8),
              Text('アーカイブ'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'stats',
          child: Row(
            children: [
              Icon(Icons.bar_chart),
              SizedBox(width: 8),
              Text('統計'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'leaderboard',
          child: Row(
            children: [
              Icon(Icons.emoji_events),
              SizedBox(width: 8),
              Text('リーダーボード'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings),
              SizedBox(width: 8),
              Text('設定'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout),
              SizedBox(width: 8),
              Text('ログアウト'),
            ],
          ),
        ),
      ],
    );
  }
}
