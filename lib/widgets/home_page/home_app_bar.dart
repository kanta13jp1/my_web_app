import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../pages/archive_page.dart';
import '../../pages/categories_page.dart';
import '../../pages/stats_page.dart';
import '../../pages/leaderboard_page.dart';
import '../../pages/settings_page.dart';
import '../../pages/profile_settings_page.dart';
import '../../pages/share_philosopher_quote_dialog.dart';
import '../../pages/enhanced_statistics_page.dart';
import '../../pages/referral_page.dart';
import '../../pages/daily_challenges_page.dart';
import '../../pages/memo_gallery_page.dart';
import '../../pages/growth_dashboard_page.dart';
import '../../pages/template_marketplace_page.dart';
import '../../pages/import_page.dart';
import '../../pages/activity_feed_page.dart';
import '../../pages/ai_secretary_page.dart';
import '../../pages/personality_test_landing_page.dart';
import '../../pages/feedback_page.dart'; // ✅ 追加: フィードバックページ
import '../../services/search_history_service.dart';
import '../../services/app_share_service.dart';
import '../../models/user_stats.dart';

class HomeAppBar extends StatefulWidget implements PreferredSizeWidget {
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
  final UserStats? userStats;

  const HomeAppBar({
    super.key,
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
    this.userStats,
  });

