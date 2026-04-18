import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 週次グロースダイジェストページ
/// チャネル別の週次グロース指標を表示
class GrowthWeeklyDigestPage extends StatefulWidget {
  const GrowthWeeklyDigestPage({super.key});

  @override
  State<GrowthWeeklyDigestPage> createState() => _GrowthWeeklyDigestPageState();
}

class _GrowthWeeklyDigestPageState extends State<GrowthWeeklyDigestPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _data;

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
      final response = await _supabase.functions.invoke('growth-weekly-digest');

      final data = response.data;
      if (data is Map<String, dynamic>) {
        setState(() => _data = data);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '週次ダイジェスト取得に失敗しました: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildChannelCard(Map<String, dynamic> channel) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              channel['label']?.toString() ?? channel['id']?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMetric(
                  'タッチ',
                  channel['touches'],
                  Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildMetric(
                  '登録送信',
                  channel['signupSubmits'],
                  Colors.green,
                ),
                const SizedBox(width: 16),
                _buildMetric(
                  '週間新規',
                  channel['weeklyNewUsers'],
                  Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, dynamic value, Color color) {
    return Column(
      children: [
        Text(
          value?.toString() ?? '0',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final channels = d != null && d['channels'] is List
        ? List<Map<String, dynamic>>.from(
            (d['channels'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map)),
          )
        : <Map<String, dynamic>>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('週次ダイジェスト'),
        backgroundColor: const Color(0xFF009688),
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
                      if (d != null && d['weekLabel'] != null) ...[
                        Text(
                          d['weekLabel'].toString(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (d != null && d['totalNewUsers'] != null)
                        Row(
                          children: [
                            const Icon(
                              Icons.person_add,
                              color: const Color(0xFF009688),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '今週の新規ユーザー: ${d['totalNewUsers']}人',
                              style: const TextStyle(
                                fontSize: 14,
                                color: const Color(0xFF009688),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      if (channels.isEmpty)
                        const Text(
                          'チャネルデータがありません',
                          style: TextStyle(color: const Color(0xFF9CA3AF)),
                        )
                      else ...[
                        const Text(
                          'チャネル別指標',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...channels.map(_buildChannelCard),
                      ],
                    ],
                  ),
                ),
    );
  }
}
