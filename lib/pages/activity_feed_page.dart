import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';
import 'package:timeago/timeago.dart' as timeago;

// ActivityFeedPageで表示するデータ構造を抽象化
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

  // DBのJSONから変換するファクトリコンストラクタ
  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    final String defaultName = '匿名ユーザー';
    final String name = json['user_name'] ?? defaultName;

    return ActivityItem(
      id: json['id'].toString(),
      type: json['type'] as String? ?? 'general',
      userName: name.isNotEmpty ? name : defaultName,
      action: json['action'] as String? ?? '新しいアクティビティ',
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
  // ✅ リアルタイム購読をキャンセルするための変数
  StreamSubscription<List<Map<String, dynamic>>>? _activitySubscription;

  List<ActivityItem> _activities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('ja', timeago.JaMessages());
    // 初回ロードはストリーム開始時に自動的に行われるため、コメントアウト
    // _loadActivities();
    _startRealTimeSubscription();
  }

  // ✅ 改善点1: Supabase Realtime Stream の実装
  void _startRealTimeSubscription() {
    // activities テーブルの最新30件の変更を購読
    // ストリームは接続時に最新のデータを取得し、以降の変更を継続的にプッシュします。
    _activitySubscription = _supabase
        .from('activities')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .limit(30)
        .listen(_handleRealTimeData, onError: (e) {
          AppLogger.error('Realtime subscription error', error: e);
          // エラーが発生した場合、Futureベースのロードをトリガー
          _loadActivities();
        });
  }

  // ✅ 改善点2: リアルタイムデータ処理ハンドラ
  void _handleRealTimeData(List<Map<String, dynamic>> data) {
    final List<ActivityItem> newActivities =
        data.map((json) => ActivityItem.fromJson(json)).toList();

    if (mounted) {
      setState(() {
        _activities = newActivities;
        _isLoading = false; // データが来たのでロード完了
      });
    }
  }

  // Futureベースのデータ取得 (ストリームが失敗した場合、または手動Refresh時)
  Future<void> _loadActivities() async {
    try {
      setState(() => _isLoading = true);

      // Postgrest (REST) APIを介してデータを取得
      final response = await _supabase
          .from('activities')
          .select('id, type, user_name, action, timestamp')
          .order('timestamp', ascending: false)
          .limit(30);

      final List<ActivityItem> activities = (response as List)
          .map((json) => ActivityItem.fromJson(json as Map<String, dynamic>))
          .toList();

      if (activities.isEmpty) {
        // データがない場合、ハードコードされたサンプルデータを表示
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
          // エラー時はサンプルデータを表示
          _activities = _generateSampleActivities();
          _isLoading = false;
        });
      }
    }
  }

  // サンプルデータ生成 (フォールバック)
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
        type: 'milestone',
        userName: 'システム',
        action: '総メモ数が10,000件を突破しました！🎉',
        timestamp: now.subtract(const Duration(hours: 2)),
      ),
    ];
  }

  @override
  void dispose() {
    // ✅ 改善点3: 購読の解除を確実に行う
    _activitySubscription?.cancel();
    super.dispose();
  }

  // Activityのアイコンや色を決定するロジック (UIとデータを分離)
  Map<String, dynamic> _getActivityStyle(String type) {
    switch (type) {
      case 'new_user':
        return {'icon': Icons.person_add, 'color': Colors.green};
      case 'achievement':
        return {'icon': Icons.emoji_events, 'color': Colors.amber};
      case 'milestone':
        return {'icon': Icons.celebration, 'color': Colors.purple};
      case 'share':
        return {'icon': Icons.share, 'color': Colors.blue};
      case 'level_up':
        return {'icon': Icons.trending_up, 'color': Colors.teal};
      default:
        return {'icon': Icons.timeline, 'color': Colors.grey};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('コミュニティ活動'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadActivities, // Refresh時はFutureベースの_loadActivitiesを呼ぶ
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
                            color: Colors.grey[400],
                          ),
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

  // ActivityItemモデルを受け取るように変更
  Widget _buildActivityItem(ActivityItem activity) {
    final style = _getActivityStyle(activity.type);
    final timeAgo = timeago.format(activity.timestamp, locale: 'ja');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // アイコン
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (style['color'] as Color).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            style['icon'] as IconData,
            color: style['color'] as Color,
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
                      text: activity.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(text: ' '),
                    TextSpan(
                      text: activity.action,
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
