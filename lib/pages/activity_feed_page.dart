import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';
import 'package:timeago/timeago.dart' as timeago;

// ActivityFeedPageで表示するデータ構造を抽象化 (変更なし)
class ActivityItem {
  final String id;
  final String type;
  final String userName;
  final String action;
  final DateTime timestamp;

  ActivityItem({
    required this.id,
    required this.type,
    required this.userName,
    required this.action,
    required this.timestamp,
  });

  // DBのJSONから変換するファクトリコンストラクタ (変更なし)
  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    const String defaultName = '匿名ユーザー';
    final String name = json['user_name'] ?? defaultName;

    // 以前の EnhancedStatisticsPage の画像で見たように、
    // activity の action が `匿名ユーザー kanta13jp が統計・実績ページを訪問しました` のような
    // ユーザー名を含む整形済みの文字列であると仮定します。
    // その場合、ActivityItemの action フィールドは、その整形済みの全文を保持しています。
    // UI側の _buildActivityItem で RichText を使用して、
    // userName と action を結合して表示しているロジックが、
    // データベース側のデータ構造と矛盾しないか注意が必要です。

    // NOTE: action にはユーザー名を含む整形済みテキストが入っているという前提を維持します。
    final fullActionText = json['action'] as String? ?? '新しいアクティビティ';

    return ActivityItem(
      id: json['id'].toString(),
      type: json['type'] as String? ?? 'general',
      userName: name.isNotEmpty ? name : defaultName,
      action: fullActionText,
      // Supabaseから返されるISO 8601形式の文字列をDateTimeにパース
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

class ActivityFeedPage extends StatefulWidget {
  const ActivityFeedPage({super.key});

  @override
  State<ActivityFeedPage> createState() => _ActivityFeedPageState();
}

class _ActivityFeedPageState extends State<ActivityFeedPage> {
  final _supabase = Supabase.instance.client;
  StreamSubscription<List<Map<String, dynamic>>>? _activitySubscription;

  List<ActivityItem> _activities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 日本語メッセージを設定
    timeago.setLocaleMessages('ja', timeago.JaMessages());
    _startRealTimeSubscription();
  }

  // ... (_startRealTimeSubscription, _handleRealTimeData, _loadActivities, _generateSampleActivities, dispose は変更なし)
  void _startRealTimeSubscription() {
    _activitySubscription = _supabase
        .from('activities')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .limit(30)
        .listen(
          _handleRealTimeData,
          onError: (e) {
            AppLogger.error('Realtime subscription error', error: e);
            _loadActivities();
          },
        );
  }

  void _handleRealTimeData(List<Map<String, dynamic>> data) {
    final List<ActivityItem> newActivities =
        data.map((json) => ActivityItem.fromJson(json)).toList();

    if (mounted) {
      setState(() {
        _activities = newActivities;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadActivities() async {
    try {
      setState(() => _isLoading = true);

      final response = await _supabase
          .from('activities')
          .select('id, type, user_name, action, timestamp')
          .order('timestamp', ascending: false)
          .limit(30);

      final List<ActivityItem> activities = (response as List)
          .map((json) => ActivityItem.fromJson(json as Map<String, dynamic>))
          .toList();

      if (activities.isEmpty) {
        activities.addAll(_generateSampleActivities());
      }

      if (mounted) {
        setState(() {
          _activities = activities;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error loading activities (Future)',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(() {
          _activities = _generateSampleActivities();
          _isLoading = false;
        });
      }
    }
  }

  List<ActivityItem> _generateSampleActivities() {
    final now = DateTime.now();
    return [
      ActivityItem(
        id: '1',
        type: 'new_user',
        userName:
            'ユーザー${_supabase.auth.currentUser?.id.substring(0, 4) ?? 'XXXX'}',
        action: '新しいメンバーが参加しました',
        timestamp: now.subtract(const Duration(minutes: 5)),
      ),
      ActivityItem(
        id: '2',
        type: 'achievement',
        userName: '匿名ユーザー',
        action: '実績「メモマスター」を解除しました',
        timestamp: now.subtract(const Duration(minutes: 15)),
      ),
      ActivityItem(
        id: '3',
        type: 'stats_page_visit', // 前のページで確認した visit の type を追加
        userName: 'kanta13jp', // ユーザー名を具体的なものに変更
        action: 'kanta13jpが統計・実績ページを訪問しました',
        timestamp: now.subtract(const Duration(minutes: 4)),
      ),
      ActivityItem(
        id: '4',
        type: 'milestone',
        userName: 'システム',
        action: '総メモ数が10,000件を突破しました！🎉',
        timestamp: now.subtract(const Duration(hours: 2)),
      ),
    ];
  }

  @override
  void dispose() {
    _activitySubscription?.cancel();
    super.dispose();
  }

  // Activityのアイコンや色を決定するロジック (UIとデータを分離)
  Map<String, dynamic> _getActivityStyle(String type) {
    switch (type) {
      case 'new_user':
        return {'icon': Icons.person_add, 'color': Colors.green};
      case 'achievement':
        return {'icon': Icons.emoji_events, 'color': const Color(0xFFFFC107)};
      case 'milestone':
        return {'icon': Icons.celebration, 'color': const Color(0xFF3D5AFE)};
      case 'share':
        return {'icon': Icons.share, 'color': const Color(0xFF3D5AFE)};
      case 'level_up':
        return {'icon': Icons.trending_up, 'color': const Color(0xFF009688)};
      case 'stats_page_visit': // 統計ページ訪問のスタイルを追加
        return {'icon': Icons.bar_chart, 'color': const Color(0xFFFF6B35)};
      default:
        return {'icon': Icons.timeline, 'color': const Color(0xFF9CA3AF)};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'コミュニティ活動',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadActivities,
            tooltip: '更新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadActivities,
              child: _activities.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.timeline,
                            size: 64,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'まだアクティビティがありません',
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.7,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      // リスト全体のパディングを調整
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      itemCount: _activities.length,
                      // 区切り線をより薄く、短く
                      separatorBuilder: (context, index) => const Divider(
                        height: 24,
                        thickness: 0.5,
                        indent: 60,
                        endIndent: 16,
                      ),
                      itemBuilder: (context, index) {
                        final activity = _activities[index];
                        return _buildActivityItem(activity);
                      },
                    ),
            ),
    );
  }

  // ActivityItemモデルを受け取るように変更
  Widget _buildActivityItem(ActivityItem activity) {
    final style = _getActivityStyle(activity.type);
    final timeAgo = timeago.format(activity.timestamp, locale: 'ja');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. アイコン
        Container(
          width: 40, // アイコンコンテナの幅を固定
          height: 40, // アイコンコンテナの高さを固定
          decoration: BoxDecoration(
            color: (style['color'] as Color).withValues(alpha: 0.15), // 透明度を調整
            borderRadius: BorderRadius.circular(8), // 角を丸く
          ),
          child: Icon(
            style['icon'] as IconData,
            color: style['color'] as Color,
            size: 22, // アイコンサイズを微調整
          ),
        ),
        const SizedBox(width: 16), // 間隔を広げる

        // 2. 内容 (Expandedでオーバーフロー対策)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                // ✅ オーバーフロー対策: maxLines と overflow を追加
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style.copyWith(
                        fontSize: 15.0, // テキストサイズを標準に
                        height: 1.7,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                  children: [
                    TextSpan(
                      text: activity.action, // action には整形済み全文が入っていると仮定
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // タイムスタンプ
              Text(
                timeAgo,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
