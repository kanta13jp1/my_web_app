import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 成長実績サマリーページ
/// 新規ユーザー数、獲得シグナル、紹介完了数などのサマリーを表示
class GrowthAchievementSummaryPage extends StatefulWidget {
  const GrowthAchievementSummaryPage({super.key});

  @override
  State<GrowthAchievementSummaryPage> createState() =>
      _GrowthAchievementSummaryPageState();
}

class _GrowthAchievementSummaryPageState
    extends State<GrowthAchievementSummaryPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _data;
  String _period = 'week';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _supabase.functions.invoke(
        'growth-achievement-summary',
        body: {'period': _period},
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        setState(() => _data = data);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'データ取得に失敗しました: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildStatCard(String label, dynamic value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value?.toString() ?? '-',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: AppBar(
        title: const Text('成長実績サマリー'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'day', label: Text('今日')),
                          ButtonSegment(value: 'week', label: Text('今週')),
                          ButtonSegment(value: 'month', label: Text('今月')),
                        ],
                        selected: {_period},
                        onSelectionChanged: (s) {
                          setState(() => _period = s.first);
                          _load();
                        },
                      ),
                      const SizedBox(height: 16),
                      if (d != null) ...[
                        Text(
                          d['label']?.toString() ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 1.5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          children: [
                            _buildStatCard(
                              '新規ユーザー',
                              d['newUsers'],
                              Icons.person_add,
                              Colors.green,
                            ),
                            _buildStatCard(
                              '獲得シグナル',
                              d['acquisitionSignals'],
                              Icons.trending_up,
                              Colors.blue,
                            ),
                            _buildStatCard(
                              '紹介完了',
                              d['referralsCompleted'],
                              Icons.people_alt,
                              Colors.purple,
                            ),
                            _buildStatCard(
                              'インポートプレビュー',
                              d['importPreviews'],
                              Icons.upload_file,
                              Colors.orange,
                            ),
                            _buildStatCard(
                              '総ユーザー数',
                              d['totalUsersEver'],
                              Icons.group,
                              Colors.teal,
                            ),
                          ],
                        ),
                      ] else
                        const Text(
                          'データがありません',
                          style: TextStyle(color: Colors.grey),
                        ),
                    ],
                  ),
                ),
    );
  }
}
