import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/english_reading_models.dart';
import '../services/english_reading_ability.dart';
import 'english_reading_practice_page.dart';

/// 英語速読カリキュラムのハブ (シラバス)。
///
/// CEFR×目標WPM の 6 レベル階梯を表示し、各レベルの教材を「計測 / RSVP」で開始できる。
/// 上部に現在の実力サマリ (推定レベル・実効WPM・対ネイティブ達成率) を表示する。
/// テストでは [initialLessons] / [initialSummary] を渡し [autoLoad]=false で Supabase 非依存。
class EnglishReadingCurriculumPage extends StatefulWidget {
  const EnglishReadingCurriculumPage({
    super.key,
    this.initialLessons,
    this.initialSummary,
    this.autoLoad = true,
  });

  final List<EnglishReadingLesson>? initialLessons;
  final EnglishReadingAbilitySummary? initialSummary;
  final bool autoLoad;

  @override
  State<EnglishReadingCurriculumPage> createState() =>
      _EnglishReadingCurriculumPageState();
}

class _EnglishReadingCurriculumPageState
    extends State<EnglishReadingCurriculumPage> {
  bool _loading = true;
  String? _error;
  List<EnglishReadingLesson> _lessons = const [];
  EnglishReadingAbilitySummary _summary = EnglishReadingAbilitySummary.empty();
  int? _generatingLevel;

  @override
  void initState() {
    super.initState();
    if (widget.initialLessons != null) {
      _lessons = widget.initialLessons!;
      _loading = false;
    }
    if (widget.initialSummary != null) {
      _summary = widget.initialSummary!;
      _loading = false;
    }
    if (widget.autoLoad) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final client = Supabase.instance.client;
    try {
      final res = await client.functions.invoke(
        'ai-hub',
        body: const {'action': 'english_reading.list_lessons'},
      );
      final data = res.data;
      final list = data is Map && data['lessons'] is List
          ? data['lessons'] as List
          : const <dynamic>[];
      final lessons = list
          .whereType<Map>()
          .map(
            (e) => EnglishReadingLesson.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
      if (mounted) setState(() => _lessons = lessons);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    await _refreshAbility();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refreshAbility() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) return;
    try {
      final res = await client.functions.invoke(
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
      if (mounted) {
        setState(
          () => _summary = EnglishReadingAbilitySummary.fromAttempts(attempts),
        );
      }
    } catch (_) {
      // 未ログイン等は無視 (サマリは空のまま)
    }
  }

  Map<int, List<EnglishReadingLesson>> get _lessonsByLevel {
    final map = <int, List<EnglishReadingLesson>>{};
    for (final lesson in _lessons) {
      map.putIfAbsent(lesson.level, () => []).add(lesson);
    }
    return map;
  }

  Future<void> _openPractice(EnglishReadingLesson lesson, String mode) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EnglishReadingPracticePage(lesson: lesson, mode: mode),
      ),
    );
    await _refreshAbility();
  }

  Future<void> _generateLesson(int level) async {
    if (_generatingLevel != null) return;
    if (Supabase.instance.client.auth.currentUser == null) {
      _snack('AI教材の生成にはログインが必要です。');
      return;
    }
    setState(() => _generatingLevel = level);
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'ai-hub',
        body: {'action': 'english_reading.generate_lesson', 'level': level},
      );
      final data = res.data;
      final lessonJson = data is Map && data['lesson'] is Map
          ? Map<String, dynamic>.from(data['lesson'] as Map)
          : null;
      if (lessonJson == null) {
        _snack('AI教材の生成に失敗しました。時間をおいて再試行してください。');
        return;
      }
      final lesson = EnglishReadingLesson.fromJson(lessonJson);
      if (!mounted) return;
      setState(() => _lessons = [..._lessons, lesson]);
      await _openPractice(lesson, 'measure');
    } catch (e) {
      _snack('AI教材の生成に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _generatingLevel = null);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final byLevel = _lessonsByLevel;
    return Scaffold(
      appBar: AppBar(
        title: const Text('📖 英語速読カリキュラム'),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: '実力ダッシュボード',
            onPressed: () =>
                Navigator.of(context).pushNamed('/english-reading-dashboard'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _CompactAbilityCard(
                    summary: _summary,
                    onOpenDashboard: () => Navigator.of(
                      context,
                    ).pushNamed('/english-reading-dashboard'),
                  ),
                  const SizedBox(height: 16),
                  const _HowItWorksCard(),
                  const SizedBox(height: 20),
                  if (_error != null && _lessons.isEmpty)
                    _InlineError(error: _error!, onRetry: _load),
                  for (final level in kEnglishReadingLevels)
                    _LevelSection(
                      level: level,
                      lessons: byLevel[level.level] ?? const [],
                      cleared: _summary.clearedLevels.contains(level.level),
                      isCurrent: _summary.estimatedLevel.level == level.level,
                      generating: _generatingLevel == level.level,
                      generateDisabled: _generatingLevel != null,
                      onMeasure: (lesson) => _openPractice(lesson, 'measure'),
                      onRsvp: (lesson) => _openPractice(lesson, 'rsvp'),
                      onGenerate: () => _generateLesson(level.level),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

class _CompactAbilityCard extends StatelessWidget {
  const _CompactAbilityCard({
    required this.summary,
    required this.onOpenDashboard,
  });

  final EnglishReadingAbilitySummary summary;
  final VoidCallback onOpenDashboard;

  @override
  Widget build(BuildContext context) {
    final level = summary.estimatedLevel;
    final nativePercent = (summary.nativeRatio * 100).round();
    return GestureDetector(
      onTap: onOpenDashboard,
      child: Container(
        padding: const EdgeInsets.all(16),
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
                Text(level.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.hasData
                            ? '現在 Lv${level.level} ${level.labelJa}・${level.cefr}'
                            : 'まずは計測から始めましょう',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
                      ),
                      Text(
                        summary.hasData
                            ? '実効 ${summary.latestEffectiveWpm} WPM / 対ネイティブ $nativePercent%'
                            : 'あなたの読書速度と理解率を測定します',
                        style: const TextStyle(
                          color: Color(0xFFB0B0B0),
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFFB0B0B0)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: summary.nativeRatio,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFFF6B35),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '2つのモードで鍛える',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          SizedBox(height: 8),
          _ModeLine(
            icon: Icons.timer_outlined,
            color: Color(0xFF3D5AFE),
            title: '計測モード',
            desc: '自分のペースで読み、内容理解クイズで WPM と理解率を測定します。',
          ),
          SizedBox(height: 6),
          _ModeLine(
            icon: Icons.flash_on_outlined,
            color: Color(0xFFFF6B35),
            title: 'RSVPトレーナー',
            desc: '設定した速度で単語を1語ずつ高速提示。ネイティブ速度を体に覚えさせます。',
          ),
        ],
      ),
    );
  }
}

class _ModeLine extends StatelessWidget {
  const _ModeLine({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                color: Color(0xFFB0B0B0),
                fontSize: 12,
                height: 1.6,
              ),
              children: [
                TextSpan(
                  text: '$title — ',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LevelSection extends StatelessWidget {
  const _LevelSection({
    required this.level,
    required this.lessons,
    required this.cleared,
    required this.isCurrent,
    required this.generating,
    required this.generateDisabled,
    required this.onMeasure,
    required this.onRsvp,
    required this.onGenerate,
  });

  final EnglishReadingLevel level;
  final List<EnglishReadingLesson> lessons;
  final bool cleared;
  final bool isCurrent;
  final bool generating;
  final bool generateDisabled;
  final void Function(EnglishReadingLesson) onMeasure;
  final void Function(EnglishReadingLesson) onRsvp;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrent
            ? level.color.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent
              ? level.color.withValues(alpha: 0.36)
              : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(level.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lv${level.level} ${level.labelJa}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
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
                const Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
            ],
          ),
          const SizedBox(height: 12),
          if (lessons.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'このレベルの教材はまだありません。AIで生成できます。',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            )
          else
            for (final lesson in lessons)
              _LessonTile(
                lesson: lesson,
                onMeasure: () => onMeasure(lesson),
                onRsvp: () => onRsvp(lesson),
              ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: generateDisabled ? null : onGenerate,
              icon: generating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, size: 16),
              label: Text(generating ? 'AI生成中…' : 'AIで新しい教材を生成'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.onMeasure,
    required this.onRsvp,
  });

  final EnglishReadingLesson lesson;
  final VoidCallback onMeasure;
  final VoidCallback onRsvp;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  lesson.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              if (lesson.isAiGenerated)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: Color(0xFFFFD54F),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '約${lesson.wordCount}語 / ${lesson.questions.length}問'
            '${lesson.topic.isNotEmpty ? ' / ${lesson.topic}' : ''}',
            style: const TextStyle(
              color: Color(0xFFB0B0B0),
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onMeasure,
                  icon: const Icon(Icons.timer_outlined, size: 16),
                  label: const Text('計測'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF3D5AFE),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRsvp,
                  icon: const Icon(Icons.flash_on_outlined, size: 16),
                  label: const Text('RSVP'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6B35),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE53935).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '教材の読み込みに失敗しました: $error',
              style: const TextStyle(
                color: Color(0xFFE53935),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('再試行')),
        ],
      ),
    );
  }
}
