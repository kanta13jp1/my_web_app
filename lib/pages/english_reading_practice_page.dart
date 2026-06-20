import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/english_reading_models.dart';
import '../services/english_reading_ability.dart';

enum _Phase { intro, reading, quiz, result }

/// 速読の練習画面。計測モード (自己ペース読了 → 内容理解クイズ → WPM/理解率/実効WPM) と
/// RSVP モード (設定WPMで単語を1語ずつ高速提示) の両方を1画面で扱う。
///
/// テストでは [lesson] を直接渡し [autoLoad]=false / [submitToServer]=false にすると
/// Supabase 非依存でレンダリングできる。
class EnglishReadingPracticePage extends StatefulWidget {
  const EnglishReadingPracticePage({
    super.key,
    this.lesson,
    this.lessonCode,
    this.mode = 'measure',
    this.autoLoad = true,
    this.submitToServer = true,
  });

  final EnglishReadingLesson? lesson;
  final String? lessonCode;

  /// 'measure' | 'rsvp'
  final String mode;
  final bool autoLoad;
  final bool submitToServer;

  @override
  State<EnglishReadingPracticePage> createState() =>
      _EnglishReadingPracticePageState();
}

class _EnglishReadingPracticePageState
    extends State<EnglishReadingPracticePage> {
  EnglishReadingLesson? _lesson;
  bool _loading = true;
  String? _error;

  _Phase _phase = _Phase.intro;
  late String _mode;

  // 計測モード
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  // RSVP モード
  List<String> _rsvpWords = const [];
  int _rsvpIndex = 0;
  double _rsvpWpm = 200;
  Timer? _rsvpTimer;
  bool _rsvpPaused = false;

  // クイズ
  List<int?> _answers = const [];
  bool _graded = false;

  // 結果
  int _resultWpm = 0;
  int _resultEffectiveWpm = 0;
  int _resultCorrect = 0;
  int _resultTotal = 0;
  int _resultElapsedMs = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode == 'rsvp' ? 'rsvp' : 'measure';
    if (widget.lesson != null) {
      _lesson = widget.lesson;
      _loading = false;
      _initForLesson();
    }
    if (widget.lesson == null && widget.autoLoad) {
      _loadLesson();
    } else if (widget.lesson == null) {
      _loading = false;
    }
  }

  void _initForLesson() {
    final lesson = _lesson;
    if (lesson == null) return;
    _rsvpWords = lesson.passage
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    _rsvpWpm = lesson.targetWpm.clamp(100, 500).toDouble();
    _answers = List<int?>.filled(lesson.questions.length, null);
  }

  Future<void> _loadLesson() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = <String, dynamic>{};
      if (widget.lessonCode != null && widget.lessonCode!.isNotEmpty) {
        body['action'] = 'english_reading.get_lesson';
        body['lesson_code'] = widget.lessonCode;
      } else {
        body['action'] = 'english_reading.list_lessons';
        body['level'] = 1;
      }
      final res = await Supabase.instance.client.functions.invoke(
        'ai-hub',
        body: body,
      );
      final data = res.data;
      EnglishReadingLesson? lesson;
      if (data is Map && data['lesson'] is Map) {
        lesson = EnglishReadingLesson.fromJson(
          Map<String, dynamic>.from(data['lesson'] as Map),
        );
      } else if (data is Map && data['lessons'] is List) {
        final list = data['lessons'] as List;
        final first = list.whereType<Map>().cast<Map>().toList();
        if (first.isNotEmpty) {
          lesson = EnglishReadingLesson.fromJson(
            Map<String, dynamic>.from(first.first),
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _lesson = lesson;
        if (lesson == null) _error = '教材が見つかりませんでした。';
      });
      _initForLesson();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _rsvpTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  // ---------- 計測モード ----------

  void _startMeasure() {
    _stopwatch
      ..reset()
      ..start();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() => _elapsed = _stopwatch.elapsed);
    });
    setState(() => _phase = _Phase.reading);
  }

  void _finishMeasure() {
    _stopwatch.stop();
    _ticker?.cancel();
    _resultElapsedMs = _stopwatch.elapsedMilliseconds;
    _goToQuizOrResult();
  }

  // ---------- RSVP モード ----------

  void _startRsvp() {
    _rsvpIndex = 0;
    _rsvpPaused = false;
    setState(() => _phase = _Phase.reading);
    _scheduleRsvpTick();
  }

  void _scheduleRsvpTick() {
    _rsvpTimer?.cancel();
    final intervalMs = (60000 / _rsvpWpm).round().clamp(40, 2000);
    _rsvpTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (!mounted) return;
      if (_rsvpPaused) return;
      // 最終語に到達したら setState の外で完了処理 (nested setState 回避)。
      if (_rsvpIndex >= _rsvpWords.length - 1) {
        _finishRsvp();
      } else {
        setState(() => _rsvpIndex++);
      }
    });
  }

  void _toggleRsvpPause() {
    setState(() => _rsvpPaused = !_rsvpPaused);
  }

  void _finishRsvp() {
    _rsvpTimer?.cancel();
    final words = _rsvpWords.length;
    _resultElapsedMs = _rsvpWpm > 0 ? ((words / _rsvpWpm) * 60000).round() : 0;
    _goToQuizOrResult();
  }

  // ---------- 共通遷移 ----------

  void _goToQuizOrResult() {
    final lesson = _lesson;
    if (lesson != null && lesson.questions.isNotEmpty) {
      setState(() {
        _graded = false;
        _phase = _Phase.quiz;
      });
    } else {
      _computeResult();
    }
  }

  void _gradeQuiz() {
    final lesson = _lesson;
    if (lesson == null) return;
    var correct = 0;
    for (var i = 0; i < lesson.questions.length; i++) {
      if (_answers[i] == lesson.questions[i].answerIndex) correct++;
    }
    _resultCorrect = correct;
    _resultTotal = lesson.questions.length;
    setState(() => _graded = true);
  }

  void _computeResult() {
    final lesson = _lesson;
    if (lesson == null) return;
    final wordCount = lesson.wordCount;
    final wpm = EnglishReadingMetrics.wpm(
      wordCount: wordCount,
      elapsedMs: _resultElapsedMs,
    );
    final effective = EnglishReadingMetrics.effectiveWpm(
      wpm: wpm,
      comprehensionCorrect: _resultCorrect,
      comprehensionTotal: _resultTotal,
    );
    setState(() {
      _resultWpm = wpm;
      _resultEffectiveWpm = effective;
      _phase = _Phase.result;
    });
    if (widget.submitToServer) {
      unawaited(_submit());
    }
  }

  Future<void> _submit() async {
    final lesson = _lesson;
    if (lesson == null) return;
    if (Supabase.instance.client.auth.currentUser == null) return;
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.functions.invoke(
        'ai-hub',
        body: {
          'action': 'english_reading.submit_attempt',
          'lesson_code': lesson.lessonCode,
          if (lesson.id.isNotEmpty) 'lesson_id': lesson.id,
          'level': lesson.level,
          'mode': _mode,
          'word_count': lesson.wordCount,
          'elapsed_ms': _resultElapsedMs,
          'comprehension_correct': _resultCorrect,
          'comprehension_total': _resultTotal,
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('記録の保存に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _restart() {
    _ticker?.cancel();
    _rsvpTimer?.cancel();
    _stopwatch
      ..stop()
      ..reset();
    setState(() {
      _elapsed = Duration.zero;
      _rsvpIndex = 0;
      _rsvpPaused = false;
      _graded = false;
      _resultWpm = 0;
      _resultEffectiveWpm = 0;
      _resultCorrect = 0;
      _resultTotal = 0;
      _resultElapsedMs = 0;
      final lesson = _lesson;
      _answers = List<int?>.filled(lesson?.questions.length ?? 0, null);
      _phase = _Phase.intro;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lesson = _lesson;
    return Scaffold(
      appBar: AppBar(title: Text(_mode == 'rsvp' ? 'RSVP 速読トレーナー' : '速読 計測')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : lesson == null
              ? _buildLoadError()
              : SafeArea(child: _buildPhase(lesson)),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _error ?? '教材を読み込めませんでした。',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFE53935), height: 1.5),
          ),
          const SizedBox(height: 16),
          if (widget.autoLoad)
            ElevatedButton(onPressed: _loadLesson, child: const Text('再試行')),
        ],
      ),
    );
  }

  Widget _buildPhase(EnglishReadingLesson lesson) {
    switch (_phase) {
      case _Phase.intro:
        return _buildIntro(lesson);
      case _Phase.reading:
        return _mode == 'rsvp'
            ? _buildRsvpReading(lesson)
            : _buildMeasureReading(lesson);
      case _Phase.quiz:
        return _buildQuiz(lesson);
      case _Phase.result:
        return _buildResult(lesson);
    }
  }

  // ---------- intro ----------

  Widget _buildIntro(EnglishReadingLesson lesson) {
    final isRsvp = _mode == 'rsvp';
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _LessonHeader(lesson: lesson, mode: _mode),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Text(
            isRsvp
                ? '単語が1語ずつ表示されます。読み終えたら内容理解クイズに進みます。'
                    '速度はスライダーで設定できます。'
                : '「開始」を押すと時間の計測が始まります。自分のペースで読み、'
                    '読み終えたら「読み終えた」を押してください。その後クイズに進みます。',
            style: const TextStyle(
              color: Color(0xFFB0B0B0),
              fontSize: 13,
              height: 1.7,
            ),
          ),
        ),
        if (isRsvp) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              const Text(
                '提示速度',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              Text(
                '${_rsvpWpm.round()} WPM',
                style: const TextStyle(
                  color: Color(0xFFFF8C5A),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
            ],
          ),
          Slider(
            value: _rsvpWpm,
            min: 100,
            max: 500,
            divisions: 40,
            label: '${_rsvpWpm.round()} WPM',
            activeColor: const Color(0xFFFF6B35),
            onChanged: (v) => setState(() => _rsvpWpm = v),
          ),
          Text(
            'ネイティブの目安は 250〜300 WPM。目標レベルは ${lesson.targetWpm} WPM です。',
            style: const TextStyle(
              color: Color(0xFFB0B0B0),
              fontSize: 11,
              height: 1.6,
            ),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isRsvp ? _startRsvp : _startMeasure,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(isRsvp ? 'RSVP を開始' : '計測を開始'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- measure reading ----------

  Widget _buildMeasureReading(EnglishReadingLesson lesson) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFF1A1A2E),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer, size: 18, color: Color(0xFFFF8C5A)),
              const SizedBox(width: 8),
              Text(
                _formatElapsed(_elapsed),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                  height: 1.4,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '約${lesson.wordCount}語',
                style: const TextStyle(
                  color: Color(0xFFB0B0B0),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Text(
              lesson.passage,
              style: const TextStyle(
                fontSize: 18,
                height: 1.9,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _finishMeasure,
              icon: const Icon(Icons.check_rounded),
              label: const Text('読み終えた'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3D5AFE),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- rsvp reading ----------

  Widget _buildRsvpReading(EnglishReadingLesson lesson) {
    final total = _rsvpWords.length;
    final current =
        total == 0 ? '' : _rsvpWords[_rsvpIndex.clamp(0, total - 1)];
    final progress = total == 0 ? 0.0 : (_rsvpIndex + 1) / total;
    return Column(
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFFF6B35),
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                current,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ),
        Text(
          '${_rsvpIndex + 1} / $total 語・${_rsvpWpm.round()} WPM',
          style: const TextStyle(
            color: Color(0xFFB0B0B0),
            fontSize: 12,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _toggleRsvpPause,
                  icon: Icon(
                    _rsvpPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    size: 18,
                  ),
                  label: Text(_rsvpPaused ? '再開' : '一時停止'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _finishRsvp,
                  icon: const Icon(Icons.skip_next_rounded, size: 18),
                  label: const Text('クイズへ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3D5AFE),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- quiz ----------

  Widget _buildQuiz(EnglishReadingLesson lesson) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          '内容理解クイズ',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '本文を見ずに答えてください。',
          style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < lesson.questions.length; i++)
          _QuestionCard(
            index: i,
            question: lesson.questions[i],
            selected: _answers[i],
            graded: _graded,
            onSelect: _graded
                ? null
                : (choice) => setState(() => _answers[i] = choice),
          ),
        const SizedBox(height: 8),
        if (!_graded)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _answers.contains(null) ? null : _gradeQuiz,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('採点する'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _computeResult,
              icon: const Icon(Icons.insights_outlined),
              label: const Text('結果を見る'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
      ],
    );
  }

  // ---------- result ----------

  Widget _buildResult(EnglishReadingLesson lesson) {
    final target = lesson.targetWpm;
    final comprehensionPct = _resultTotal == 0
        ? null
        : ((_resultCorrect / _resultTotal) * 100).round();
    final clearedSpeed = _resultWpm >= target;
    final clearedComp = comprehensionPct == null || comprehensionPct >= 75;
    final mastered = clearedSpeed && clearedComp && _resultTotal > 0;

    final feedback = mastered
        ? '🎉 速度・理解ともに目標達成！このレベルを制覇しました。'
        : !clearedComp
            ? '理解率が目標(75%)に届きませんでした。少しペースを落として正確さを優先しましょう。'
            : !clearedSpeed
                ? '理解は十分。次は RSVP で速度を $target WPM 以上へ引き上げましょう。'
                : '記録しました。継続して実効WPMを伸ばしましょう。';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
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
            children: [
              const Text(
                '実効 WPM',
                style: TextStyle(
                  color: Color(0xFFB0B0B0),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              Text(
                '$_resultEffectiveWpm',
                style: const TextStyle(
                  color: Color(0xFFFF8C5A),
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _mode == 'rsvp'
                    ? 'RSVP ${_rsvpWpm.round()} WPM で読了'
                    : '素の速度 $_resultWpm WPM',
                style: const TextStyle(
                  color: Color(0xFFB0B0B0),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ResultStat(
                label: '読書速度',
                value: '$_resultWpm',
                unit: 'WPM',
                accent: const Color(0xFF3D5AFE),
                ok: clearedSpeed,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ResultStat(
                label: '理解率',
                value: comprehensionPct == null ? '—' : '$comprehensionPct',
                unit: comprehensionPct == null ? '' : '%',
                accent: const Color(0xFF4CAF50),
                ok: clearedComp && _resultTotal > 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '目標 $target WPM / 理解率 75%',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFB0B0B0),
            fontSize: 11,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.28),
            ),
          ),
          child: Text(
            feedback,
            style: const TextStyle(
              fontSize: 13,
              height: 1.7,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (_saving) ...[
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text(
                '記録を保存中…',
                style: TextStyle(
                  color: Color(0xFFB0B0B0),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _restart,
                icon: const Icon(Icons.replay, size: 18),
                label: const Text('もう一度'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(
                  context,
                ).pushReplacementNamed('/english-reading-dashboard'),
                icon: const Icon(Icons.insights_outlined, size: 18),
                label: const Text('実力を見る'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('カリキュラムに戻る'),
          ),
        ),
      ],
    );
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _LessonHeader extends StatelessWidget {
  const _LessonHeader({required this.lesson, required this.mode});

  final EnglishReadingLesson lesson;
  final String mode;

  @override
  Widget build(BuildContext context) {
    final levelMeta = englishReadingLevelOf(lesson.level);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Chip(
              label: 'Lv${lesson.level} ${levelMeta.labelJa}',
              color: levelMeta.color,
            ),
            _Chip(label: lesson.cefr, color: const Color(0xFF3D5AFE)),
            _Chip(
              label: '目標 ${lesson.targetWpm} WPM',
              color: const Color(0xFFFF6B35),
            ),
            if (lesson.isAiGenerated)
              const _Chip(label: 'AI生成', color: Color(0xFFFFD54F)),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          lesson.title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.4,
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.question,
    required this.selected,
    required this.graded,
    required this.onSelect,
  });

  final int index;
  final EnglishReadingQuestion question;
  final int? selected;
  final bool graded;
  final void Function(int)? onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Q${index + 1}. ${question.question}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < question.choices.length; i++)
            _ChoiceTile(
              text: question.choices[i],
              isSelected: selected == i,
              isCorrect: graded && i == question.answerIndex,
              isWrongSelected:
                  graded && selected == i && i != question.answerIndex,
              onTap: onSelect == null ? null : () => onSelect!(i),
            ),
          if (graded && question.explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '解説: ${question.explanation}',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: Color(0xFFD7DBE8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.text,
    required this.isSelected,
    required this.isCorrect,
    required this.isWrongSelected,
    required this.onTap,
  });

  final String text;
  final bool isSelected;
  final bool isCorrect;
  final bool isWrongSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Color border = Colors.white.withValues(alpha: 0.12);
    Color bg = Colors.white.withValues(alpha: 0.03);
    IconData? icon;
    Color iconColor = Colors.white;
    if (isCorrect) {
      border = const Color(0xFF4CAF50);
      bg = const Color(0xFF4CAF50).withValues(alpha: 0.12);
      icon = Icons.check_circle;
      iconColor = const Color(0xFF4CAF50);
    } else if (isWrongSelected) {
      border = const Color(0xFFE53935);
      bg = const Color(0xFFE53935).withValues(alpha: 0.12);
      icon = Icons.cancel;
      iconColor = const Color(0xFFE53935);
    } else if (isSelected) {
      border = const Color(0xFF3D5AFE);
      bg = const Color(0xFF3D5AFE).withValues(alpha: 0.12);
      icon = Icons.radio_button_checked;
      iconColor = const Color(0xFF3D5AFE);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Icon(
                icon ?? Icons.radio_button_unchecked,
                size: 18,
                color: icon == null
                    ? Colors.white.withValues(alpha: 0.4)
                    : iconColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
    required this.ok,
  });

  final String label;
  final String value;
  final String unit;
  final Color accent;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ok
              ? accent.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFB0B0B0),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              if (ok) ...[
                const SizedBox(width: 4),
                Icon(Icons.check_circle, size: 14, color: accent),
              ],
            ],
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: accent,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    color: Color(0xFFB0B0B0),
                    fontSize: 12,
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
}
