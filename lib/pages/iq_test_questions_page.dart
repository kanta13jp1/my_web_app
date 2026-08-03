// IQテストの出題ページ。

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/iq_question_bank.dart';
import '../models/iq_test.dart';
import '../services/iq_test_service.dart';
import '../theme/design_tokens.dart';
import 'iq_test_result_page.dart';

class IqTestQuestionsPage extends StatefulWidget {
  final int testId;

  /// 選択肢シャッフルに使うシード。結果ページでの再現に必要。
  final int questionSeed;

  const IqTestQuestionsPage({
    super.key,
    required this.testId,
    required this.questionSeed,
  });

  @override
  State<IqTestQuestionsPage> createState() => _IqTestQuestionsPageState();
}

class _IqTestQuestionsPageState extends State<IqTestQuestionsPage>
    with WidgetsBindingObserver {
  final IqTestService _service = IqTestService();

  late final List<IqQuestion> _questions;
  final List<IqAnswerRecord> _answers = [];

  int _index = 0;
  bool _isSubmitting = false;
  bool _isFinishing = false;

  /// 記憶課題の刺激提示フェーズ中か。
  bool _isRevealing = false;
  int _revealRemaining = 0;
  Timer? _revealTimer;

  /// テスト全体の残り時間。
  late int _remainingSeconds;
  Timer? _globalTimer;

  late DateTime _testStartedAt;
  late DateTime _questionStartedAt;

  @override
  void initState() {
    super.initState();
    _questions = IqQuestionBank.standardTest(seed: widget.questionSeed);
    _remainingSeconds = IqQuestionBank.timeLimit.inSeconds;
    _testStartedAt = DateTime.now();
    _questionStartedAt = DateTime.now();
    WidgetsBinding.instance.addObserver(this);
    _startGlobalTimer();
    _prepareQuestion();
  }

  /// アプリが背面に回ったら記憶課題の提示を止める。
  ///
  /// 提示タイマーは実時間で進むため、タブを隠している間もカウントが進み、
  /// 戻ってきたときには刺激が消えている = 見ていないのに解答を迫られる。
  /// 背面では一時停止し、復帰時に残り時間から再開する。
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
    _globalTimer?.cancel();
    super.dispose();
  }

  IqQuestion get _current => _questions[_index];

  void _startGlobalTimer() {
    _globalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _finish(timedOut: true);
      }
    });
  }

  /// 記憶課題なら刺激提示フェーズから始める。
  void _prepareQuestion() {
    _questionStartedAt = DateTime.now();
    _revealTimer?.cancel();

    if (!_current.hasMemoryPhase) {
      setState(() => _isRevealing = false);
      return;
    }

    setState(() {
      _isRevealing = true;
      _revealRemaining = _current.revealSeconds!;
    });

    _resumeRevealCountdown();
  }

  /// 残り [_revealRemaining] 秒からカウントダウンを（再）開始する。
  ///
  /// 初回開始と背面復帰の両方から呼ぶ。残り時間を状態に持たせているので、
  /// 中断しても見せていない分は減らない。
  void _resumeRevealCountdown() {
    _revealTimer?.cancel();
    _revealTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _revealRemaining--);
      if (_revealRemaining <= 0) {
        timer.cancel();
        setState(() {
          _isRevealing = false;
          // 刺激が消えた瞬間から回答時間を測る
          _questionStartedAt = DateTime.now();
        });
      }
    });
  }

  Future<void> _answer(int selectedIndex) async {
    if (_isSubmitting || _isRevealing) return;
    setState(() => _isSubmitting = true);

    final question = _current;
    final record = IqAnswerRecord(
      questionKey: question.key,
      category: question.category,
      difficulty: question.difficulty,
      selectedIndex: selectedIndex,
      isCorrect: question.isCorrect(selectedIndex),
      responseMs: DateTime.now().difference(_questionStartedAt).inMilliseconds,
    );
    _answers.add(record);

    try {
      await _service.saveAnswer(testId: widget.testId, answer: record);
    } catch (e) {
      // 個々の保存失敗でテストを止めない。最終集計はローカルの _answers で行う。
      debugPrint('IQ answer save failed (continuing): $e');
    }

    if (!mounted) return;

    if (_index < _questions.length - 1) {
      setState(() {
        _index++;
        _isSubmitting = false;
      });
      _prepareQuestion();
    } else {
      await _finish();
    }
  }

  /// 未回答を不正解として埋めたうえで集計する。
  ///
  /// 時間切れの未回答を単に捨てると、解いた問題だけで採点され
  /// 「早く諦めるほど高得点」になってしまう。
  Future<void> _finish({bool timedOut = false}) async {
    if (_isFinishing) return;
    _isFinishing = true;
    _globalTimer?.cancel();
    _revealTimer?.cancel();

    final answered = _answers.map((a) => a.questionKey).toSet();
    final filled = <IqAnswerRecord>[
      ..._answers,
      for (final q in _questions)
        if (!answered.contains(q.key))
          IqAnswerRecord(
            questionKey: q.key,
            category: q.category,
            difficulty: q.difficulty,
            selectedIndex: null,
            isCorrect: false,
            responseMs: 0,
          ),
    ];

    try {
      final result = await _service.completeTest(
        testId: widget.testId,
        answers: filled,
        durationSeconds: DateTime.now().difference(_testStartedAt).inSeconds,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/iq-test-result'),
          builder: (_) => IqTestResultPage(
            testId: result.id,
            initialResult: result,
            timedOut: timedOut,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _isFinishing = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('結果の保存に失敗しました: $e'),
          backgroundColor: DesignTokens.red,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmQuit() async {
    final shouldQuit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DesignTokens.surface1,
        title: const Text(
          'テストを中断しますか？',
          style: TextStyle(color: DesignTokens.textPrimary),
        ),
        content: const Text(
          '途中でやめると、この回の結果は保存されません。',
          style: TextStyle(color: DesignTokens.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('続ける'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              '中断する',
              style: TextStyle(color: DesignTokens.red),
            ),
          ),
        ],
      ),
    );

    if (shouldQuit != true || !mounted) return;
    await _service.abandonTest(widget.testId);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  String get _formattedRemaining {
    final safe = _remainingSeconds < 0 ? 0 : _remainingSeconds;
    final m = (safe ~/ 60).toString().padLeft(2, '0');
    final s = (safe % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_index + 1) / _questions.length;
    final isLowTime = _remainingSeconds <= 60;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmQuit();
      },
      child: Scaffold(
        backgroundColor: DesignTokens.background,
        appBar: AppBar(
          backgroundColor: DesignTokens.surface1,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: DesignTokens.textSecondary),
            onPressed: _confirmQuit,
          ),
          title: Text(
            '${_index + 1} / ${_questions.length}',
            style: const TextStyle(
              color: DesignTokens.textPrimary,
              fontSize: 16,
            ),
          ),
          actions: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: DesignTokens.space16),
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.space12,
                  vertical: DesignTokens.space4,
                ),
                decoration: BoxDecoration(
                  color: (isLowTime ? DesignTokens.red : DesignTokens.surface3)
                      .withValues(alpha: isLowTime ? 0.2 : 1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                ),
                child: Text(
                  _formattedRemaining,
                  style: TextStyle(
                    color: isLowTime
                        ? DesignTokens.red
                        : DesignTokens.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: DesignTokens.surface3,
              valueColor: const AlwaysStoppedAnimation(DesignTokens.orange),
              minHeight: 3,
            ),
          ),
        ),
        body: SafeArea(
          child: _isFinishing
              ? const Center(
                  child: CircularProgressIndicator(
                    color: DesignTokens.orange,
                  ),
                )
              : _isRevealing
                  ? _buildRevealPhase()
                  : _buildQuestionPhase(),
        ),
      ),
    );
  }

  /// 記憶課題の刺激提示。
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
            const SizedBox(height: DesignTokens.space8),
            const Text(
              '秒後に隠れます',
              style: TextStyle(
                color: DesignTokens.textTertiary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionPhase() {
    final question = _current;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesignTokens.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CategoryChip(category: question.category),
              const SizedBox(width: DesignTokens.space8),
              _DifficultyChip(difficulty: question.difficulty),
            ],
          ),
          const SizedBox(height: DesignTokens.space20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(DesignTokens.space20),
            decoration: BoxDecoration(
              color: DesignTokens.surface1,
              borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
              border: Border.all(color: DesignTokens.divider),
            ),
            // 図形問題は ■□ のままでは読み上げで配置が伝わらないため、
            // 音声には言葉へ開いた説明を渡す。
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
              child: _OptionButton(
                label: String.fromCharCode(65 + i),
                text: question.options[i],
                semanticText: question.semanticOption(i),
                monospace: question.monospacePrompt,
                enabled: !_isSubmitting,
                onTap: () => _answer(i),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final IqCategory category;

  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space12,
        vertical: DesignTokens.space4,
      ),
      decoration: BoxDecoration(
        color: DesignTokens.indigo.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
      ),
      child: Text(
        category.labelJa,
        style: const TextStyle(
          color: DesignTokens.indigoLight,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  final int difficulty;

  const _DifficultyChip({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        return Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Icon(
            i < difficulty ? Icons.star : Icons.star_border,
            size: 12,
            color:
                i < difficulty ? DesignTokens.amber : DesignTokens.textDisabled,
          ),
        );
      }),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String label;
  final String text;

  /// 読み上げ用の代替テキスト。図形選択肢を言葉に開いたもの。
  final String semanticText;
  final bool monospace;
  final bool enabled;
  final VoidCallback onTap;

  const _OptionButton({
    required this.label,
    required this.text,
    required this.semanticText,
    required this.monospace,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DesignTokens.surface2,
      borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(DesignTokens.space16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
            border: Border.all(color: DesignTokens.divider),
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
                    color: DesignTokens.textPrimary,
                    fontSize: 15,
                    height: monospace ? 1.7 : 1.5,
                    fontFamily: monospace ? 'monospace' : null,
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
