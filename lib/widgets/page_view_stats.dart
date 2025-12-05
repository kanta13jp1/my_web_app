import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart'; // kIsWeb用

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

  // ブラウザ名を取得する
  Future<String> _getBrowserName() async {
    if (!kIsWeb) return 'App'; // Web以外からのアクセス

    try {
      final deviceInfo = DeviceInfoPlugin();
      final webBrowserInfo = await deviceInfo.webBrowserInfo;

      // browserNameはenumなので文字列に変換して整形
      // 例: BrowserName.chrome -> Chrome
      final name = webBrowserInfo.browserName.name;
      return name[0].toUpperCase() + name.substring(1);
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<Map<String, dynamic>> _trackAndFetchStats() async {
    try {
      // ブラウザ情報を取得
      final browser = await _getBrowserName();

      // RPCを呼び出し (browser情報を追加)
      final response = await Supabase.instance.client.rpc(
        'track_and_get_page_stats',
        params: {
          'target_path': widget.pagePath,
          'user_browser': browser,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error tracking views: $e');
      return {'total': 0, 'today': 0, 'browsers': {}};
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

        return GestureDetector(
          onTap: () => _showBrowserStats(context, browsers),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                _buildStatItem(Icons.visibility, '総閲覧', '$total'),
                Container(
                  height: 16,
                  width: 1,
                  color: Colors.grey.withValues(alpha: 0.3),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                _buildStatItem(Icons.today, '本日', '$today'),
                const SizedBox(width: 8),
                Icon(Icons.info_outline, size: 14, color: Colors.grey[400]),
              ],
            ),
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

  // ブラウザ内訳をダイアログで表示
  void _showBrowserStats(BuildContext context, Map<String, dynamic> browsers) {
    // 値の大きい順にソート
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
        return const Icon(Icons.language, color: Colors.blue); // Chrome Icon代用
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
