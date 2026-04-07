import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 収益予測ページ
/// revenue-forecaster Edge Function と連携して売上・収益を予測
class RevenueForecasterPage extends StatefulWidget {
  const RevenueForecasterPage({super.key});

  @override
  State<RevenueForecasterPage> createState() => _RevenueForecasterPageState();
}

class _RevenueForecasterPageState extends State<RevenueForecasterPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _forecast;

  @override
  void initState() {
    super.initState();
    _fetchForecast();
  }

  Future<void> _fetchForecast() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response =
          await _supabase.functions.invoke('revenue-forecaster');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        setState(() => _forecast = data);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '収益予測の取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildMetricCard(String label, String value, IconData icon,
      Color color) {
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
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('収益予測'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchForecast,
            tooltip: '更新',
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
                      Text(_errorMessage!,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _fetchForecast,
                          child: const Text('再試行')),
                    ],
                  ),
                )
              : _forecast == null
                  ? const Center(child: Text('データがありません'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('収益サマリー',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium),
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics:
                                const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.6,
                            children: [
                              _buildMetricCard(
                                '今月予測',
                                _forecast!['monthly_forecast']
                                        ?.toString() ??
                                    '-',
                                Icons.trending_up,
                                Colors.green,
                              ),
                              _buildMetricCard(
                                '四半期予測',
                                _forecast!['quarterly_forecast']
                                        ?.toString() ??
                                    '-',
                                Icons.bar_chart,
                                Colors.blue,
                              ),
                              _buildMetricCard(
                                '年間予測',
                                _forecast!['annual_forecast']
                                        ?.toString() ??
                                    '-',
                                Icons.show_chart,
                                Colors.orange,
                              ),
                              _buildMetricCard(
                                '成長率',
                                _forecast!['growth_rate']
                                        ?.toString() ??
                                    '-',
                                Icons.arrow_upward,
                                Colors.purple,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_forecast!['insights'] is List) ...[
                            Text('AI インサイト',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium),
                            const SizedBox(height: 8),
                            ...(_forecast!['insights'] as List)
                                .map((insight) => Card(
                                      margin: const EdgeInsets.only(
                                          bottom: 8),
                                      child: ListTile(
                                        leading: const Icon(
                                          Icons.lightbulb,
                                          color: Colors.amber,
                                        ),
                                        title: Text(insight.toString()),
                                      ),
                                    ),
                                  ),
                          ],
                        ],
                      ),
                    ),
    );
  }
}
