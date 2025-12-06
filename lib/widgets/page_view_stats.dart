import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_share_service.dart';

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

  // 🔥 本日の目標数値を設定
  static const int dailyGoal = 40;

  @override
  void initState() {
    super.initState();
    _statsFuture = _trackAndFetchStats();
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

      // ✅ キリ番チェック (ここでも確実にintに変換)
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
            const SizedBox(height: 8),
            const Text(
              'この奇跡をシェアしてみんなに自慢しませんか？',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
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
            style: FilledButton.styleFrom(
              backgroundColor: Colors.black, // Xカラー
            ),
            onPressed: () {
              Navigator.pop(context);
              _shareToX(count, 0, isMilestone: true);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _shareToX(int total, int today,
      {bool isMilestone = false}) async {
    final String text;
    if (isMilestone) {
      text = '🎉 記念すべき $total 人目の訪問者になりました！\n'
          '個人開発アプリ「マイメモ」でキリ番ゲット 🚀\n'
          '#個人開発 #Flutter #キリ番';
    } else {
      text = '現在のLP閲覧数は $total 回（本日 $today 回）です！\n'
          '個人開発アプリ「マイメモ」公開中 🚀\n'
          '#個人開発 #Flutter #Supabase';
    }

    final url = AppShareService.appUrl;

    final tweetUrl = Uri.parse(
      'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(text)}&url=${Uri.encodeComponent(url)}',
    );

    if (await canLaunchUrl(tweetUrl)) {
      await launchUrl(tweetUrl, mode: LaunchMode.externalApplication);
    }
  }

  // ここは int 型を受け取るように定義されている
  Future<void> _shareGoalProgress(int today) async {
    final remaining = dailyGoal - today;
    final isAchieved = remaining <= 0;

    final String text;
    if (isAchieved) {
      text = '🎉【目標達成】今日の訪問者数が目標の$dailyGoal人を突破しました！\n'
          '現在 $today 人の方が訪問中。ありがとうございます！🚀\n'
          '#個人開発 #Flutter #目標達成';
    } else {
      text = '🔥【緊急ミッション】今日の目標閲覧数 $dailyGoal まで、あと $remaining 人です！\n'
          '現在 $today/$dailyGoal 人。\n'
          '👇 1クリックで応援してください！あなたのアクセスでグラフが進みます！\n'
          '#個人開発 #Flutter #駆け出しエンジニアと繋がりたい';
    }

    final url = AppShareService.appUrl;

    final tweetUrl = Uri.parse(
      'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(text)}&url=${Uri.encodeComponent(url)}',
    );

    if (await canLaunchUrl(tweetUrl)) {
      await launchUrl(tweetUrl, mode: LaunchMode.externalApplication);
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

        // 🛠️ 【最重要】ここで確実に int型 に変換します
        // これにより、後続の計算や関数呼び出しでのエラーが全て解消されます
        final int total = (data['total'] as num?)?.toInt() ?? 0;
        final int today = (data['today'] as num?)?.toInt() ?? 0;

        final browsers = data['browsers'] as Map<String, dynamic>? ?? {};

        // 進捗率の計算 (int同士の割り算なので安全)
        final double progress = (today / dailyGoal).clamp(0.0, 1.0);
        final int remaining = dailyGoal - today;

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
              // 1. カウンター表示
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
                                '/ $dailyGoal',
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

              // 3. メッセージ
              if (remaining > 0)
                Text(
                  '目標まであと $remaining 人！',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                )
              else
                const Text(
                  '🎉 本日の目標達成！',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),

              const SizedBox(height: 12),

              // 4. シェアボタン
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _shareGoalProgress(today), // todayはintなのでエラーなし
                  icon: const Icon(Icons.rocket_launch, size: 18),
                  label: const Text('進捗をシェアして応援を呼ぶ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black, // Xカラー
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
