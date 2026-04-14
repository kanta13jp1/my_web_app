import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AI大学ランキングページ
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

      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _openUniversity() {
    Navigator.of(context).pushNamed('/gemini-university');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _RankingPalette.background,
      appBar: AppBar(
        backgroundColor: _RankingPalette.surface1,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: const Text(
          'AI大学ランキング',
          style: _RankingTextStyles.heading3,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '更新',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: _RankingPalette.indigo,
              ),
            )
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : _RankingBody(
                  entries: _entries,
                  myUserId: _myUserId,
                  onOpenUniversity: _openUniversity,
                ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _RankingPalette.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _RankingPalette.orange.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: _RankingPalette.orangeLight,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'ランキングを取得できませんでした',
                style: _RankingTextStyles.heading2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                '通信状況を確認して、もう一度お試しください。',
                style: _RankingTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                error,
                style: _RankingTextStyles.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('再試行'),
                style: FilledButton.styleFrom(
                  backgroundColor: _RankingPalette.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankingBody extends StatelessWidget {
  const _RankingBody({
    required this.entries,
    required this.myUserId,
    required this.onOpenUniversity,
  });

  final List<_LeaderboardEntry> entries;
  final String? myUserId;
  final VoidCallback onOpenUniversity;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return _EmptyRankingView(onOpenUniversity: onOpenUniversity);
    }

    final leader = entries.first;
    _LeaderboardEntry? myEntry;
    for (final entry in entries) {
      if (entry.userId == myUserId) {
        myEntry = entry;
        break;
      }
    }

    final maxProvidersStudied = entries.fold<int>(
      0,
      (best, entry) => entry.providersStudied > best
          ? entry.providersStudied
          : best,
    );

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _RankingHero(
            leader: leader,
            myEntry: myEntry,
            myUserId: myUserId,
            displayedPlayers: entries.length,
            maxProvidersStudied: maxProvidersStudied,
          ),
          const SizedBox(height: 20),
          const Text(
            'TOP 10',
            style: _RankingTextStyles.heading3,
          ),
          const SizedBox(height: 4),
          const Text(
            'クイズ正解数と学習社数の積み上がりが見える、いまの上位メンバーです。',
            style: _RankingTextStyles.bodySmall,
          ),
          const SizedBox(height: 14),
          for (final entry in entries) ...[
            _RankCard(
              entry: entry,
              isMe: entry.userId == myUserId,
            ),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _RankingPalette.surface2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: const Text(
              'ランキングは AI大学のクイズ正解数に応じて更新されます。毎日の1問を積み上げるほど、順位とストリークの両方が伸びていきます。',
              style: _RankingTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRankingView extends StatelessWidget {
  const _EmptyRankingView({required this.onOpenUniversity});

  final VoidCallback onOpenUniversity;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: _RankingPalette.heroGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: _RankingPalette.orange.withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _RankingPalette.orange.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _RankingPalette.orange.withValues(alpha: 0.28),
                    ),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: _RankingPalette.orangeLight,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'まだランキングは始まっていません',
                  style: _RankingTextStyles.heading2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'AI大学でクイズに挑戦すると、ここに学習の積み上がりが並びます。まずは気になる1社から始めてみましょう。',
                  style: _RankingTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onOpenUniversity,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('AI大学を開く'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _RankingPalette.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RankingHero extends StatelessWidget {
  const _RankingHero({
    required this.leader,
    required this.myEntry,
    required this.myUserId,
    required this.displayedPlayers,
    required this.maxProvidersStudied,
  });

  final _LeaderboardEntry leader;
  final _LeaderboardEntry? myEntry;
  final String? myUserId;
  final int displayedPlayers;
  final int maxProvidersStudied;

  @override
  Widget build(BuildContext context) {
    final leaderGap =
        myEntry == null ? null : max(0, leader.totalCorrect - myEntry!.totalCorrect);

    String summaryTitle;
    String summaryBody;
    if (myEntry != null) {
      summaryTitle = 'あなたは現在 ${myEntry!.rank} 位です';
      summaryBody = leaderGap == 0
          ? '首位タイです。このまま連続学習を伸ばして、差を広げましょう。'
          : '首位まであと $leaderGap 問。今日の1問で順位が動く位置にいます。';
    } else if (myUserId != null) {
      summaryTitle = 'いま見えているのは TOP10 です';
      summaryBody =
          'まだ表示圏外でも、クイズ正解数を積むほどここに近づきます。次の学習で一段上を狙えます。';
    } else {
      summaryTitle = 'ログインすると学習の積み上がりが残せます';
      summaryBody = 'AI大学でクイズに正解すると、ランキングとストリークに反映されます。';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;
        final metricWidth = isCompact
            ? (constraints.maxWidth - 8) / 2
            : (constraints.maxWidth - 24) / 4;

        return Container(
          decoration: BoxDecoration(
            gradient: _RankingPalette.heroGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: _RankingPalette.orange.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _RankingPalette.orange.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _RankingPalette.orange.withValues(alpha: 0.28),
                      ),
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: _RankingPalette.orangeLight,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: const [
                            Text(
                              'AI大学',
                              style: _RankingTextStyles.heading1,
                            ),
                            _StatusPill(
                              icon: Icons.leaderboard_rounded,
                              label: 'TOP10 表示中',
                              color: _RankingPalette.amber,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'クイズの積み上げが、そのままランキングに反映されます。',
                          style: _RankingTextStyles.heading2,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${leader.displayName} が ${leader.totalCorrect}pt で首位。学習社数は最大 $maxProvidersStudied 社まで広がっています。',
                          style: _RankingTextStyles.body,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: metricWidth,
                    child: _MetricTile(
                      icon: Icons.people_alt_outlined,
                      label: '表示中',
                      value: '$displayedPlayers人',
                      accent: _RankingPalette.indigoLight,
                    ),
                  ),
                  SizedBox(
                    width: metricWidth,
                    child: _MetricTile(
                      icon: Icons.workspace_premium_outlined,
                      label: '首位スコア',
                      value: '${leader.totalCorrect}pt',
                      accent: _RankingPalette.gold,
                    ),
                  ),
                  SizedBox(
                    width: metricWidth,
                    child: _MetricTile(
                      icon: Icons.hub_outlined,
                      label: '最多学習',
                      value: '$maxProvidersStudied社',
                      accent: _RankingPalette.green,
                    ),
                  ),
                  SizedBox(
                    width: metricWidth,
                    child: _MetricTile(
                      icon: myEntry != null
                          ? Icons.person_rounded
                          : Icons.school_rounded,
                      label: myEntry != null ? 'あなたの順位' : '次の一歩',
                      value: myEntry != null ? '#${myEntry!.rank}' : 'クイズ回答',
                      accent: _RankingPalette.orangeLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summaryTitle,
                      style: _RankingTextStyles.heading3.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      summaryBody,
                      style: _RankingTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RankCard extends StatelessWidget {
  const _RankCard({required this.entry, required this.isMe});

  final _LeaderboardEntry entry;
  final bool isMe;

  static const _medals = {
    1: '🥇',
    2: '🥈',
    3: '🥉',
  };

  Color get _rankColor {
    switch (entry.rank) {
      case 1:
        return _RankingPalette.gold;
      case 2:
        return _RankingPalette.silver;
      case 3:
        return _RankingPalette.bronze;
      default:
        return _RankingPalette.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final medal = _medals[entry.rank];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 460;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFF141A2B) : _RankingPalette.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isMe
                  ? _RankingPalette.indigo.withValues(alpha: 0.72)
                  : Colors.white.withValues(alpha: 0.08),
              width: isMe ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (isMe ? _RankingPalette.indigo : _RankingPalette.orange)
                    .withValues(alpha: isMe ? 0.16 : 0.05),
                blurRadius: isMe ? 18 : 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RankBadge(
                          rank: entry.rank,
                          medal: medal,
                          color: _rankColor,
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: _RankDetails(entry: entry, isMe: isMe)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _ScoreColumn(
                        score: entry.totalCorrect,
                        rankLabel: 'RANK #${entry.rank}',
                        color: _rankColor,
                      ),
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RankBadge(
                      rank: entry.rank,
                      medal: medal,
                      color: _rankColor,
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: _RankDetails(entry: entry, isMe: isMe)),
                    const SizedBox(width: 16),
                    _ScoreColumn(
                      score: entry.totalCorrect,
                      rankLabel: 'RANK #${entry.rank}',
                      color: _rankColor,
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _RankDetails extends StatelessWidget {
  const _RankDetails({required this.entry, required this.isMe});

  final _LeaderboardEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                entry.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _RankingTextStyles.body.copyWith(
                  color: isMe ? Colors.white : _RankingPalette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _RankingPalette.indigo.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _RankingPalette.indigo.withValues(alpha: 0.32),
                  ),
                ),
                child: const Text(
                  'あなた',
                  style: _RankingTextStyles.caption,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoPill(
              icon: Icons.quiz_rounded,
              label: '正解 ${entry.totalCorrect} 問',
              color: _RankingPalette.amber,
            ),
            _InfoPill(
              icon: Icons.hub_outlined,
              label: '${entry.providersStudied}社学習',
              color: _RankingPalette.indigoLight,
            ),
            if (entry.lastStudiedAt != null)
              _InfoPill(
                icon: Icons.schedule_rounded,
                label: _formatDate(entry.lastStudiedAt!),
                color: _RankingPalette.textSecondary,
              ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final local = dateTime.toLocal();
    final diff = now.difference(local);
    if (diff.inDays <= 0) return '今日学習';
    if (diff.inDays == 1) return '昨日学習';
    if (diff.inDays < 7) return '${diff.inDays}日前';
    return '${local.month}/${local.day}';
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({
    required this.rank,
    required this.medal,
    required this.color,
  });

  final int rank;
  final String? medal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Center(
        child: medal != null
            ? Text(
                medal!,
                style: const TextStyle(fontSize: 28),
              )
            : Text(
                '#$rank',
                style: _RankingTextStyles.heading3.copyWith(color: color),
              ),
      ),
    );
  }
}

class _ScoreColumn extends StatelessWidget {
  const _ScoreColumn({
    required this.score,
    required this.rankLabel,
    required this.color,
  });

  final int score;
  final String rankLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$score',
          style: _RankingTextStyles.score.copyWith(color: color),
        ),
        const Text(
          'pt',
          style: _RankingTextStyles.caption,
        ),
        const SizedBox(height: 6),
        Text(
          rankLabel,
          style: _RankingTextStyles.caption.copyWith(
            color: _RankingPalette.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _RankingTextStyles.label),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _RankingTextStyles.metricValue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.32),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: _RankingTextStyles.label.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: _RankingTextStyles.label.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _RankingPalette {
  static const Color background = Color(0xFF0A0A0A);
  static const Color surface1 = Color(0xFF1A1A1A);
  static const Color surface2 = Color(0xFF1E1E1E);
  static const Color orange = Color(0xFFFF6B35);
  static const Color orangeLight = Color(0xFFFF8C5A);
  static const Color indigo = Color(0xFF3D5AFE);
  static const Color indigoLight = Color(0xFF7986CB);
  static const Color green = Color(0xFF4CAF50);
  static const Color amber = Color(0xFFFFC107);
  static const Color gold = Color(0xFFFFD700);
  static const Color silver = Color(0xFFC0C0C0);
  static const Color bronze = Color(0xFFCD7F32);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textTertiary = Color(0xFF707070);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF101216),
      Color(0xFF16213E),
      Color(0xFF2A1B12),
    ],
  );
}

class _RankingTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: 0.96,
    height: 1.4,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0.72,
    height: 1.4,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    height: 1.4,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: _RankingPalette.textSecondary,
    height: 1.7,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    color: _RankingPalette.textSecondary,
    height: 1.6,
  );

  static const TextStyle label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: _RankingPalette.textSecondary,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 10,
    color: _RankingPalette.textSecondary,
    height: 1.5,
  );

  static const TextStyle metricValue = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    height: 1.4,
  );

  static const TextStyle score = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.0,
  );
}

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

  factory _LeaderboardEntry.fromMap(Map<String, dynamic> map) {
    return _LeaderboardEntry(
      userId: map['user_id'] as String? ?? '',
      displayName: map['display_name'] as String? ?? '匿名ユーザー',
      totalCorrect: (map['total_correct'] as num?)?.toInt() ?? 0,
      providersStudied: (map['providers_studied'] as num?)?.toInt() ?? 0,
      lastStudiedAt: map['last_studied_at'] != null
          ? DateTime.tryParse(map['last_studied_at'] as String)
          : null,
      rank: (map['rank'] as num?)?.toInt() ?? 0,
    );
  }
}
