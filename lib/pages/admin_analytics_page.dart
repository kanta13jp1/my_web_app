import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart'; // supabaseクライアントのため

class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  List<Map<String, dynamic>> _dailyStats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final response = await supabase
          .from('app_analytics')
          .select()
          .order('date', ascending: false)
          .limit(30);

      if (mounted) {
        setState(() {
          _dailyStats = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalViews = 0;
    int totalConversions = 0;
    for (var stat in _dailyStats) {
      totalViews += (stat['landing_views'] as int? ?? 0);
      totalConversions += (stat['conversions'] as int? ?? 0);
    }
    
    double totalCvr = totalViews == 0 ? 0 : (totalConversions / totalViews * 100);

    return Scaffold(
      appBar: AppBar(
        title: const Text(' アプリ分析ダッシュボード'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadStats();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 4,
                    color: Colors.indigo.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Text('現在のコンバージョン率 (CVR)', style: TextStyle(fontSize: 14, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Text(
                            '${totalCvr.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: totalCvr >= 10 ? Colors.green : (totalCvr >= 5 ? Colors.orange : Colors.red),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem('訪問数', '$totalViews'),
                              _buildStatItem('登録数', '$totalConversions'),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('日別レポート', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _dailyStats.length,
                    itemBuilder: (context, index) {
                      final stat = _dailyStats[index];
                      final views = stat['landing_views'] as int? ?? 0;
                      final conv = stat['conversions'] as int? ?? 0;
                      final cvr = views == 0 ? 0.0 : (conv / views * 100);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(stat['date'].toString()),
                          trailing: Text(
                            '${cvr.toStringAsFixed(1)}%',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Text('View: $views / Conv: $conv'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
