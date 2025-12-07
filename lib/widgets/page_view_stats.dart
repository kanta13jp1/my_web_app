import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:ui';
import '../services/app_share_service.dart';
import '../services/viral_growth_service.dart';

class PageViewStats extends StatefulWidget {
  final String pagePath;

  const PageViewStats({
    super.key,
    this.pagePath = '/landing',
  });

  @override
  State<PageViewStats> createState() => _PageViewStatsState();
}

class _PageViewStatsState extends State<PageViewStats> {
  Future<Map<String, dynamic>>? _statsFuture;
  late final ViralGrowthService _viralGrowthService;

  Timer? _timer;
  Duration _timeUntilReset = Duration.zero;

  @override
  void initState() {
    super.initState();
    _viralGrowthService = ViralGrowthService(Supabase.instance.client);
    _statsFuture = _trackAndFetchStats();

    _updateTimeUntilReset();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeUntilReset();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // 🕒 修正: 日本時間 (JST) の深夜0時までのカウントダウンを厳密に計算
  void _updateTimeUntilReset() {
    final nowUtc = DateTime.now().toUtc();
    // UTC時間をJST (+9時間) に変換して計算
    final nowJst = nowUtc.add(const Duration(hours: 9));

    // 今日の深夜0時（＝明日の始まり）を作成
    // 例: 今が 12/7 18:25 なら、ターゲットは 12/8 00:00:00
    final nextMidnightJst = DateTime(nowJst.year, nowJst.month, nowJst.day + 1);

    final difference = nextMidnightJst.difference(nowJst);

    if (mounted) {
      setState(() {
        _timeUntilReset = difference;
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours時間$minutes分$seconds秒';
  }

  Future<String> _getBrowserName() async {
    if (!kIsWeb) return 'App';
    try {
      final deviceInfo = DeviceInfoPlugin();
      final webBrowserInfo = await deviceInfo.webBrowserInfo;
      final name = webBrowserInfo.browserName.name;
      return name[0].toUpperCase() + name.substring(1);
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<Map<String, dynamic>> _trackAndFetchStats() async {
    try {
      final browser = await _getBrowserName();
      final response = await Supabase.instance.client.rpc(
        'track_and_get_page_stats',
        params: {
          'target_path': widget.pagePath,
          'user_browser': browser,
        },
      );

      final data = response as Map<String, dynamic>;
      final int total = (data['total'] as num?)?.toInt() ?? 0;

      if (mounted && _isMilestone(total)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showMilestoneDialog(total);
        });
      }

      return data;
    } catch (e) {
      debugPrint('Error tracking views: $e');
      return {'total': 0, 'today': 0, 'browsers': {}};
    }
  }

  bool _isMilestone(int count) {
    if (count <= 0) return false;
    if (count == 20) return true;
    if (count % 50 == 0) return true;
    if (count % 10 == 0 && count < 100) return true;
    return false;
  }

  int _calculateDynamicGoal(int total) {
    if (total < 60) return 40;
    if (total < 200) return 80;
    if (total < 500) return 120;
    return 160;
  }

  void _showMilestoneDialog(int count) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 おめでとうございます！'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              'あなたが記念すべき\n$count人目の訪問者です！',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('キリ番をシェア'),
            style: FilledButton.styleFrom(backgroundColor: Colors.black),
            onPressed: () {
              Navigator.pop(context);
              _shareToX(count, 0, isMilestone: true);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _recordShareAchievement() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final isActive = await _viralGrowthService.isShareCampaignActive();
      await _viralGrowthService.awardShareBonus(
        userId: user.id,
        platform: 'goal_progress',
        isCampaignActive: isActive,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isActive
                ? 'シェアありがとうございます！キャンペーンボーナス50pt獲得🎉'
                : 'シェアありがとうございます！実績加算＆10pt獲得✨'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error recording share: $e');
    }
  }

  Future<void> _shareToX(int total, int today,
      {bool isMilestone = false}) async {
    const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '');
    final versionText = appVersion.isNotEmpty ? ' (v$appVersion)' : '';
    final timeStr = _formatDuration(_timeUntilReset);

    final String text;
    if (isMilestone) {
      text = '🎉 記念すべき $total 人目の訪問者になりました！\n'
          '個人開発アプリ「マイメモ」でキリ番ゲット 🚀$versionText\n'
          '#個人開発 #Flutter #キリ番';
    } else {
      text = '現在のLP閲覧数は $total 回（本日 $today 回）です！\n'
          'リセットまで残り $timeStr ⏳\n'
          '個人開発アプリ「マイメモ」公開中 🚀$versionText\n'
          '#個人開発 #Flutter #Supabase';
    }

    final url = AppShareService.appUrl;
    final tweetUrl = Uri.parse(
      'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(text)}&url=${Uri.encodeComponent(url)}',
    );

    if (await canLaunchUrl(tweetUrl)) {
      await launchUrl(tweetUrl, mode: LaunchMode.externalApplication);
      await _recordShareAchievement();
    }
  }

  Future<void> _shareGoalProgress(int today, int goal) async {
    const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '');
    final versionText = appVersion.isNotEmpty ? ' (v$appVersion)' : '';
    final remaining = goal - today;
    final isAchieved = remaining <= 0;
    final timeStr = _formatDuration(_timeUntilReset);

    final String text;
    if (isAchieved) {
      text = '🎉【目標達成】今日の訪問者数が目標の$goal人を突破しました！\n'
          '残り時間 $timeStr で達成！🚀$versionText\n'
          '現在 $today 人の方が訪問中。ありがとうございます！\n'
          '#個人開発 #Flutter #目標達成';
    } else {
      text = '🔥【緊急ミッション】残り $timeStr ⏳\n'
          '今日の目標閲覧数 $goal まで、あと $remaining 人です！\n'
          '👇 1クリックで応援してください！あなたのアクセスでグラフが進みます！$versionText\n'
          '#個人開発 #Flutter #駆け出しエンジニアと繋がりたい';
    }

    final url = AppShareService.appUrl;
    final tweetUrl = Uri.parse(
      'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(text)}&url=${Uri.encodeComponent(url)}',
    );

    if (await canLaunchUrl(tweetUrl)) {
      await launchUrl(tweetUrl, mode: LaunchMode.externalApplication);
      await _recordShareAchievement();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!;
        final int total = (data['total'] as num?)?.toInt() ?? 0;
        final int today = (data['today'] as num?)?.toInt() ?? 0;
        final browsers = data['browsers'] as Map<String, dynamic>? ?? {};

        final int currentDailyGoal = _calculateDynamicGoal(total);
        final double progress = (today / currentDailyGoal).clamp(0.0, 1.0);
        final int remaining = currentDailyGoal - today;

        return Container(
          width: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. カウンター
              InkWell(
                onTap: () => _showBrowserStats(context, browsers),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '今日の訪問者',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$today',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '/ $currentDailyGoal',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ],
                      ),
                      _buildTotalCounter(total),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 2. プログレスバー
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    remaining <= 0 ? Colors.green : Colors.orangeAccent,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // 3. メッセージ & カウントダウン
              if (remaining > 0)
                Column(
                  children: [
                    Text(
                      '目標まであと $remaining 人！',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined,
                              size: 14, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            'リセットまで残り ${_formatDuration(_timeUntilReset)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    const Text(
                      '🎉 本日の目標達成！',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'リセットまで ${_formatDuration(_timeUntilReset)}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),

              const SizedBox(height: 12),

              // 4. シェアボタン
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _shareGoalProgress(today, currentDailyGoal),
                  icon: const Icon(Icons.rocket_launch, size: 18),
                  label: const Text('進捗をシェアして応援を呼ぶ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTotalCounter(int total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '総訪問者数',
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
        Text(
          '$total',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const Icon(Icons.pie_chart_outline, size: 14, color: Colors.grey),
      ],
    );
  }

  void _showBrowserStats(BuildContext context, Map<String, dynamic> browsers) {
    final sortedEntries = browsers.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.pie_chart, color: Colors.blue),
            SizedBox(width: 8),
            Text('ブラウザ別閲覧数', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: sortedEntries.length,
            itemBuilder: (context, index) {
              final entry = sortedEntries[index];
              return ListTile(
                leading: _getBrowserIcon(entry.key),
                title: Text(entry.key),
                trailing: Text(
                  '${entry.value}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              );
            },
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

  Icon _getBrowserIcon(String browserName) {
    switch (browserName.toLowerCase()) {
      case 'chrome':
        return const Icon(Icons.language, color: Colors.blue);
      case 'safari':
        return const Icon(Icons.explore, color: Colors.lightBlue);
      case 'firefox':
        return const Icon(Icons.local_fire_department, color: Colors.orange);
      case 'edge':
        return const Icon(Icons.edgesensor_high, color: Colors.teal);
      default:
        return const Icon(Icons.web, color: Colors.grey);
    }
  }
}
