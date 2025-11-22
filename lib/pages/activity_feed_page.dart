import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';
import 'package:timeago/timeago.dart' as timeago;

class ActivityFeedPage extends StatefulWidget {
  const ActivityFeedPage({super.key});

  @override
  State<ActivityFeedPage> createState() => _ActivityFeedPageState();
}

class _ActivityFeedPageState extends State<ActivityFeedPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;
  StreamSubscription? _periodicSubscription;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('ja', timeago.JaMessages());
    _loadActivities();
    _startRealTimeUpdates();
  }

  Future<void> _loadActivities() async {
    try {
      setState(() => _isLoading = true);

      // サンプルアクティビティを生成（実際はDBから取得）
      final activities = await _generateSampleActivities();

      if (mounted) {
        setState(() {
          _activities = activities;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error loading activities',
          error: e, stackTrace: stackTrace,);
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _generateSampleActivities() async {
    // 実際のアクティビティを取得する処理
    // 現在はサンプルデータを返す

    final now = DateTime.now();

    return [
      {
        'id': '1',
        'type': 'new_user',
        'user_name':
            'ユーザー${_supabase.auth.currentUser?.id.substring(0, 4) ?? 'XXXX'}',
        'action': '新しいメンバーが参加しました',
        'timestamp': now.subtract(const Duration(minutes: 5)),
        'icon': Icons.person_add,
        'color': Colors.green,
      },
      {
        'id': '2',
        'type': 'achievement',
        'user_name': '匿名ユーザー',
        'action': '実績「メモマスター」を解除しました',
        'timestamp': now.subtract(const Duration(minutes: 15)),
        'icon': Icons.emoji_events,
        'color': Colors.amber,
      },
      {
        'id': '3',
        'type': 'milestone',
        'user_name': 'システム',
        'action': '総メモ数が10,000件を突破しました！🎉',
        'timestamp': now.subtract(const Duration(hours: 2)),
        'icon': Icons.celebration,
        'color': Colors.purple,
      },
      {
        'id': '4',
        'type': 'share',
        'user_name': '匿名ユーザー',
        'action': 'メモを公開ギャラリーに投稿しました',
        'timestamp': now.subtract(const Duration(hours: 3)),
        'icon': Icons.share,
        'color': Colors.blue,
      },
      {
        'id': '5',
        'type': 'level_up',
        'user_name': '匿名ユーザー',
        'action': 'レベル20に到達しました',
        'timestamp': now.subtract(const Duration(hours: 5)),
        'icon': Icons.trending_up,
        'color': Colors.teal,
      },
    ];
  }

  void _startRealTimeUpdates() {
    // 30秒ごとにアクティビティを更新
    _periodicSubscription = Stream.periodic(const Duration(seconds: 30), (_) {
      _loadActivities();
    }).listen((_) {});
  }

  @override
  void dispose() {
    _periodicSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('コミュニティ活動'),
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
                          Icon(Icons.timeline,
                              size: 64, color: Colors.grey[400],),
                          const SizedBox(height: 16),
                          Text(
                            'まだアクティビティがありません',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _activities.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 24),
                      itemBuilder: (context, index) {
                        final activity = _activities[index];
                        return _buildActivityItem(activity);
                      },
                    ),
            ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final timestamp = activity['timestamp'] as DateTime;
    final timeAgo = timeago.format(timestamp, locale: 'ja');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // アイコン
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (activity['color'] as Color).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            activity['icon'] as IconData,
            color: activity['color'] as Color,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),

        // 内容
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    TextSpan(
                      text: activity['user_name'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(text: ' '),
                    TextSpan(
                      text: activity['action'] as String,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timeAgo,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
