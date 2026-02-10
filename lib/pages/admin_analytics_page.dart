import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:my_web_app/main.dart'; // 必要に応じてインポート

class AdminAnalyticsPage extends StatefulWidget {
  final SupabaseClient? supabaseClient;
  const AdminAnalyticsPage({super.key, this.supabaseClient});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  List<Map<String, dynamic>> _dailyStats = [];
  int _actualUserCount = 0;
  bool _isLoading = true;
  late final SupabaseClient _supabase;

  @override
  void initState() {
    super.initState();
    // 外部から渡されなければシングルトンを使用（main.dartの実装に合わせる）
    _supabase = widget.supabaseClient ?? Supabase.instance.client;
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final statsResponse = await _supabase
          .from('app_analytics')
          .select()
          .order('date', ascending: false)
          .limit(30);

      // 実際のユーザー総数を取得
      final userCountResponse = await _supabase
          .from('user_profiles')
          .select()
          .count(CountOption.exact);

      if (mounted) {
        setState(() {
          _dailyStats = List<Map<String, dynamic>>.from(statsResponse);
          _actualUserCount = userCountResponse.count;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // データ集計
    int totalViews = 0;
    int totalConversions = 0;
    int totalShares = 0;
    final Map<String, int> sourceBreakdown = {};

    // グラフ用の最大値を計算（スケーリング用）
    int maxDailyViews = 0;

    for (var stat in _dailyStats) {
      final views = stat['landing_views'] as int? ?? 0;
      final conv = stat['conversions'] as int? ?? 0;

      totalViews += views;
      totalConversions += conv;
      totalShares += (stat['share_count'] as int? ?? 0);

      if (views > maxDailyViews) maxDailyViews = views;

      // ソース内訳を集計
      final sources = stat['source_details'];
      if (sources != null && sources is Map) {
        sources.forEach((key, value) {
          final count = value as int? ?? 0;
          sourceBreakdown[key] = (sourceBreakdown[key] ?? 0) + count;
        });
      }
    }

    // 最新のデータが右に来るようにリストを反転（グラフ描画用）
    final chartData = _dailyStats.reversed.toList();

    final double totalCvr =
        totalViews == 0 ? 0 : (totalConversions / totalViews * 100);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // 背景色を少しグレーに
      appBar: AppBar(
        title: const Text('経営分析ダッシュボード'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
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
                  // 1. KPIサマリーカード
                  _buildKpiSummaryCard(
                      totalCvr, totalViews, _actualUserCount, totalShares),

                  const SizedBox(height: 24),

                  // 2. トレンドグラフ（棒グラフ）
                  const Text(
                    '過去30日間の推移 (閲覧 vs 登録)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 200,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _buildTrendChart(chartData, maxDailyViews),
                  ),

                  const SizedBox(height: 24),

                  // 3. 流入元分析（構成比バー）
                  const Text(
                    '流入元チャネル (Source Breakdown)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildSourceDistribution(sourceBreakdown),

                  const SizedBox(height: 24),

                  // 4. 詳細データリスト
                  const Text(
                    '日次レポート詳細',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildDailyList(),
                ],
              ),
            ),
    );
  }

  // KPIサマリーカード
  Widget _buildKpiSummaryCard(double cvr, int views, int users, int shares) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text('現在のコンバージョン率 (CVR)',
                style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  cvr.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: _getCvrColor(cvr),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0, left: 4),
                  child: Text('%',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _getCvrColor(cvr))),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('総閲覧数', '$views', Icons.visibility, Colors.blue),
                _buildStatItem('総ユーザー', '$users', Icons.group, Colors.indigo),
                _buildStatItem('シェア', '$shares', Icons.share, Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getCvrColor(double cvr) {
    if (cvr >= 10) return Colors.green;
    if (cvr >= 5) return Colors.orange;
    return Colors.red;
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color.withOpacity(0.8)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  // カスタム棒グラフ（ライブラリ不使用）
  Widget _buildTrendChart(List<Map<String, dynamic>> data, int maxViews) {
    if (data.isEmpty) {
      return const Center(child: Text("データがありません"));
    }

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final barWidth = (width / (data.length * 2)).clamp(4.0, 12.0);

      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: data.map((stat) {
          final views = stat['landing_views'] as int? ?? 0;
          final conv = stat['conversions'] as int? ?? 0;

          // 高さの比率計算 (最大値を1.0とする)
          // 0除算回避のため maxViews が 0 の場合は 1 とする
          final double viewHeightRatio = maxViews == 0 ? 0 : (views / maxViews);
          final double convHeightRatio = maxViews == 0 ? 0 : (conv / maxViews);

          // 日付の整形 (例: "2023-10-01" -> "10/1")
          String label = "";
          try {
            final date = DateTime.parse(stat['date'].toString());
            label = "${date.month}/${date.day}";
          } catch (_) {
            label = "?";
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // グラフ部分
              Expanded(
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // 背景（最大高さの枠）
                    Container(width: barWidth, color: Colors.transparent),
                    // 閲覧数（青）
                    FractionallySizedBox(
                      heightFactor: viewHeightRatio,
                      child: Container(
                        width: barWidth,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    // コンバージョン数（濃い青/オレンジ）
                    FractionallySizedBox(
                      heightFactor: convHeightRatio,
                      child: Container(
                        width: barWidth,
                        decoration: BoxDecoration(
                          color: Colors.indigo,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // 日付ラベル（5件に1件表示など間引く）
              if (data.indexOf(stat) % 5 == 0 ||
                  data.indexOf(stat) == data.length - 1)
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                )
              else
                const Text("", style: TextStyle(fontSize: 10)),
            ],
          );
        }).toList(),
      );
    });
  }

  // 流入元の構成比バー
  Widget _buildSourceDistribution(Map<String, int> sources) {
    if (sources.isEmpty) {
      return const Card(
          child: Padding(padding: EdgeInsets.all(16), child: Text("データなし")));
    }

    int total = sources.values.fold(0, (sum, count) => sum + count);

    // ソートして多い順に
    final sortedEntries = sources.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 構成比バー
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 20,
                child: Row(
                  children: sortedEntries.map((e) {
                    final double ratio = e.value / total;
                    return Expanded(
                      flex: e.value,
                      child: Container(
                        color: _getSourceColor(e.key),
                        child: Tooltip(
                          message: "${e.key}: ${e.value} ($ratio%)",
                          child: Container(),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 凡例 (Legend)
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: sortedEntries.map((e) {
                final percent = (e.value / total * 100).toStringAsFixed(1);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getSourceColor(e.key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatSourceName(e.key),
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      " ($percent%)",
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSourceName(String key) {
    if (key == 'direct') return '直接/その他';
    if (key == 'x_share') return 'X (Twitter)';
    if (key == 'qr_scan') return 'QRコード';
    return key;
  }

  Color _getSourceColor(String key) {
    switch (key) {
      case 'direct':
        return Colors.grey;
      case 'x_share':
        return Colors.black; // X brand color
      case 'qr_scan':
        return Colors.teal;
      case 'facebook':
        return Colors.blue.shade800;
      default:
        return Colors.indigo;
    }
  }

  // 日次リスト
  Widget _buildDailyList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _dailyStats.length,
      itemBuilder: (context, index) {
        final stat = _dailyStats[index];
        final views = stat['landing_views'] as int? ?? 0;
        final conv = stat['conversions'] as int? ?? 0;
        final cvr = views == 0 ? 0.0 : (conv / views * 100);

        // 日付整形
        String dateStr = stat['date'].toString();
        try {
          final d = DateTime.parse(dateStr);
          dateStr = "${d.year}/${d.month}/${d.day}";
        } catch (_) {}

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Text(dateStr,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Row(
              children: [
                Icon(Icons.visibility, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text("$views  "),
                Icon(Icons.person_add, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text("$conv"),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${cvr.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _getCvrColor(cvr),
                  ),
                ),
                const Text("CVR",
                    style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }
}
