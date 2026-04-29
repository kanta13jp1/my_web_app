import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiUniversityStreaksPage extends StatefulWidget {
  const AiUniversityStreaksPage({super.key});

  @override
  State<AiUniversityStreaksPage> createState() =>
      _AiUniversityStreaksPageState();
}

class _AiUniversityStreaksPageState extends State<AiUniversityStreaksPage> {
  bool _loading = false;
  Map<String, dynamic>? _streak;
  List<dynamic> _leaderboard = [];
  String? _error;

  Future<void> _fetch() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'ai-hub',
        body: {'action': 'university.streak'},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final streak = data['streak'];
        setState(
          () => _streak = streak is Map<String, dynamic> ? streak : null,
        );
      }
      final lb = await Supabase.instance.client.functions.invoke(
        'ai-hub',
        body: {'action': 'university.leaderboard', 'limit': 10},
      );
      final lbData = lb.data;
      if (lbData is Map && lbData['leaderboard'] is List) {
        setState(() => _leaderboard = lbData['leaderboard'] as List);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI大学 学習ストリーク'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _fetch,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'エラー: $_error',
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _fetch,
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
                      if (_streak != null) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _StatItem(
                                  label: '現在のストリーク',
                                  value: '${_streak!['current_streak'] ?? 0}日',
                                  icon: '🔥',
                                ),
                                _StatItem(
                                  label: '最長ストリーク',
                                  value: '${_streak!['longest_streak'] ?? 0}日',
                                  icon: '🏆',
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_leaderboard.isNotEmpty) ...[
                        const Text(
                          'ストリークランキング',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._leaderboard.asMap().entries.map((e) {
                          final item = e.value as Map<String, dynamic>;
                          return ListTile(
                            leading: Text(
                              '${e.key + 1}位',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                height: 1.5,
                              ),
                            ),
                            title: Text(
                              item['user_id'] as String? ?? '-',
                            ),
                            trailing: Text(
                              '${item['current_streak'] ?? 0}日 🔥',
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          icon,
          style: const TextStyle(
            fontSize: 32,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
