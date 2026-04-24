import 'dart:math' show max, min;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/ai_university_genre_catalog.dart';

/// AI大学ホームカード — ホーム最上部に表示するキラーコンテンツバナー
///
/// 機能:
/// - プロバイダー絵文字一覧 (DB登録数に関わらず既知分を表示)
/// - クイズ達成数 (SharedPreferences から取得)
/// - シェアボタン (share_plus)
/// - タップで /gemini-university へ遷移

class AiUniversityHomeCard extends StatefulWidget {
  const AiUniversityHomeCard({super.key});

  @override
  State<AiUniversityHomeCard> createState() => _AiUniversityHomeCardState();
}

class _AiUniversityHomeCardState extends State<AiUniversityHomeCard> {
  final _supabase = Supabase.instance.client;
  int _answeredCount = 0;
  int _currentStreak = 0;
  int _badgeCount = 0;
  int _providerCount = 0;
  int _dueCardCount = 0;
  DateTime? _latestContentUpdatedAt;
  static const String _prefsKey = 'ai_univ_answered_quizzes';

  static const List<String> _featuredProviders = [
    '🔵 Google',
    '⚫ OpenAI',
    '🟠 Anthropic',
    '⚡ xAI',
    '🐋 DeepSeek',
    '💨 Mistral',
  ];

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey) ?? '';
    final answered = saved.isEmpty ? <String>[] : saved.split(',');
    if (mounted) {
      setState(() => _answeredCount = answered.length);
    }

    try {
      final providerRows = await _supabase
          .from('ai_university_content')
          .select('provider, updated_at')
          .eq('is_active', true)
          .timeout(const Duration(seconds: 5));
      final providerMaps = (providerRows as List).cast<Map<String, dynamic>>();
      final providerCount = providerMaps
          .map((row) => row['provider'] as String?)
          .whereType<String>()
          .toSet()
          .length;
      DateTime? latestUpdatedAt;
      for (final row in providerMaps) {
        final raw = row['updated_at'];
        if (raw == null) continue;
        try {
          final parsed = DateTime.parse(raw.toString()).toLocal();
          if (latestUpdatedAt == null || parsed.isAfter(latestUpdatedAt)) {
            latestUpdatedAt = parsed;
          }
        } catch (_) {
          // updated_at のフォーマット異常は UI フォールバックに任せる
        }
      }
      if (mounted && providerCount > 0) {
        setState(() {
          _providerCount = providerCount;
          _latestContentUpdatedAt = latestUpdatedAt;
        });
      }
    } catch (_) {
      // 取得失敗はサイレント — 静的コピーで継続
    }

    // Supabase からクロスデバイス学習記録・ストリーク・バッジ数を取得
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final scoresRow = await _supabase
          .from('ai_university_scores')
          .select('provider_id')
          .eq('user_id', user.id)
          .eq('quiz_correct', true)
          .timeout(const Duration(seconds: 5));
      final remoteCount =
          ((scoresRow as List).cast<Map<String, dynamic>>()).length;
      final streakRow = await _supabase
          .from('ai_university_streaks')
          .select('current_streak')
          .eq('user_id', user.id)
          .maybeSingle();
      final badgeRow = await _supabase
          .from('ai_university_badges')
          .select('id')
          .eq('user_id', user.id)
          .count(CountOption.exact);
      final dueCardRow = await _supabase
          .from('ai_university_fsrs_cards')
          .select('id')
          .eq('user_id', user.id)
          .lte('due_date', DateTime.now().toIso8601String())
          .count(CountOption.exact);
      if (mounted) {
        setState(() {
          // リモート記録があればローカルより優先 (クロスデバイス対応)
          if (remoteCount > _answeredCount) _answeredCount = remoteCount;
          _currentStreak = (streakRow?['current_streak'] as num?)?.toInt() ?? 0;
          _badgeCount = badgeRow.count;
          _dueCardCount = dueCardRow.count;
        });
      }
    } catch (_) {
      // 取得失敗はサイレント — ローカルデータを維持
    }
  }

  Future<void> _share() async {
    final providerCountText = _providerCount > 0 ? '$_providerCount社' : '多数の';
    final learnedText =
        _answeredCount > 0 ? '$_answeredCount社学習済み' : '最初の1社に挑戦中';
    final streakText = _currentStreak > 0 ? ' / $_currentStreak日連続' : '';

    // A/B テスト: バリアント選択 (50/50)
    final variant = DateTime.now().millisecond % 2 == 0 ? 'a' : 'b';
    final shareText = variant == 'a'
        ? '🤖 自分株式会社の AI 大学で学習中！\n'
            '$providerCountTextのAIを1か所で横断しながら学べます。'
            '$learnedText$streakText\n'
            'https://my-web-app-b67f4.web.app/ai-university'
        : '🎓 最新AIの違いが3分でわかる！\n'
            'Google / OpenAI / Anthropic など $providerCountTextを '
            'クイズ+ニュースで横断学習。\n'
            '$learnedText$streakText\n'
            'https://my-web-app-b67f4.web.app/ai-university';

    // Web: OS native share sheet omits X on Windows/desktop → open X intent
    // directly. Native platforms keep the familiar SharePlus flow.
    if (kIsWeb) {
      final intent = Uri.parse(
        'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(shareText)}',
      );
      await launchUrl(intent, mode: LaunchMode.externalApplication);
      return;
    }
    await SharePlus.instance.share(
      ShareParams(text: shareText),
    );
  }

  void _openUniversity() {
    Navigator.of(context).pushNamed('/gemini-university');
  }

  void _openProvider(String providerId) {
    Navigator.of(context).pushNamed(
      '/gemini-university',
      arguments: {'provider': providerId},
    );
  }

  void _openRanking() {
    Navigator.of(context).pushNamed('/ai-university-ranking');
  }

  void _openVideoLesson() {
    Navigator.of(context).pushNamed('/ai-university-video');
  }

  String _buildRefreshLabel() {
    final updatedAt = _latestContentUpdatedAt;
    if (updatedAt == null) return '毎週更新';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(updatedAt.year, updatedAt.month, updatedAt.day);
    final diff = today.difference(target).inDays;
    if (diff <= 0) return '今日更新';
    if (diff == 1) return '昨日更新';
    if (diff < 7) return '$diff日前更新';
    return '${updatedAt.month}/${updatedAt.day} 更新';
  }

  Widget _buildStatusPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final providerCountText = _providerCount > 0 ? '$_providerCount社' : '多数の';
    final learnedTotalLabel = _providerCount > 0 ? '$_providerCount' : '—';
    final progress =
        _providerCount <= 0 ? 0.0 : min(1.0, _answeredCount / _providerCount);
    final progressPercent = (progress * 100).round();
    final extraProviders = _providerCount > _featuredProviders.length
        ? _providerCount - _featuredProviders.length
        : 0;
    final remainingProviders =
        _providerCount > 0 ? max(0, _providerCount - _answeredCount) : 0;
    final isReturningLearner =
        _answeredCount > 0 || _currentStreak > 0 || _badgeCount > 0;
    final headline =
        isReturningLearner ? '今日の1社で連続学習とランキングを伸ばす' : '最短3分で主要AIの違いをつかむ';
    final subcopy = isReturningLearner
        ? remainingProviders > 0
            ? '$_answeredCount社を学習済み。残り$remainingProviders社で制覇に近づきます。'
            : '全掲載AIを学習済み。最新ニュースを追いながらランキング上位を狙えます。'
        : '$providerCountTextのAIを、ニュースとクイズで横断学習。まずは気になる1社から始めましょう。';
    final primaryCta = isReturningLearner ? '続きから学ぶ' : '最初の1社を始める';
    final goalLabel = isReturningLearner ? '次の目標' : '最初の目標';
    final goalValue = isReturningLearner
        ? remainingProviders > 0
            ? '次はあと$remainingProviders社。1問解いてストリークをつなぐ'
            : 'ランキングを見て、最新AIの復習を1社ぶん進める'
        : 'Google / OpenAI / Anthropic など主要AIの違いを1社ずつ体感する';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;
        final metricWidth = isCompact
            ? (constraints.maxWidth - 8) / 2
            : (constraints.maxWidth - 24) / 4;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _openUniversity,
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1A1A2E),
                    Color(0xFF16213E),
                    Color(0xFF0A1A3E),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: const Color(0xFF3D5AFE).withValues(alpha: 0.12),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
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
                          color:
                              const Color(0xFFFF6B35).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                const Color(0xFFFF6B35).withValues(alpha: 0.28),
                          ),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: Color(0xFFFF8C5A),
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
                              children: [
                                const Text(
                                  'AI 大学',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.96,
                                    height: 1.4,
                                  ),
                                ),
                                _buildStatusPill(
                                  icon: Icons.auto_awesome,
                                  label: _buildRefreshLabel(),
                                  color: const Color(0xFFFFC107),
                                ),
                                if (_dueCardCount > 0)
                                  _buildStatusPill(
                                    icon: Icons.replay_rounded,
                                    label: '復習 $_dueCardCount問',
                                    color: const Color(0xFF3D5AFE),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              headline,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.72,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subcopy,
                              style: const TextStyle(
                                color: Color(0xFFB0B0B0),
                                fontSize: 13,
                                height: 1.7,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isCompact)
                        IconButton(
                          icon: Icon(
                            Icons.share,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          tooltip: '共有',
                          onPressed: _share,
                        ),
                    ],
                  ),
                  if (isCompact)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: Icon(
                            Icons.share,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          tooltip: '共有',
                          onPressed: _share,
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final provider in _featuredProviders)
                        _buildProviderChip(provider),
                      if (extraProviders > 0)
                        _buildProviderChip('+$extraProviders'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kLegalAiGenre.accentColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: kLegalAiGenre.accentColor.withValues(
                          alpha: 0.34,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                '新ジャンル',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            Text(
                              kLegalAiGenre.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          kLegalAiGenre.headline,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          kLegalAiGenre.description,
                          style: const TextStyle(
                            color: Color(0xFFD7DBE8),
                            fontSize: 12,
                            height: 1.7,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final area in kLegalAiGenre.focusAreas)
                              _buildProviderChip(area),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () =>
                                _openProvider(kLegalAiGenre.launchProviderId),
                            icon: const Icon(
                              Icons.gavel_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            label: const Text(
                              '法律AIから学ぶ',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: metricWidth,
                        child: _buildMetricTile(
                          icon: Icons.hub_outlined,
                          label: '掲載AI',
                          value: providerCountText,
                          accent: const Color(0xFF3D5AFE),
                        ),
                      ),
                      SizedBox(
                        width: metricWidth,
                        child: _buildMetricTile(
                          icon: Icons.check_circle_outline,
                          label: '学習済み',
                          value: '$_answeredCount社',
                          accent: const Color(0xFF4CAF50),
                        ),
                      ),
                      SizedBox(
                        width: metricWidth,
                        child: _buildMetricTile(
                          icon: Icons.local_fire_department_outlined,
                          label: '連続学習',
                          value: '$_currentStreak日',
                          accent: const Color(0xFFFF6B35),
                        ),
                      ),
                      SizedBox(
                        width: metricWidth,
                        child: _buildMetricTile(
                          icon: Icons.workspace_premium_outlined,
                          label: 'バッジ',
                          value: '$_badgeCount個',
                          accent: const Color(0xFFFFD700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
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
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    goalLabel,
                                    style: const TextStyle(
                                      color: Color(0xFFB0B0B0),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    goalValue,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      height: 1.7,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '$progressPercent%',
                              style: const TextStyle(
                                color: Color(0xFFFFC107),
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '学習済み: $_answeredCount / $learnedTotalLabel 社',
                          style: const TextStyle(
                            color: Color(0xFFB0B0B0),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white.withValues(alpha: 0.14),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFFFC107),
                          ),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isCompact) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _openUniversity,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(primaryCta),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    if (_dueCardCount > 0) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _openUniversity,
                          icon: const Icon(Icons.replay_rounded),
                          label: Text('復習する ($_dueCardCount問)'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF3D5AFE),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openRanking,
                        icon: const Icon(Icons.leaderboard_outlined),
                        label: const Text('ランキングを見る'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.24),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openVideoLesson,
                        icon: const Icon(Icons.videocam_outlined),
                        label: const Text('動画で学ぶ'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF90CAF9),
                          side: const BorderSide(color: Color(0x3390CAF9)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ] else
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: _openUniversity,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(primaryCta),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B35),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _openRanking,
                          icon: const Icon(Icons.leaderboard_outlined),
                          label: const Text('ランキングを見る'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.24),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _openVideoLesson,
                          icon: const Icon(
                            Icons.videocam_outlined,
                            size: 16,
                            color: Color(0xFF90CAF9),
                          ),
                          label: const Text(
                            '動画で学ぶ',
                            style: TextStyle(
                              color: Color(0xFF90CAF9),
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            '/ai-university-voice',
                          ),
                          icon: const Icon(
                            Icons.mic,
                            size: 16,
                            color: Color(0xFF3D5AFE),
                          ),
                          label: const Text(
                            '音声で学ぶ',
                            style: TextStyle(
                              color: Color(0xFF3D5AFE),
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
