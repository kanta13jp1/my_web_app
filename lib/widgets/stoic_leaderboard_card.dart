import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';

class StoicLeaderboardCard extends StatefulWidget {
  const StoicLeaderboardCard({super.key});

  @override
  State<StoicLeaderboardCard> createState() => _StoicLeaderboardCardState();
}

class _StoicLeaderboardCardState extends State<StoicLeaderboardCard> {
  List<Map<String, dynamic>> _leaderboard = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'tools-hub',
        body: {'action': 'habit.leaderboard'},
      );

      final data = response.data as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        if (mounted) {
          setState(() {
            _leaderboard = (data['leaderboard'] as List<dynamic>)
                .cast<Map<String, dynamic>>();
            _isLoading = false;
          });
        }
      }
    } catch (e, st) {
      AppLogger.error('リーダーボードの取得に失敗しました', error: e, stackTrace: st);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1A2233) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const stoicColor = Color(0xFF10B981);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: stoicColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Color(0xFFFFCA28)),
              const SizedBox(width: 8),
              Text(
                '全国 精神性・防衛資産ランキング',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  height: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '欲望をコントロールし、最も資産を防衛したトッププレイヤーたち',
            style: TextStyle(
              fontSize: 12,
              color: subColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _leaderboard.isEmpty
                  ? Text(
                      'まだデータがありません。最初のランカーになりましょう！',
                      style: TextStyle(
                        color: subColor,
                        height: 1.5,
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _leaderboard.length,
                      separatorBuilder: (context, index) =>
                          Divider(color: subColor.withValues(alpha: 0.2)),
                      itemBuilder: (context, index) {
                        final item = _leaderboard[index];
                        final profile =
                            (item['user_profiles'] as Map<String, dynamic>?) ??
                                {};
                        final displayName =
                            (profile['display_name'] as String?) ?? '名無し役員';
                        final savedMoney = (item['saved_money'] as int?) ?? 0;
                        final stoicLevel = (item['stoic_level'] as int?) ?? 1;

                        return _buildRankingRow(
                          rank: index + 1,
                          name: displayName,
                          savedMoney: savedMoney,
                          level: stoicLevel,
                          textColor: textColor,
                          subColor: subColor,
                        );
                      },
                    ),
        ],
      ),
    );
  }

  Widget _buildRankingRow({
    required int rank,
    required String name,
    required int savedMoney,
    required int level,
    required Color textColor,
    required Color subColor,
  }) {
    final Color rankColor = rank == 1
        ? const Color(0xFFFFC107)
        : (rank == 2
            ? Theme.of(context).colorScheme.outlineVariant
            : (rank == 3 ? const Color(0xFFA1887F) : subColor));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '#$rank',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: rankColor,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: textColor,
                height: 1.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            'Lv.$level',
            style: TextStyle(
              fontSize: 12,
              color: subColor,
              height: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '¥$savedMoney',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF10B981),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
