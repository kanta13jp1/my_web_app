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
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions
          .invoke('enterprise-hub', body: {'action': 'forecast.list'});
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

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB0B0B0),
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
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchForecast,
                        child: const Text('再試行'),
                      ),
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
                          Text(
                            '収益サマリー',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.6,
                            children: [
                              _buildMetricCard(
                                '今月予測',
                                _forecast!['monthly_forecast']?.toString() ??
                                    '-',
                                Icons.trending_up,
                                const Color(0xFF4CAF50),
                              ),
                              _buildMetricCard(
                                '四半期予測',
                                _forecast!['quarterly_forecast']?.toString() ??
                                    '-',
                                Icons.bar_chart,
                                const Color(0xFF3D5AFE),
                              ),
                              _buildMetricCard(
                                '年間予測',
                                _forecast!['annual_forecast']?.toString() ??
                                    '-',
                                Icons.show_chart,
                                const Color(0xFFFF6B35),
                              ),
                              _buildMetricCard(
                                '成長率',
                                _forecast!['growth_rate']?.toString() ?? '-',
                                Icons.arrow_upward,
                                const Color(0xFF3D5AFE),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_forecast!['insights'] is List) ...[
                            Text(
                              'AI インサイト',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            ...(_forecast!['insights'] as List).map(
                              (insight) => Card(
                                margin: const EdgeInsets.only(
                                  bottom: 8,
                                ),
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.lightbulb,
                                    color: Color(0xFFFFC107),
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
