import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // チャート用（pubspecに含まれている想定）
import 'package:share_plus/share_plus.dart';
import '../main.dart';

class CmoPage extends StatefulWidget {
  const CmoPage({super.key});

  @override
  State<CmoPage> createState() => _CmoPageState();
}

class _CmoPageState extends State<CmoPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isGeneratingPr = false;

  // 分析データ
  int _totalPoints = 0;
  int _taskCount = 0;
  List<FlSpot> _pointHistory = [];

  // PRデータ
  Map<String, dynamic>? _lastPr;
  String? _usedModel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 基本統計
      final stats = await supabase
          .from('user_stats')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      // 簡易的な履歴データのシミュレーション（本来は履歴テーブルが必要だが、ここではstatsから擬似生成するか、notesの履歴を使う）
      // 今回はnotesの作成日を使って「活動量の推移」をグラフ化します
      final notes = await supabase
          .from('notes')
          .select('created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      // 日ごとのタスク数を集計
      Map<String, int> dailyCounts = {};
      for (var note in notes) {
        String date = note['created_at'].toString().substring(0, 10);
        dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
      }

      List<FlSpot> spots = [];
      double index = 0;
      // 直近7日分などを表示
      dailyCounts.forEach((date, count) {
        spots.add(FlSpot(index, count.toDouble()));
        index++;
      });

      if (mounted) {
        setState(() {
          _totalPoints = stats?['total_points'] ?? 0;
          _taskCount = stats?['notes_created'] ?? 0;
          _pointHistory = spots.isNotEmpty
              ? spots
              : [const FlSpot(0, 0), const FlSpot(1, 1)];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generatePressRelease() async {
    setState(() => _isGeneratingPr = true);
    try {
      // 本日の実績を集計（簡易版：全期間の平均などを混ぜてそれっぽくする）
      // 本来は created_at >= today のクエリを投げる
      final now = DateTime.now();
      final todayStr = now.toIso8601String().substring(0, 10);
      final userId = supabase.auth.currentUser!.id;

      final todayNotes = await supabase
          .from('notes')
          .count()
          .eq('user_id', userId)
          .gte('created_at', todayStr);
      final todayDanshari = await supabase
          .from('notes')
          .count()
          .eq('user_id', userId)
          .eq('is_archived', true)
          .gte('updated_at', todayStr);

      final dailyStats = {
        'task_count': todayNotes,
        'danshari_count': todayDanshari,
        'points_earned': (todayDanshari * 100) + (todayNotes * 10) // 概算
      };

      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {'action': 'generate_press_release', 'dailyStats': dailyStats},
      );

      if (response.status != 200) throw Exception('AI Error');
      final data = response.data;

      setState(() {
        _lastPr = data['result'];
        _usedModel = data['used_model'];
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('PR生成エラー: $e')));
    } finally {
      setState(() => _isGeneratingPr = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(' 広報マーケティング (CMO)'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.purple.shade200,
          tabs: const [
            Tab(icon: Icon(Icons.campaign), text: 'プレスリリース'),
            Tab(icon: Icon(Icons.show_chart), text: 'ブランド分析'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPrTab(),
          _buildAnalyticsTab(),
        ],
      ),
    );
  }

  Widget _buildPrTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.newspaper, size: 64, color: Colors.purple),
          const SizedBox(height: 16),
          const Text(
            '本日の活動を、世界へ。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'AIがあなたの些細な日常を、壮大な企業ニュースに変えます。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _isGeneratingPr ? null : _generatePressRelease,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
            ),
            icon: _isGeneratingPr
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: const Text('本日のプレスリリースを発行する'),
          ),
          if (_lastPr != null) ...[
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                border: Border.all(color: Colors.purple.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_usedModel != null)
                    Text('Writer: $_usedModel',
                        style: TextStyle(
                            fontSize: 10, color: Colors.purple.shade300)),
                  const SizedBox(height: 8),
                  Text(
                    _lastPr!['headline'] ?? '',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 24),
                  Text(
                    _lastPr!['body'] ?? '',
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.trending_up,
                            color: Colors.purple, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(_lastPr!['market_analysis'] ?? '',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.purple.shade800))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Share.share(
                            '${_lastPr!['headline']}\n\n${_lastPr!['body']}\n\n#自分株式会社',
                            subject: 'プレスリリース');
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('メディア（SNS）に公開'),
                    ),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildStatCard('時価総額(Pt)', '$_totalPoints',
                        Icons.currency_yen, Colors.amber),
                    const SizedBox(width: 16),
                    _buildStatCard('累積生産数', '$_taskCount', Icons.check_circle,
                        Colors.green),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('生産性チャート (Activity)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(right: 16, top: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.grey.withOpacity(0.1), blurRadius: 10)
                      ],
                    ),
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _pointHistory,
                            isCurved: true,
                            color: Colors.purple,
                            barWidth: 4,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                                show: true,
                                color: Colors.purple.withOpacity(0.2)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('このデータはあなたの「ブランド価値」を示しています。',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4))
          ],
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
