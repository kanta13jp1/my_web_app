// IQトレーニングのドリル実施ページ。
//
// テストと違い、1問ごとに正誤と解説を即時に返す。
// 学習が目的なので「測る」より「気づかせる」ことを優先する。

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/iq_training_drills.dart';
import '../models/iq_test.dart';
import '../services/iq_training_service.dart';
import '../theme/design_tokens.dart';

class IqTrainingDrillPage extends StatefulWidget {
  final int planId;
  final IqCategory category;
  final int level;

  /// テスト用に問題生成を固定したい場合に渡す。
  final int? seed;

  const IqTrainingDrillPage({
    super.key,
    required this.planId,
    required this.category,
    required this.level,
    this.seed,
  });

  @override
  State<IqTrainingDrillPage> createState() => _IqTrainingDrillPageState();
}

class _IqTrainingDrillPageState extends State<IqTrainingDrillPage>
    with WidgetsBindingObserver {
  final IqTrainingService _service = IqTrainingService();

  late final List<IqQuestion> _questions;
  late final DateTime _startedAt;

  int _index = 0;
  int _correctCount = 0;

  /// 現在の問題で選んだ選択肢。null なら未回答。
  int? _selectedIndex;
  bool _isFinished = false;
  bool _isSaving = false;

  bool _isRevealing = false;
  int _revealRemaining = 0;
  Timer? _revealTimer;

  @override
  void initState() {
    super.initState();
    _questions = IqDrillGenerator.generate(
      category: widget.category,
      level: widget.level,
      seed: widget.seed ?? math.Random().nextInt(1 << 31),
    );
    _startedAt = DateTime.now();
    WidgetsBinding.instance.addObserver(this);
    _prepareQuestion();
  }

  /// 背面では刺激の提示カウントを止める (テスト側と同じ理由)。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!_isRevealing) return;
    if (state == AppLifecycleState.resumed) {
      _resumeRevealCountdown();
    } else {
      _revealTimer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _revealTimer?.cancel();
    super.dispose();
  }

  IqQuestion get _current => _questions[_index];
  bool get _hasAnswered => _selectedIndex != null;

  void _prepareQuestion() {
    _revealTimer?.cancel();

    if (!_current.hasMemoryPhase) {
      if (mounted) setState(() => _isRevealing = false);
      return;
    }

    setState(() {
      _isRevealing = true;
      _revealRemaining = _current.revealSeconds!;
    });

    _resumeRevealCountdown();
  }

  /// 残り時間からカウントダウンを（再）開始する。
  void _resumeRevealCountdown() {
    _revealTimer?.cancel();
    _revealTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _revealRemaining--);
      if (_revealRemaining <= 0) {
        timer.cancel();
        setState(() => _isRevealing = false);
      }
    });
  }

  void _answer(int index) {
    if (_hasAnswered || _isRevealing) return;
    setState(() {
      _selectedIndex = index;
      if (_current.isCorrect(index)) _correctCount++;
    });
  }

  void _next() {
    if (_index < _questions.length - 1) {
      setState(() {
        _index++;
        _selectedIndex = null;
      });
      _prepareQuestion();
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      await _service.recordSession(
        planId: widget.planId,
        category: widget.category,
        level: widget.level,
        correctCount: _correctCount,
        questionCount: _questions.length,
        durationSeconds: DateTime.now().difference(_startedAt).inSeconds,
      );
      if (!mounted) return;
      setState(() {
        _isFinished = true;
        _isSaving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('記録の保存に失敗しました: $e'),
          backgroundColor: DesignTokens.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.background,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface1,
        elevation: 0,
        title: Text(
          '${widget.category.labelJa}・レベル${widget.level}',
          style: const TextStyle(
            color: DesignTokens.textPrimary,
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: DesignTokens.textSecondary),
        bottom: _isFinished
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: (_index + 1) / _questions.length,
                  backgroundColor: DesignTokens.surface3,
                  valueColor: const AlwaysStoppedAnimation(DesignTokens.orange),
                  minHeight: 3,
                ),
              ),
      ),
      body: SafeArea(
        child: _isFinished
            ? _buildSummary()
            : _isRevealing
                ? _buildRevealPhase()
                : _buildQuestion(),
      ),
    );
  }

  Widget _buildRevealPhase() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'この内容を覚えてください',
              style: TextStyle(
                color: DesignTokens.orange,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: DesignTokens.space32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(DesignTokens.space32),
              decoration: BoxDecoration(
                color: DesignTokens.surface1,
                borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
                border: Border.all(
                  color: DesignTokens.orange.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                _current.memoryStimulus ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: DesignTokens.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  height: 1.8,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.space32),
            Text(
              '$_revealRemaining',
              style: const TextStyle(
                color: DesignTokens.textSecondary,
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion() {
    final question = _current;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesignTokens.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_index + 1} / ${_questions.length}',
            style: const TextStyle(
              color: DesignTokens.textTertiary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: DesignTokens.space12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(DesignTokens.space20),
            decoration: BoxDecoration(
              color: DesignTokens.surface1,
              borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
              border: Border.all(color: DesignTokens.divider),
            ),
            // 図形問題は読み上げ用に言葉へ開いた説明を渡す。
            child: Text(
              question.prompt,
              semanticsLabel: question.semanticPrompt,
              style: TextStyle(
                color: DesignTokens.textOnDark,
                fontSize: 16,
                height: question.monospacePrompt ? 1.8 : 1.7,
                fontFamily: question.monospacePrompt ? 'monospace' : null,
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.space20),
          ...List.generate(question.options.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: DesignTokens.space12),
              child: _DrillOption(
                label: String.fromCharCode(65 + i),
                text: question.options[i],
                semanticText: question.semanticOption(i),
                monospace: question.monospacePrompt,
                state: _optionState(i),
                onTap: () => _answer(i),
              ),
            );
          }),
          if (_hasAnswered) ...[
            const SizedBox(height: DesignTokens.space8),
            _ExplanationCard(
              isCorrect: question.isCorrect(_selectedIndex!),
              explanation: question.explanation,
            ),
            const SizedBox(height: DesignTokens.space20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: DesignTokens.space16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radiusMedium),
                  ),
                ),
                child: Text(
                  _index < _questions.length - 1 ? '次の問題' : '結果を見る',
                ),
              ),
            ),
          ],
          const SizedBox(height: DesignTokens.space32),
        ],
      ),
    );
  }

  _OptionState _optionState(int i) {
    if (!_hasAnswered) return _OptionState.idle;
    if (i == _current.correctIndex) return _OptionState.correct;
    if (i == _selectedIndex) return _OptionState.wrong;
    return _OptionState.dimmed;
  }

  Widget _buildSummary() {
    final accuracy = _correctCount / _questions.length;
    final next = IqTrainingService.nextLevel(widget.level, accuracy);
    final levelDelta = next - widget.level;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesignTokens.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: DesignTokens.space20),
          Icon(
            accuracy >= 0.85
                ? Icons.emoji_events_outlined
                : accuracy >= 0.6
                    ? Icons.thumb_up_outlined
                    : Icons.self_improvement_outlined,
            size: 56,
            color: accuracy >= 0.6 ? DesignTokens.green : DesignTokens.amber,
          ),
          const SizedBox(height: DesignTokens.space16),
          Text(
            '$_correctCount / ${_questions.length} 正解',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: DesignTokens.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: DesignTokens.space8),
          Text(
            '正答率 ${(accuracy * 100).round()}%',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: DesignTokens.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: DesignTokens.space24),
          Container(
            padding: const EdgeInsets.all(DesignTokens.space16),
            decoration: BoxDecoration(
              color: DesignTokens.surface1,
              borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
              border: Border.all(color: DesignTokens.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      levelDelta > 0
                          ? Icons.arrow_upward
                          : levelDelta < 0
                              ? Icons.arrow_downward
                              : Icons.remove,
                      size: 16,
                      color: levelDelta > 0
                          ? DesignTokens.green
                          : levelDelta < 0
                              ? DesignTokens.amber
                              : DesignTokens.textSecondary,
                    ),
                    const SizedBox(width: DesignTokens.space8),
                    Text(
                      levelDelta > 0
                          ? '次回はレベル $next に上がります'
                          : levelDelta < 0
                              ? '次回はレベル $next に下がります'
                              : '次回もレベル $next のままです',
                      style: TextStyle(
                        color: levelDelta > 0
                            ? DesignTokens.green
                            : levelDelta < 0
                                ? DesignTokens.amber
                                : DesignTokens.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.space12),
                const Text(
                  '正答率が 60〜85% に収まる難度が最も伸びます。'
                  '簡単すぎても難しすぎても学習効率は落ちるため、自動で調整しています。',
                  style: TextStyle(
                    color: DesignTokens.textSecondary,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.space24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.orange,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(vertical: DesignTokens.space16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
              ),
            ),
            child: const Text('プランに戻る'),
          ),
        ],
      ),
    );
  }
}

