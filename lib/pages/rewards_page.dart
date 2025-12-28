import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  bool _isLoading = true;
  int _totalPoints = 0;
  int _currentLevel = 1;

  @override
  void initState() {
    super.initState();
    _fetchUserStats();
  }

  Future<void> _fetchUserStats() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await supabase
          .from('user_stats')
          .select('total_points, current_level')
          .eq('user_id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (data != null) {
            _totalPoints = data['total_points'] as int? ?? 0;
            _currentLevel = data['current_level'] as int? ?? 1;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error fetching rewards: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(' ステータス報酬'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black87,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ステータスカード
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade300, Colors.orange.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.emoji_events,
                            size: 60, color: Colors.white),
                        const SizedBox(height: 16),
                        Text(
                          'Level $_currentLevel',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_totalPoints pt',
                          style: const TextStyle(
                            fontSize: 24,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  const Text(
                    '獲得した称号',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // 簡易的な称号リスト（実装簡略化のため固定表示または将来的な拡張用）
                  if (_totalPoints == 0)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('まだポイントがありません。\nメモを書いたり断捨離してポイントを貯めましょう！',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildBadge(
                            '初めの一歩', Icons.directions_walk, _totalPoints >= 10),
                        _buildBadge('断捨離見習い', Icons.cleaning_services,
                            _totalPoints >= 100),
                        _buildBadge(
                            'メモの達人', Icons.edit_note, _totalPoints >= 500),
                        _buildBadge(
                            '継続の力', Icons.calendar_month, _totalPoints >= 1000),
                        _buildBadge('ミニマリスト', Icons.home, _totalPoints >= 2000),
                        _buildBadge(
                            '伝説', Icons.auto_awesome, _totalPoints >= 5000),
                      ],
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildBadge(String label, IconData icon, bool isUnlocked) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUnlocked ? Colors.amber.shade100 : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 30,
            color: isUnlocked ? Colors.amber.shade800 : Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isUnlocked ? Colors.black87 : Colors.grey,
            fontWeight: isUnlocked ? FontWeight.bold : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
