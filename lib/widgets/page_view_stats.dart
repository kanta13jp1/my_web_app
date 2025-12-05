import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PageViewStats extends StatefulWidget {
  final String pagePath;

  const PageViewStats({
    super.key,
    this.pagePath = '/landing', // デフォルトのパス
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

  // カウントアップしてデータを取得
  Future<Map<String, dynamic>> _trackAndFetchStats() async {
    try {
      // SupabaseのRPC（関数）を呼び出す
      final response = await Supabase.instance.client.rpc(
        'track_and_get_page_stats',
        params: {'target_path': widget.pagePath},
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error tracking views: $e');
      return {'total': 0, 'today': 0};
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // 読み込み中は何も表示しない（またはローディング）
          return const SizedBox.shrink();
        }

        final data = snapshot.data!;
        final total = data['total'] ?? 0;
        final today = data['today'] ?? 0;

        return Container(
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
}
