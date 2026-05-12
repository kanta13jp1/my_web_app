import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppAnalyticsDashboardPage extends StatefulWidget {
  const AppAnalyticsDashboardPage({super.key});

  @override
  State<AppAnalyticsDashboardPage> createState() =>
      _AppAnalyticsDashboardPageState();
}

class _AppAnalyticsDashboardPageState extends State<AppAnalyticsDashboardPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _analytics;

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'core-hub',
        body: {'action': 'analytics.summary'},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        setState(() => _analytics = data);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アプリアナリティクス'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchAnalytics,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'アプリ利用状況',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.5,
                        children: [
                          _metricCard(
                            '総ユーザー数',
                            _analytics?['total_users']?.toString() ?? '-',
                            Icons.people,
                            const Color(0xFF6366F1),
                          ),
                          _metricCard(
                            'DAU',
                            _analytics?['dau']?.toString() ?? '-',
                            Icons.today,
                            Colors.green,
                          ),
                          _metricCard(
                            'セッション数',
                            _analytics?['sessions']?.toString() ?? '-',
                            Icons.bar_chart,
                            Colors.orange,
                          ),
                          _metricCard(
                            '平均滞在時間',
                            _analytics?['avg_duration']?.toString() ?? '-',
                            Icons.timer,
                            Colors.blue,
                          ),
                        ],
                      ),
                      if (_analytics != null) ...[
                        const SizedBox(height: 24),
                        const Text(
                          '人気ページ TOP 5',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...(() {
                          final pages = _analytics!['top_pages'];
                          if (pages is! List) return <Widget>[];
                          return pages.take(5).map((p) {
                            final page = p as Map<String, dynamic>;
                            return ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.web,
                                color: Color(0xFF6366F1),
                              ),
                              title: Text(page['path']?.toString() ?? ''),
                              trailing: Text(
                                '${page['views'] ?? 0}回',
                                style: const TextStyle(
                                  color: Color(0xFF6366F1),
                                  height: 1.5,
                                ),
                              ),
                            );
                          }).toList();
                        })(),
                      ],
                    ],
                  ),
                ),
    );
  }
}
