import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AI競馬予想プロバイダー別的中率リーダーボード
class HorseProviderLeaderboardPage extends StatefulWidget {
  const HorseProviderLeaderboardPage({super.key});

  @override
  State<HorseProviderLeaderboardPage> createState() =>
      _HorseProviderLeaderboardPageState();
}

class _HorseProviderLeaderboardPageState
    extends State<HorseProviderLeaderboardPage> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await Supabase.instance.client.functions.invoke(
        'tools-hub',
        body: {'action': 'horseracing.provider_leaderboard'},
      );
      final data = resp.data as Map<String, dynamic>?;
      final lb = (data?['leaderboard'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _rows = lb.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Color _providerColor(String provider) {
    switch (provider.toLowerCase()) {
      case 'google':
        return const Color(0xFF4285F4);
      case 'openai':
        return const Color(0xFF10A37F);
      case 'anthropic':
        return const Color(0xFFFF6B35);
      case 'x':
      case 'xai':
        return const Color(0xFF94A3B8);
      default:
        return const Color(0xFF6366F1);
    }
  }

  Widget _rankBadge(int rank) {
    Color color;
    switch (rank) {
      case 1:
        color = const Color(0xFFFFC107);
        break;
      case 2:
        color = const Color(0xFF9CA3AF);
        break;
      case 3:
        color = const Color(0xFFA1887F);
        break;
      default:
        color = const Color(0xFF475569);
    }
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      alignment: Alignment.center,
      child: Text(
        '$rank',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          height: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('AI競馬 プロバイダー別的中率'),
        backgroundColor: const Color(0xFF0A0A0A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: '更新',
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
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFB91C1C),
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'データ取得失敗',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _rows.isEmpty
                  ? const Center(
                      child: Text(
                        'データがありません。予想が蓄積されると表示されます。',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              SizedBox(width: 36),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'プロバイダー',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 52,
                                child: Text(
                                  '学習スコア',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(
                                width: 44,
                                child: Text(
                                  '1着率',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(
                                width: 52,
                                child: Text(
                                  'スキップ精度',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(
                                width: 56,
                                child: Text(
                                  'ベスト券種',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._rows.asMap().entries.map((entry) {
                          final rank = entry.key + 1;
                          final row = entry.value;
                          final provider = row['provider'] as String? ?? '';
                          final model = row['model'] as String? ?? provider;
                          final firstHitRate =
                              (row['first_hit_rate'] as num?)?.toDouble() ?? 0;
                          final avgLearningScore =
                              (row['avg_learning_score'] as num?)?.toDouble() ??
                                  0;
                          final skipAccuracyPct =
                              (row['skip_accuracy_pct'] as num?)?.toDouble() ??
                                  0;
                          final bestBetType = row['best_bet_type'] as String?;
                          final bestBetHitRate =
                              (row['best_bet_hit_rate'] as num?)?.toDouble() ??
                                  0;
                          final color = _providerColor(provider);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141414),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: rank == 1
                                    ? const Color(0xFFFFC107)
                                        .withValues(alpha: 0.3)
                                    : const Color(0xFF1F1F1F),
                              ),
                            ),
                            child: Row(
                              children: [
                                _rankBadge(rank),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        provider,
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          height: 1.5,
                                        ),
                                      ),
                                      if (model != provider)
                                        Text(
                                          model.length > 20
                                              ? model.substring(0, 20)
                                              : model,
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 10,
                                            height: 1.5,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 52,
                                  child: Text(
                                    avgLearningScore > 0
                                        ? (avgLearningScore * 100)
                                            .toStringAsFixed(1)
                                        : '-',
                                    style: TextStyle(
                                      color: avgLearningScore > 0.5
                                          ? const Color(0xFF4ADE80)
                                          : Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      height: 1.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                SizedBox(
                                  width: 44,
                                  child: Text(
                                    '${(firstHitRate * 100).toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      color: firstHitRate > 0.3
                                          ? const Color(0xFF4ADE80)
                                          : Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      height: 1.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                SizedBox(
                                  width: 52,
                                  child: Text(
                                    skipAccuracyPct > 0
                                        ? '${skipAccuracyPct.toStringAsFixed(1)}%'
                                        : '-',
                                    style: TextStyle(
                                      color: skipAccuracyPct > 60
                                          ? const Color(0xFF4ADE80)
                                          : skipAccuracyPct > 40
                                              ? const Color(0xFFFBBF24)
                                              : Colors.white,
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                SizedBox(
                                  width: 56,
                                  child: bestBetType != null
                                      ? Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              bestBetType,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                height: 1.5,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            Text(
                                              '${bestBetHitRate.toStringAsFixed(1)}%',
                                              style: const TextStyle(
                                                color: Color(0xFF94A3B8),
                                                fontSize: 10,
                                                height: 1.5,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        )
                                      : const Text(
                                          '-',
                                          style: TextStyle(
                                            color: Color(0xFF64748B),
                                            height: 1.5,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
    );
  }
}
