import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/toeic_practice.dart';
import '../view_models/toeic_practice_view_model.dart';

const Color _toeicNavy = Color(0xFF102A43);
const Color _toeicBlue = Color(0xFF2563EB);
const Color _toeicGold = Color(0xFFF5B700);

class ToeicPracticePage extends StatelessWidget {
  const ToeicPracticePage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ToeicPracticeViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI大学 TOEIC対策'),
        backgroundColor: _toeicNavy,
        foregroundColor: Colors.white,
        leading: viewModel.stage == ToeicPracticeStage.dashboard
            ? null
            : IconButton(
                tooltip: 'ダッシュボードへ戻る',
                onPressed: viewModel.showDashboard,
                icon: const Icon(Icons.close),
              ),
      ),
      body: switch (viewModel.stage) {
        ToeicPracticeStage.dashboard => _Dashboard(viewModel: viewModel),
        ToeicPracticeStage.question => _QuestionSession(viewModel: viewModel),
        ToeicPracticeStage.summary => _SessionSummary(viewModel: viewModel),
      },
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.viewModel});

  final ToeicPracticeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final snapshot = viewModel.dashboard;
    final progress = snapshot.progress;
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < 600 ? 16.0 : 28.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(padding, 20, padding, 36),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeroCard(
                    targetScore: progress.targetScore,
                    todayCompleted: snapshot.todayCompleted,
                    onStart: viewModel.startDailySession,
                  ),
                  if (viewModel.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    _InlineMessage(message: viewModel.errorMessage!),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    '学習ダッシュボード',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MetricCard(
                        icon: Icons.flag_outlined,
                        label: '目標スコア',
                        value: '${progress.targetScore}',
                        color: _toeicBlue,
                      ),
                      _MetricCard(
                        icon: Icons.task_alt,
                        label: '累計正答率',
                        value: progress.totalAnswered == 0
                            ? '—'
                            : '${(progress.accuracy * 100).round()}%',
                        color: const Color(0xFF16A34A),
                      ),
                      _MetricCard(
                        icon: Icons.local_fire_department_outlined,
                        label: '連続学習',
                        value: '${snapshot.currentStreak}日',
                        color: const Color(0xFFEA580C),
                      ),
                      _MetricCard(
                        icon: Icons.edit_note_outlined,
                        label: '回答数',
                        value: '${progress.totalAnswered}問',
                        color: const Color(0xFF7C3AED),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _TargetScoreSelector(
                    selectedScore: progress.targetScore,
                    onSelected: viewModel.setTargetScore,
                  ),
                  const SizedBox(height: 28),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Part別トレーニング',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      Text(
                        'おすすめ: ${snapshot.recommendedPart.label}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: _toeicBlue,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _PartCards(
                    progress: progress,
                    recommendedPart: snapshot.recommendedPart,
                    onStart: viewModel.startPartSession,
                  ),
                  const SizedBox(height: 24),
                  _ScorePlanCard(targetScore: progress.targetScore),
                  const SizedBox(height: 16),
                  const Text(
                    '※ 練習問題は本アプリ独自作成です。ETS等の公式問題・公式教材ではありません。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.targetScore,
    required this.todayCompleted,
    required this.onStart,
  });

  final int targetScore;
  final bool todayCompleted;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[_toeicNavy, Color(0xFF174A7E)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _toeicNavy.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'AI大学 × ENGLISH',
                  style: TextStyle(
                    color: Color(0xFFFFD966),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '毎日5問、\nスコアにつながる習慣を。',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '目標 $targetScore点に向けて、Part 5・6・7を短時間で反復します。',
                style: const TextStyle(
                  color: Color(0xFFD9EAF7),
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ],
          );
          final action = FilledButton.icon(
            key: const Key('start_daily_toeic_drill'),
            style: FilledButton.styleFrom(
              backgroundColor: _toeicGold,
              foregroundColor: _toeicNavy,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
            onPressed: onStart,
            icon: Icon(
              todayCompleted ? Icons.replay_rounded : Icons.play_arrow_rounded,
            ),
            label: Text(todayCompleted ? 'もう1セット解く' : '今日の5問を始める'),
          );
          if (constraints.maxWidth >= 720) {
            return Row(
              children: [
                Expanded(child: copy),
                const SizedBox(width: 24),
                action,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [copy, const SizedBox(height: 20), action],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 155,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.labelSmall),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TargetScoreSelector extends StatelessWidget {
  const _TargetScoreSelector({
    required this.selectedScore,
    required this.onSelected,
  });

  final int selectedScore;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '目標スコア',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text('目標に合わせて学習の重点を確認できます。'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                for (final score in const <int>[600, 730, 860])
                  ChoiceChip(
                    key: Key('toeic_target_$score'),
                    label: Text('$score点'),
                    selected: selectedScore == score,
                    onSelected: (_) => onSelected(score),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PartCards extends StatelessWidget {
  const _PartCards({
    required this.progress,
    required this.recommendedPart,
    required this.onStart,
  });

  final ToeicProgress progress;
  final ToeicPart recommendedPart;
  final ValueChanged<ToeicPart> onStart;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final width =
            wide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final part in ToeicPart.values)
              SizedBox(
                width: width,
                child: _PartCard(
                  part: part,
                  answered: progress.answeredByPart[part] ?? 0,
                  accuracy: progress.accuracyFor(part),
                  recommended: part == recommendedPart,
                  onStart: () => onStart(part),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PartCard extends StatelessWidget {
  const _PartCard({
    required this.part,
    required this.answered,
    required this.accuracy,
    required this.recommended,
    required this.onStart,
  });

  final ToeicPart part;
  final int answered;
  final double accuracy;
  final bool recommended;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: recommended ? _toeicBlue : Theme.of(context).dividerColor,
          width: recommended ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _toeicBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    part.label,
                    style: const TextStyle(
                      color: _toeicBlue,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Spacer(),
                if (recommended)
                  const Text(
                    'おすすめ',
                    style: TextStyle(
                      color: _toeicBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              part.titleJa,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(part.description),
            const SizedBox(height: 14),
            Text(
              answered == 0
                  ? 'まだ記録がありません'
                  : '$answered問・正答率 ${(accuracy * 100).round()}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: Key('start_${part.id}_drill'),
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('このPartを解く'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScorePlanCard extends StatelessWidget {
  const _ScorePlanCard({required this.targetScore});

  final int targetScore;

  @override
  Widget build(BuildContext context) {
    final String title;
    final String detail;
    if (targetScore <= 600) {
      title = '600点プラン';
      detail = 'Part 5の基本文法と頻出語彙を優先し、毎日1セットを確実に続けましょう。';
    } else if (targetScore <= 730) {
      title = '730点プラン';
      detail = 'Part 5の速度を上げながら、Part 6・7で根拠を素早く探す練習を重ねましょう。';
    } else {
      title = '860点プラン';
      detail = '正答率だけでなく時間配分を意識し、弱点Partを優先して取りこぼしを減らしましょう。';
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _toeicGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _toeicGold.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: Color(0xFF9A6B00)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(detail),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionSession extends StatelessWidget {
  const _QuestionSession({required this.viewModel});

  final ToeicPracticeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final question = viewModel.currentQuestion;
    if (question == null) return const Center(child: Text('問題がありません。'));
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: constraints.maxWidth < 600 ? 16 : 28,
            vertical: 20,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        '${viewModel.questionNumber} / ${viewModel.sessionLength}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const Spacer(),
                      Text('${question.part.label}・${question.category}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: viewModel.questionNumber / viewModel.sessionLength,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(999),
                    color: _toeicBlue,
                  ),
                  const SizedBox(height: 20),
                  if (question.passage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: SelectableText(
                        question.passage!,
                        style: const TextStyle(fontSize: 15, height: 1.65),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  Text(
                    question.prompt,
                    key: const Key('toeic_question_prompt'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.45,
                        ),
                  ),
                  const SizedBox(height: 18),
                  for (var index = 0;
                      index < question.choices.length;
                      index++) ...[
                    _AnswerChoice(
                      index: index,
                      text: question.choices[index],
                      selected: viewModel.selectedAnswerIndex == index,
                      submitted: viewModel.answerSubmitted,
                      correct: question.answerIndex == index,
                      onTap: () => viewModel.selectAnswer(index),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 8),
                  if (!viewModel.answerSubmitted)
                    FilledButton(
                      key: const Key('submit_toeic_answer'),
                      onPressed: viewModel.selectedAnswerIndex == null
                          ? null
                          : viewModel.submitAnswer,
                      style: FilledButton.styleFrom(
                        backgroundColor: _toeicBlue,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: const Text('回答する'),
                    )
                  else ...[
                    _AnswerFeedback(
                      correct: viewModel.selectedAnswerIsCorrect,
                      explanation: question.explanation,
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      key: const Key('next_toeic_question'),
                      onPressed: viewModel.nextQuestion,
                      style: FilledButton.styleFrom(
                        backgroundColor: _toeicNavy,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      icon: Icon(
                        viewModel.isLastQuestion
                            ? Icons.emoji_events_outlined
                            : Icons.arrow_forward,
                      ),
                      label: Text(viewModel.isLastQuestion ? '結果を見る' : '次の問題'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnswerChoice extends StatelessWidget {
  const _AnswerChoice({
    required this.index,
    required this.text,
    required this.selected,
    required this.submitted,
    required this.correct,
    required this.onTap,
  });

  final int index;
  final String text;
  final bool selected;
  final bool submitted;
  final bool correct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    var color = Theme.of(context).colorScheme.outline;
    var background = Colors.transparent;
    if (!submitted && selected) {
      color = _toeicBlue;
      background = _toeicBlue.withValues(alpha: 0.08);
    } else if (submitted && correct) {
      color = const Color(0xFF15803D);
      background = const Color(0xFFDCFCE7);
    } else if (submitted && selected) {
      color = const Color(0xFFB91C1C);
      background = const Color(0xFFFEE2E2);
    }
    return OutlinedButton(
      key: Key('toeic_choice_$index'),
      onPressed: submitted ? null : onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: submitted && (correct || selected)
            ? color
            : Theme.of(context).colorScheme.onSurface,
        disabledForegroundColor: color,
        backgroundColor: background,
        disabledBackgroundColor: background,
        side: BorderSide(color: color, width: selected || correct ? 2 : 1),
        padding: const EdgeInsets.all(15),
        alignment: Alignment.centerLeft,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              String.fromCharCode(65 + index),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
          if (submitted && correct) const Icon(Icons.check_circle_outline),
          if (submitted && selected && !correct)
            const Icon(Icons.cancel_outlined),
        ],
      ),
    );
  }
}

class _AnswerFeedback extends StatelessWidget {
  const _AnswerFeedback({required this.correct, required this.explanation});

  final bool correct;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    final color = correct ? const Color(0xFF15803D) : const Color(0xFFB91C1C);
    return Container(
      key: const Key('toeic_answer_feedback'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            correct ? '正解です！' : 'ここを復習しましょう',
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(explanation),
        ],
      ),
    );
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({required this.viewModel});

  final ToeicPracticeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final percent = viewModel.sessionLength == 0
        ? 0
        : (viewModel.sessionCorrect / viewModel.sessionLength * 100).round();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 38,
                    backgroundColor: Color(0xFFFFF3C4),
                    child: Icon(
                      Icons.emoji_events,
                      color: Color(0xFF9A6B00),
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '今日のドリル完了！',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${viewModel.sessionCorrect} / ${viewModel.sessionLength}問正解（$percent%）',
                    key: const Key('toeic_session_score'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: _toeicBlue,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    percent >= 80
                        ? 'よくできました。次はスピードも意識してみましょう。'
                        : '解説を思い出しながら、同じPartをもう一度解くと定着します。',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('return_to_toeic_dashboard'),
                      onPressed: viewModel.showDashboard,
                      icon: const Icon(Icons.dashboard_outlined),
                      label: const Text('ダッシュボードへ'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: viewModel.repeatSession,
                      icon: const Icon(Icons.replay),
                      label: const Text('もう一度解く'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
