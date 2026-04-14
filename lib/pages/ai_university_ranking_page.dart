import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AI 大学 ランキングページ
/// ai_university_leaderboard ビューから TOP10 を表示する。
class AiUniversityRankingPage extends StatefulWidget {
  const AiUniversityRankingPage({super.key});

  @override
  State<AiUniversityRankingPage> createState() =>
      _AiUniversityRankingPageState();
}

class _AiUniversityRankingPageState extends State<AiUniversityRankingPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<_LeaderboardEntry> _entries = [];
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _myUserId = _supabase.auth.currentUser?.id;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _supabase
          .from('ai_university_leaderboard')
          .select()
          .order('rank')
          .limit(10)
          .timeout(const Duration(seconds: 10));

      final entries = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(_LeaderboardEntry.fromMap)
          .toList();

      if (mounted) {
        setState(() {
          _entries = entries;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        title: const Text('AI 大学 ランキング'),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.indigoAccent),
            )
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : _RankingBody(entries: _entries, myUserId: _myUserId),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: Colors.orange, size: 48),
            const SizedBox(height: 16),
            const Text(
              'ランキングを取得できませんでした',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('再試行'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _RankingBody extends StatelessWidget {
  const _RankingBody({required this.entries, required this.myUserId});
  final List<_LeaderboardEntry> entries;
  final String? myUserId;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_outlined, color: Colors.white38, size: 64),
            SizedBox(height: 16),
            Text(
              'まだランキングがありません\nAI大学でクイズに挑戦してみよう！',
              style: TextStyle(color: Colors.white54, fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // ヘッダー説明
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1a237e), Color(0xFF283593)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Text('🏆', style: TextStyle(fontSize: 28)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 大学 週間ランキング',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'クイズ正解数でランキング決定。全プロバイダーを制覇しよう！',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ランキングリスト
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final isMe = entry.userId == myUserId;
              return _RankCard(entry: entry, isMe: isMe);
            },
          ),
        ),

        // フッター説明
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'クイズに正解するとランキングに参加できます',
            style: TextStyle(color: Colors.white38, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _RankCard extends StatelessWidget {
  const _RankCard({required this.entry, required this.isMe});
  final _LeaderboardEntry entry;
  final bool isMe;

  static const _medals = {1: '🥇', 2: '🥈', 3: '🥉'};

  Color get _rankColor {
    switch (entry.rank) {
      case 1:
        return const Color(0xFFFFD700);
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    final medal = _medals[entry.rank];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isMe
            ? const Color(0xFF1a237e).withValues(alpha: 0.6)
            : const Color(0xFF16213e),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe ? Colors.indigoAccent : Colors.white12,
          width: isMe ? 1.5 : 0.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: SizedBox(
          width: 44,
          child: Center(
            child: medal != null
                ? Text(medal, style: const TextStyle(fontSize: 26))
                : Text(
                    '#${entry.rank}',
                    style: TextStyle(
                      color: _rankColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                entry.displayName,
                style: TextStyle(
                  color: isMe ? Colors.indigoAccent.shade100 : Colors.white,
                  fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isMe)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.indigoAccent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'あなた',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              const Icon(Icons.quiz, size: 13, color: Colors.amber),
              const SizedBox(width: 3),
              Text(
                '正解 ${entry.totalCorrect} 問',
                style: const TextStyle(color: Colors.amber, fontSize: 12),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.school, size: 13, color: Colors.white38),
              const SizedBox(width: 3),
              Text(
                '${entry.providersStudied} 社学習',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${entry.totalCorrect}pt',
              style: TextStyle(
                color: _rankColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            if (entry.lastStudiedAt != null)
              Text(
                _formatDate(entry.lastStudiedAt!),
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return '今日';
    if (diff.inDays == 1) return '昨日';
    if (diff.inDays < 7) return '${diff.inDays}日前';
    return '${dt.month}/${dt.day}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _LeaderboardEntry {
  const _LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.totalCorrect,
    required this.providersStudied,
    required this.lastStudiedAt,
    required this.rank,
  });

  final String userId;
  final String displayName;
  final int totalCorrect;
  final int providersStudied;
  final DateTime? lastStudiedAt;
  final int rank;

  factory _LeaderboardEntry.fromMap(Map<String, dynamic> m) {
    return _LeaderboardEntry(
      userId: m['user_id'] as String? ?? '',
      displayName: m['display_name'] as String? ?? '匿名ユーザー',
      totalCorrect: (m['total_correct'] as num?)?.toInt() ?? 0,
      providersStudied: (m['providers_studied'] as num?)?.toInt() ?? 0,
      lastStudiedAt: m['last_studied_at'] != null
          ? DateTime.tryParse(m['last_studied_at'] as String)
          : null,
      rank: (m['rank'] as num?)?.toInt() ?? 0,
    );
  }
}