enum _OptionState { idle, correct, wrong, dimmed }

class _DrillOption extends StatelessWidget {
  final String label;
  final String text;

  /// 読み上げ用の代替テキスト。
  final String semanticText;
  final bool monospace;
  final _OptionState state;
  final VoidCallback onTap;

  const _DrillOption({
    required this.label,
    required this.text,
    required this.semanticText,
    required this.monospace,
    required this.state,
    required this.onTap,
  });

  Color get _borderColor {
    switch (state) {
      case _OptionState.correct:
        return DesignTokens.green;
      case _OptionState.wrong:
        return DesignTokens.red;
      case _OptionState.idle:
      case _OptionState.dimmed:
        return DesignTokens.divider;
    }
  }

  Color get _textColor {
    switch (state) {
      case _OptionState.correct:
        return DesignTokens.green;
      case _OptionState.wrong:
        return DesignTokens.red;
      case _OptionState.dimmed:
        return DesignTokens.textTertiary;
      case _OptionState.idle:
        return DesignTokens.textPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DesignTokens.surface2,
      borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
      child: InkWell(
        onTap: state == _OptionState.idle ? onTap : null,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(DesignTokens.space16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: DesignTokens.surface3,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: DesignTokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: DesignTokens.space12),
              Expanded(
                child: Text(
                  text,
                  semanticsLabel: semanticText,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 15,
                    height: monospace ? 1.7 : 1.5,
                    fontFamily: monospace ? 'monospace' : null,
                  ),
                ),
              ),
              if (state == _OptionState.correct)
                const Icon(
                  Icons.check_circle,
                  color: DesignTokens.green,
                  size: 20,
                )
              else if (state == _OptionState.wrong)
                const Icon(
                  Icons.cancel,
                  color: DesignTokens.red,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  final bool isCorrect;
  final String explanation;

  const _ExplanationCard({
    required this.isCorrect,
    required this.explanation,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? DesignTokens.green : DesignTokens.amber;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect
                    ? Icons.check_circle_outline
                    : Icons.lightbulb_outline,
                color: color,
                size: 16,
              ),
              const SizedBox(width: DesignTokens.space8),
              Text(
                isCorrect ? '正解' : '解説を読んで次に活かしましょう',
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space8),
          Text(
            explanation,
            style: const TextStyle(
              color: DesignTokens.textOnDark,
              fontSize: 13,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}
