import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  Map<String, dynamic>? _summary;
  String? _errorMessage;

  String _selectedPeriod = 'すべて';
  String _selectedSince = '2020-01-01T00:00:00Z';

  final _periods = {
    '今日': () {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day).toIso8601String();
    },
    '今週': () {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      return DateTime(weekStart.year, weekStart.month, weekStart.day)
          .toIso8601String();
    },
    '今月': () {
      final now = DateTime.now();
      return DateTime(now.year, now.month, 1).toIso8601String();
    },
    '今年': () {
      return DateTime(DateTime.now().year, 1, 1).toIso8601String();
    },
    'すべて': () => '2020-01-01T00:00:00Z',
  };

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _supabase.functions.invoke(
        'growth-achievement-summary',
        body: {'since': _selectedSince, 'label': _selectedPeriod},
      );
      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        throw Exception(data?['error'] ?? 'データの取得に失敗しました');
      }
      setState(() => _summary = data);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _selectPeriod(String label) {
    setState(() {
      _selectedPeriod = label;
      _selectedSince = _periods[label]!();
    });
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('グロース達成サマリー'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetch,
            tooltip: '更新',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.green.shade50,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _periods.keys
                  .map((label) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: _selectedPeriod == label,
                          onSelected: (_) => _selectPeriod(label),
                          selectedColor: Colors.green,
                          labelStyle: TextStyle(
                            color: _selectedPeriod == label
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(_errorMessage!,
                                style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetch,
                              child: const Text('再試行'),
                            ),
                          ],
                        ),
                      )
                    : _summary == null
                        ? const Center(child: Text('データがありません'))
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  '期間: ${_summary!['label']}',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _MetricCard(
                                        label: '新規ユーザー',
                                        value: _summary!['newUsers']
                                            .toString(),
                                        icon: Icons.person_add,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _MetricCard(
                                        label: '累計ユーザー',
                                        value: _summary!['totalUsersEver']
                                            .toString(),
                                        icon: Icons.people,
                                        color: Colors.indigo,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _MetricCard(
                                        label: '獲得シグナル',
                                        value: _summary!['acquisitionSignals']
                                            .toString(),
                                        icon: Icons.trending_up,
                                        color: Colors.green,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _MetricCard(
                                        label: '紹介成立',
                                        value: _summary!['referralsCompleted']
                                            .toString(),
                                        icon: Icons.share,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _MetricCard(
                                  label: 'インポートプレビュー',
                                  value:
                                      _summary!['importPreviews'].toString(),
                                  icon: Icons.upload_file,
                                  color: Colors.teal,
                                ),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(label,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color),
            ),
          ],
        ),
      ),
    );
  }
}