  @override
  State<HomeAppBar> createState() => _HomeAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _HomeAppBarState extends State<HomeAppBar> {
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = packageInfo.version;
      });
    }
  }

  // フィルタリングアクションのマップ
  static const Map<String, VoidCallback Function(HomeAppBar)> _filterActions = {
    'advanced_search': (w) => w.onShowAdvancedSearch,
    'reminder_filter': (w) => w.onShowReminderFilter,
    'favorite_filter': (w) => w.onToggleFavorites,
    'category_filter': (w) => w.onShowCategoryFilter,
    'sort': (w) => w.onShowSortDialog,
    'date_filter': (w) => w.onShowDateFilter,
  };

  // ページ遷移アクションのマップ
  static const Map<String, Widget Function(BuildContext)> _pageBuilders = {
    'categories': (c) => const CategoriesPage(),
    'archive': (c) => const ArchivePage(),
    'stats': (c) => const StatsPage(),
    'leaderboard': (c) => const LeaderboardPage(),
    'profile_settings': (c) => const ProfileSettingsPage(),
    'site_stats': (c) => const EnhancedStatisticsPage(),
    'referral': (c) => const ReferralPage(),
    'daily_challenges': (c) => const DailyChallengesPage(),
    'personality_test': (c) => const PersonalityTestLandingPage(),
    'ai_secretary': (c) => const AISecretaryPage(),
    'memo_gallery': (c) => const MemoGalleryPage(),
    'growth_dashboard': (c) => const GrowthDashboardPage(),
    'templates': (c) => const TemplateMarketplacePage(),
    'import': (c) => const ImportPage(),
    'activity_feed': (c) => const ActivityFeedPage(),
    'settings': (c) => const SettingsPage(),
    'feedback': (c) => const FeedbackPage(), // ✅ 追加
  };

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: widget.isSearching
          ? TextField(
              controller: widget.searchController,
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
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('マイメモ'),
                if (_appVersion != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2), // 修正: withOpacity
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'v$_appVersion',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
      actions: [
        if (widget.isSearching)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              widget.searchController.clear();
            },
            tooltip: 'クリア',
          ),
        IconButton(
          icon: Icon(widget.isSearching ? Icons.close : Icons.search),
          onPressed: widget.onToggleSearch,
          tooltip: widget.isSearching ? '検索を閉じる' : '検索',
        ),
        if (!widget.isMobile) ...[
          IconButton(
            icon: Icon(
              Icons.tune,
              color: widget.hasActiveAdvancedFilters ? Colors.purple : null,
            ),
            tooltip: '詳細検索',
            onPressed: widget.onShowAdvancedSearch,
          ),
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  widget.reminderFilter != null ? Icons.alarm_on : Icons.alarm,
                  color: widget.reminderFilter != null ? Colors.orange : null,
                ),
                onPressed: widget.onShowReminderFilter,
                tooltip: 'リマインダーで絞り込み',
              ),
              if (widget.reminderFilter != null)
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
                  widget.showFavoritesOnly ? Icons.star : Icons.star_border,
                  color: widget.showFavoritesOnly ? Colors.amber : null,
                ),
                onPressed: widget.onToggleFavorites,
                tooltip: widget.showFavoritesOnly ? 'すべて表示' : 'お気に入りのみ表示',
              ),
              if (widget.showFavoritesOnly)
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
                onPressed: widget.onShowCategoryFilter,
                tooltip: 'カテゴリで絞り込み',
              ),
              if (widget.hasCategoryFilter)
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
            onPressed: widget.onShowSortDialog,
            tooltip: '並び替え',
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: widget.onShowDateFilter,
                tooltip: '日付で絞り込み',
              ),
              if (widget.hasDateFilter)
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
          onPressed: widget.onRefresh,
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
        if (value == 'share_app') {
          _showShareDialog(context);
        } else if (value == 'logout') {
          widget.onSignOut();
        } else if (_filterActions.containsKey(value)) {
          // フィルタリング処理の実行
          _filterActions[value]!(widget)();
        } else if (_pageBuilders.containsKey(value)) {
          // ページ遷移処理の実行
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => _pageBuilders[value]!(context)),
          ).then((result) {
            // 遷移後の処理 (リフレッシュ/統計ロード)
            if (value == 'profile_settings' && result == true) {
              widget.onLoadUserStats();
              widget.onRefresh();
            } else if (['categories', 'archive', 'import'].contains(value)) {
              widget.onRefresh();
            } else if ([
              'stats',
              'leaderboard',
              'referral',
              'daily_challenges',
              'personality_test',
              'ai_secretary'
            ].contains(value)) {
              widget.onLoadUserStats();
            }
            // その他のページは特になし
          });
        }
      },
      itemBuilder: (context) => [
        if (widget.isMobile) ...[
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
                  widget.showFavoritesOnly ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
                const SizedBox(width: 8),
                Text(widget.showFavoritesOnly ? 'すべて表示' : 'お気に入り'),
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
          value: 'profile_settings',
          child: Row(
            children: [
              Icon(Icons.person, color: Colors.blue),
              SizedBox(width: 8),
              Text('プロフィール設定'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'site_stats',
          child: Row(
            children: [
              Icon(Icons.analytics, color: Colors.green),
              SizedBox(width: 8),
              Text('サイト統計'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'memo_gallery',
          child: Row(
            children: [
              Icon(Icons.collections, color: Colors.purple),
              SizedBox(width: 8),
              Text('メモギャラリー'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'daily_challenges',
          child: Row(
            children: [
              Icon(Icons.task_alt, color: Colors.orange),
              SizedBox(width: 8),
              Text('デイリーチャレンジ'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'personality_test',
          child: Row(
            children: [
              Icon(Icons.psychology, color: Colors.deepPurple),
              SizedBox(width: 8),
              Text('🧠 性格診断'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'ai_secretary',
          child: Row(
            children: [
              Icon(Icons.assistant, color: Colors.blue),
              SizedBox(width: 8),
              Text('🤖 AI秘書'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'referral',
          child: Row(
            children: [
              Icon(Icons.card_giftcard, color: Colors.pink),
              SizedBox(width: 8),
              Text('紹介プログラム'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'growth_dashboard',
          child: Row(
            children: [
              Icon(Icons.trending_up, color: Colors.green),
              SizedBox(width: 8),
              Text('🚀 成長ダッシュボード'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'templates',
          child: Row(
            children: [
              Icon(Icons.library_books, color: Colors.blue),
              SizedBox(width: 8),
              Text('テンプレート'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'import',
          child: Row(
            children: [
              Icon(Icons.upload_file, color: Colors.orange),
              SizedBox(width: 8),
              Text('インポート'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'activity_feed',
          child: Row(
            children: [
              Icon(Icons.timeline, color: Colors.purple),
              SizedBox(width: 8),
              Text('コミュニティ'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        // ✅ 追加: フィードバックメニュー
        const PopupMenuItem(
          value: 'feedback',
          child: Row(
            children: [
              Icon(Icons.feedback_outlined, color: Colors.teal),
              SizedBox(width: 8),
              Text('ご意見・ご要望'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'share_app',
          child: Row(
            children: [
              Icon(Icons.share, color: Colors.blue),
              SizedBox(width: 8),
              Text('アプリをシェア'),
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

  void _showShareDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.all(0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ヘッダー部分
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade400,
                        Colors.purple.shade400,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white
                                  .withOpacity(0.2), // 修正: withOpacity
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.share,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'マイメモをシェア',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'みんなに広めよう！',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              Colors.white.withOpacity(0.15), // 修正: withOpacity
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '🎮 友達と一緒にメモ習慣を楽しもう！',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (widget.userStats != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white
                                    .withOpacity(0.25), // 修正: withOpacity
                                Colors.white.withOpacity(0.15),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white
                                  .withOpacity(0.4), // 修正: withOpacity
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withOpacity(0.1), // 修正: withOpacity
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white
                                      .withOpacity(0.3), // 修正: withOpacity
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      '👑 ',
                                      style: TextStyle(fontSize: 20),
                                    ),
                                    Text(
                                      widget.userStats!.levelTitle,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatItem(
                                    '📊',
                                    'Lv.${widget.userStats!.currentLevel}',
                                  ),
                                  Container(
                                    height: 40,
                                    width: 1,
                                    color: Colors.white
                                        .withOpacity(0.3), // 修正: withOpacity
                                  ),
                                  _buildStatItem(
                                    '⭐',
                                    '${widget.userStats!.totalPoints}pt',
                                  ),
                                  Container(
                                    height: 40,
                                    width: 1,
                                    color: Colors.white
                                        .withOpacity(0.3), // 修正: withOpacity
                                  ),
                                  _buildStatItem(
                                    '🔥',
                                    '${widget.userStats!.currentStreak}日',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // コンテンツ部分
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.purple.shade400,
                                  Colors.pink.shade400,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.format_quote,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '哲学者の名言をシェア',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.purple.shade400,
                                  Colors.pink.shade400,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'おすすめ',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // SNS別シェアボタン（哲学者の名言版）
                      _buildSnsShareButtons(context),
                      const SizedBox(height: 12),
                      // 画像カードを作成
                      _buildShareButton(
                        context,
                        icon: Icons.image,
                        label: '名言カードを作成してシェア',
                        color: Colors.purple.shade700,
                        subtitle: '美しいOGPカード画像を生成',
                        badge: 'NEW',
                        onTap: () {
                          Navigator.pop(context);
                          showDialog(
                            context: context,
                            builder: (_) => SharePhilosopherQuoteDialog(
                              userLevel: widget.userStats?.currentLevel,
                              totalPoints: widget.userStats?.totalPoints,
                              currentStreak: widget.userStats?.currentStreak,
                              levelTitle: widget.userStats?.levelTitle,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Divider(color: Colors.grey.shade300, thickness: 1),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.more_horiz,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'その他の方法',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const SizedBox(height: 8),
                      if (widget.userStats != null) ...[
                        _buildShareButton(
                          context,
                          icon: Icons.emoji_events,
                          label: '実績付きでシェア',
                          color: Colors.amber.shade700,
                          subtitle: 'あなたの実績を含めてシェア',
                          onTap: () async {
                            Navigator.pop(context);
                            try {
                              await AppShareService.shareWithUserStats(
                                level: widget.userStats!.currentLevel,
                                totalPoints: widget.userStats!.totalPoints,
                                currentStreak: widget.userStats!.currentStreak,
                                levelTitle: widget.userStats!.levelTitle,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('実績付きでシェアしました！'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('クリップボードにコピーしました'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                      _buildShareButton(
                        context,
                        icon: Icons.share,
                        label: '通常シェア',
                        color: Colors.blue.shade700,
                        subtitle: 'アプリの情報をシェア',
                        onTap: () async {
                          Navigator.pop(context);
                          try {
                            await AppShareService.shareApp();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('シェアしました！'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('クリップボードにコピーしました'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildShareButton(
                        context,
                        icon: Icons.link,
                        label: 'URLをコピー',
                        color: Colors.grey.shade700,
                        subtitle: 'リンクをクリップボードにコピー',
                        onTap: () async {
                          Navigator.pop(context);
                          await AppShareService.copyAppUrlToClipboard();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('URLをクリップボードにコピーしました'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String emoji, String text) {
    return Column(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 24),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSnsShareButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildSnsButton(
            context,
            label: 'X',
            icon: Icons.close, // Xのアイコン
            color: Colors.black,
            onTap: () async {
              Navigator.pop(context);
              try {
                // 動的OGP対応: 哲学者の名言シェア
                await AppShareService.shareToTwitterWithDynamicOgp(
                  level: widget.userStats?.currentLevel,
                  totalPoints: widget.userStats?.totalPoints,
                  currentStreak: widget.userStats?.currentStreak,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('動的OGP対応の名言をXでシェアしました！🎨'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('クリップボードにコピーしました'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSnsButton(
            context,
            label: 'Facebook',
            icon: Icons.facebook,
            color: const Color(0xFF1877F2),
            onTap: () async {
              Navigator.pop(context);
              try {
                // 動的OGP対応: Facebookシェア
                await AppShareService.shareToFacebookWithDynamicOgp();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('動的OGP対応の名言をFacebookでシェアしました！🎨'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('クリップボードにコピーしました'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSnsButton(
            context,
            label: 'LINE',
            icon: Icons.chat,
            color: const Color(0xFF00B900),
            onTap: () async {
              Navigator.pop(context);
              try {
                // 動的OGP対応: LINEシェア
                await AppShareService.shareToLineWithDynamicOgp(
                  level: widget.userStats?.currentLevel,
                  totalPoints: widget.userStats?.totalPoints,
                  currentStreak: widget.userStats?.currentStreak,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('動的OGP対応の名言をLINEでシェアしました！🎨'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('クリップボードにコピーしました'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSnsButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3), // 修正: withOpacity
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    String? subtitle,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05), // 修正: withOpacity
          border: Border.all(
              color: color.withOpacity(0.3), width: 1.5), // 修正: withOpacity
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1), // 修正: withOpacity
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.pink.shade400,
                                Colors.orange.shade400,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: color.withOpacity(0.7), // 修正: withOpacity
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: color.withOpacity(0.5), // 修正: withOpacity
            ),
          ],
        ),
      ),
    );
  }
}
