import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
// ✅ 追加: AppShareService をインポート
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

      // キリ番チェック（ビルド完了後にダイアログを表示）
      final total = data['total'] as int? ?? 0;
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

  // キリ番判定ロジック（20, 30, 40... 100, 200... などの節目）
  bool _isMilestone(int count) {
    if (count <= 0) return false;
    if (count == 20) return true; // 次の目標
    if (count % 50 == 0) return true; // 50, 100, 150...
    // テスト用に小さい数字でも反応するように調整（本番では消してもOK）
    if (count % 10 == 0 && count < 100) return true;
    return false;
  }

  // キリ番祝いのダイアログ
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

// ✅ 修正: 直書きをやめて、AppShareServiceのURLを参照するように変更
    // これでパラメータ付きのURL(?v=test2025)が自動的に使われます
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
        final total = data['total'] ?? 0;
        final today = data['today'] ?? 0;
        final browsers = data['browsers'] as Map<String, dynamic>? ?? {};

        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => _showBrowserStats(context, browsers),
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(30)),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatItem(Icons.visibility, '総閲覧', '$total'),
                      Container(
                        height: 16,
                        width: 1,
                        color: Colors.grey.withValues(alpha: 0.3),
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      _buildStatItem(Icons.today, '本日', '$today'),
                    ],
                  ),
                ),
              ),
              Container(
                height: 24,
                width: 1,
                color: Colors.grey.withValues(alpha: 0.2),
              ),
              IconButton(
                icon: const Icon(Icons.share, size: 18, color: Colors.blue),
                tooltip: '閲覧数をシェア',
                onPressed: () => _shareToX(total, today),
              ),
              const SizedBox(width: 4),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                height: 1.1,
              ),
            ),
          ],
        ),
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
