import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/english_reading_models.dart';
import '../services/english_reading_ability.dart';
import '../widgets/english_reading_wpm_chart.dart';

/// 英語速読の「現在の実力」可視化ダッシュボード。
///
/// 推定レベル / 実効 WPM / 対ネイティブ達成率 / WPM 時系列 / レベル制覇マップを表示。
/// テストでは [initialSummary] を渡し [autoLoad] を false にすると Supabase 非依存。
class EnglishReadingDashboardPage extends StatefulWidget {
  const EnglishReadingDashboardPage({
    super.key,
    this.initialSummary,
    this.autoLoad = true,
  });

  final EnglishReadingAbilitySummary? initialSummary;
  final bool autoLoad;

  @override
  State<EnglishReadingDashboardPage> createState() =>
      _EnglishReadingDashboardPageState();
}

class _EnglishReadingDashboardPageState
    extends State<EnglishReadingDashboardPage> {
  bool _loading = true;
  String? _error;
  EnglishReadingAbilitySummary _summary = EnglishReadingAbilitySummary.empty();

  @override
  void initState() {
    super.initState();
    if (widget.initialSummary != null) {
      _summary = widget.initialSummary!;
      _loading = false;
    }
    if (widget.autoLoad) _fetch();
  }

  Future<void> _fetch() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'ai-hub',
        body: const {'action': 'english_reading.ability'},
      );
      final data = res.data;
      final list = data is Map && data['attempts'] is List
          ? data['attempts'] as List
          : const <dynamic>[];
      final attempts = list
          .whereType<Map>()
          .map(
            (e) => EnglishReadingAttempt.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
      if (!mounted) return;
      setState(
        () => _summary = EnglishReadingAbilitySummary.fromAttempts(attempts),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('英語速読 実力ダッシュボード'),
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
              ? _ErrorView(error: _error!, onRetry: _fetch)
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHero(context),
                      const SizedBox(height: 16),
                      _buildStatsGrid(),
                      const SizedBox(height: 20),
                      const Text(
                        'WPM の推移',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'オレンジ = 実効WPM (理解率込み) / 薄線 = 素のWPM',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFB0B0B0),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      EnglishReadingWpmChart(trend: _summary.trend),
                      const SizedBox(height: 20),
                      const Text(
                        'レベル制覇マップ',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '各レベルの目標WPMを理解率75%以上で達成すると制覇',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFB0B0B0),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildLevelMap(),
                      if (!_summary.hasData) ...[
                        const SizedBox(height: 20),
                        _buildEmptyCta(context),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final level = _summary.estimatedLevel;
    final nativePercent = (_summary.nativeRatio * 100).round();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0A1A3E)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: level.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: level.color.withValues(alpha: 0.32),
                  ),
                ),
                child: Text(
                  level.emoji,
                  style: const TextStyle(fontSize: 26, height: 1.2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '現在の推定レベル',
                      style: TextStyle(
                        color: Color(0xFFB0B0B0),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lv${level.level} ${level.labelJa}・${level.cefr}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_summary.latestEffectiveWpm}',
                    style: const TextStyle(
                      color: Color(0xFFFF8C5A),
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const Text(
                    '実効WPM',
                    style: TextStyle(
                      color: Color(0xFFB0B0B0),
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                '対ネイティブ (300 WPM)',
                style: TextStyle(
                  color: Color(0xFFD7DBE8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                '$nativePercent%',
                style: const TextStyle(
                  color: Color(0xFFFFC107),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _summary.nativeRatio,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFFF6B35),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _summary.reachedNative
                ? '🏆 ネイティブ速度に到達しています。複雑な長文で維持を狙いましょう。'
                : _summary.hasData
                    ? 'あと ${(kNativeReadingWpm - _summary.latestEffectiveWpm).clamp(0, kNativeReadingWpm)} WPM でネイティブ速度です。'
                    : 'まず計測モードを1回行うと、ここに実力が表示されます。',
            style: const TextStyle(
              color: Color(0xFFB0B0B0),
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final comprehensionPct = (_summary.averageComprehension * 100).round();
    final tiles = <Widget>[
      _StatTile(
        icon: Icons.bolt_outlined,
        label: '最新WPM',
        value: '${_summary.latestWpm}',
        accent: const Color(0xFF3D5AFE),
      ),
      _StatTile(
        icon: Icons.emoji_events_outlined,
        label: '最高WPM',
        value: '${_summary.bestWpm}',
        accent: const Color(0xFFFFD700),
      ),
      _StatTile(
        icon: Icons.fact_check_outlined,
        label: '平均理解率',
        value: '$comprehensionPct%',
        accent: const Color(0xFF4CAF50),
      ),
      _StatTile(
        icon: Icons.menu_book_outlined,
        label: '累計セッション',
        value: '${_summary.totalSessions}',
        accent: const Color(0xFFFF6B35),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }

  Widget _buildLevelMap() {
    return Column(
      children: [
        for (final level in kEnglishReadingLevels)
          _LevelRow(
            level: level,
            cleared: _summary.clearedLevels.contains(level.level),
            isCurrent: _summary.estimatedLevel.level == level.level,
          ),
      ],
    );
  }

  Widget _buildEmptyCta(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () => Navigator.of(
          context,
        ).pushReplacementNamed('/english-reading-curriculum'),
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('カリキュラムを始める'),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFB0B0B0),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.level,
    required this.cleared,
    required this.isCurrent,
  });

  final EnglishReadingLevel level;
  final bool cleared;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrent
            ? level.color.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent
              ? level.color.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        children: [
          Text(level.emoji, style: const TextStyle(fontSize: 20, height: 1.2)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lv${level.level} ${level.labelJa}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                Text(
                  '${level.cefr}・目標 ${level.targetWpm} WPM',
                  style: const TextStyle(
                    color: Color(0xFFB0B0B0),
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          if (cleared)
            const _Badge(
              label: '制覇',
              color: Color(0xFF4CAF50),
              icon: Icons.check_circle,
            )
          else if (isCurrent)
            const _Badge(
              label: '挑戦中',
              color: Color(0xFFFF6B35),
              icon: Icons.directions_run,
            )
          else
            Text(
              '未',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, required this.icon});

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.36)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
        ],
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'エラー: $error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFE53935), height: 1.5),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('再試行')),
        ],
      ),
    );
  }
}
