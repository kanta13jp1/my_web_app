import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ホーム画面に表示するリーダーボードカード。
/// 公開プロフィールユーザーのノート数をランキング表示し、
/// ソーシャルプルーフと新規登録の動機を提供する。
class LeaderboardCard extends StatefulWidget {
  const LeaderboardCard({super.key});

  @override
  State<LeaderboardCard> createState() => _LeaderboardCardState();
}

class _LeaderboardCardState extends State<LeaderboardCard> {
  bool _loading = true;
  List<_RankEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // 公開プロフィール + ノート数をクエリ
      final profiles = await Supabase.instance.client
          .from('user_profiles')
          .select('user_id, display_name, avatar_url')
          .eq('is_public', true)
          .limit(20);

      final List<_RankEntry> entries = [];
      for (final p in profiles) {
        final uid = p['user_id'] as String;
        final countRes = await Supabase.instance.client
            .from('notes')
            .select('id')
            .eq('user_id', uid)
            .count(CountOption.exact);
        final noteCount = countRes.count;
        if (noteCount > 0) {
          entries.add(
            _RankEntry(
              userId: uid,
              displayName: p['display_name'] as String? ?? 'ユーザー',
              avatarUrl: p['avatar_url'] as String?,
              noteCount: noteCount,
            ),
          );
        }
      }

      entries.sort((a, b) => b.noteCount.compareTo(a.noteCount));
      final top5 = entries.take(5).toList();

      if (!mounted) return;
      setState(() {
        _entries = top5;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _entries.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.leaderboard,
                  size: 18,
                  color: Color(0xFF6366F1),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'ユーザーランキング',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  'ノート数',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._entries.asMap().entries.map((e) {
              final rank = e.key + 1;
              final entry = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RankRow(
                  rank: rank,
                  entry: entry,
                  isDark: isDark,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final int rank;
  final _RankEntry entry;
  final bool isDark;

  const _RankRow({
    required this.rank,
    required this.entry,
    required this.isDark,
  });

  String get _rankEmoji {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '$rank';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            _rankEmoji,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 14,
          backgroundColor: const Color(0xFF6366F1).withAlpha(30),
          backgroundImage: entry.avatarUrl != null
              ? NetworkImage(entry.avatarUrl!)
              : null,
          child: entry.avatarUrl == null
              ? Text(
                  entry.displayName.isNotEmpty
                      ? entry.displayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6366F1),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            entry.displayName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: rank <= 3 ? FontWeight.w700 : FontWeight.w500,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '${entry.noteCount}件',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: rank == 1
                ? const Color(0xFFEAB308)
                : (isDark ? Colors.grey[300] : Colors.grey[700]),
          ),
        ),
      ],
    );
  }
}

class _RankEntry {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int noteCount;

  const _RankEntry({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.noteCount,
  });
}
