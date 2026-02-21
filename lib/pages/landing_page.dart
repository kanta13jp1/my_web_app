import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;
  bool _isLoadingStats = true;
  int _todayViews = 0;
  int _monthViews = 0;
  int _totalViews = 0;
  List<FlSpot> _pvSpots = [];
  List<String> _pvLabels = []; // x軸ラベル（M/d）

  @override
  void initState() {
    super.initState();
    _initLpViewStats(); // LP表示時に1回カウントして取得
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _initLpViewStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final supabase = Supabase.instance.client;

      // ① 1PV増やす（LP表示＝1回）
      await supabase.rpc('increment_lp_view');

      // ② 集計＋今月シリーズ取得
      final res = await supabase.rpc('get_lp_view_stats');
      final m = Map<String, dynamic>.from(res as Map);

      final today = (m['today'] as num?)?.toInt() ?? 0;
      final month = (m['month'] as num?)?.toInt() ?? 0;
      final total = (m['total'] as num?)?.toInt() ?? 0;

      final series = (m['series'] as List?) ?? [];
      final spots = <FlSpot>[];
      final labels = <String>[];

      for (int i = 0; i < series.length; i++) {
        final row = Map<String, dynamic>.from(series[i] as Map);
        final dateStr = (row['date'] ?? '').toString(); // "YYYY-MM-DD"
        final count = (row['count'] as num?)?.toDouble() ?? 0;

        spots.add(FlSpot(i.toDouble(), count));

        final d = DateTime.tryParse(dateStr);
        labels.add(d == null ? '' : DateFormat('M/d').format(d));
      }

      if (!mounted) return;
      setState(() {
        _todayViews = today;
        _monthViews = month;
        _totalViews = total;
        _pvSpots = spots;
        _pvLabels = labels;
        _isLoadingStats = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingStats = false);
      // 必要ならSnackBar出す
    }
  }

  Future<void> _auth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メールアドレスとパスワードを入力してください')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isSignUp) {
        await Supabase.instance.client.auth
            .signUp(email: email, password: password);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('登録完了。確認メールを送信しました。')),
          );
        }
      } else {
        await Supabase.instance.client.auth
            .signInWithPassword(email: email, password: password);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('認証エラー: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPvSection() {
    final fmt = NumberFormat('#,###', 'ja_JP');

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('LP Views',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // 3指標
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _pvKpi('今日', fmt.format(_todayViews)),
                _pvKpi('今月', fmt.format(_monthViews)),
                _pvKpi('総計', fmt.format(_totalViews)),
              ],
            ),

            const SizedBox(height: 16),

            // グラフ
            SizedBox(
              height: 180,
              child: _isLoadingStats
                  ? const Center(child: CircularProgressIndicator())
                  : (_pvSpots.isEmpty
                      ? const Center(child: Text('データなし'))
                      : LineChart(
                          LineChartData(
                            minY: 0,
                            gridData: const FlGridData(show: true),
                            borderData: FlBorderData(show: true),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(
                                    showTitles: true, reservedSize: 36),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 28,
                                  interval: (_pvLabels.length / 5)
                                      .clamp(1, 999)
                                      .toDouble(),
                                  getTitlesWidget: (v, meta) {
                                    final i = v.toInt();
                                    final label =
                                        (i >= 0 && i < _pvLabels.length)
                                            ? _pvLabels[i]
                                            : '';
                                    return SideTitleWidget(
                                        axisSide: meta.axisSide,
                                        child: Text(label,
                                            style:
                                                const TextStyle(fontSize: 10)));
                                  },
                                ),
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _pvSpots,
                                isCurved: false,
                                dotData: const FlDotData(show: false),
                                barWidth: 2,
                              ),
                            ],
                          ),
                        )),
            ),
            const SizedBox(height: 6),
            const Text('※グラフは今月の日次View（0埋め）',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _pvKpi(String label, String value) {
    return SizedBox(
      width: 110,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('自分株式会社へようこそ')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.business, size: 80, color: Colors.blue),
              const SizedBox(height: 16),

              _buildPvSection(), // ← 追加

              const SizedBox(height: 24),
              const Text(
                '自分株式会社',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Me Inc.',
                style: TextStyle(fontSize: 20, color: Colors.grey),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _auth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isSignUp ? '新規登録 (Sign Up)' : 'ログイン (Login)',
                          style: const TextStyle(fontSize: 18),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _isSignUp = !_isSignUp),
                child: Text(
                  _isSignUp ? 'すでにアカウントをお持ちの方はログイン' : 'アカウントをお持ちでない方は新規登録',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
