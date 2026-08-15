// IQテストの結果ページ。
//
// ここが「測定」と「学習」の接続点。総合値だけを見せて終わりにせず、
// 領域別の凸凹 → 弱点 → 学習プラン生成 まで一本の導線にする。

import 'package:flutter/material.dart';

import '../data/iq_question_bank.dart';
import '../models/iq_test.dart';
import '../services/iq_scoring.dart';
import '../services/iq_test_service.dart';
import '../services/iq_training_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/iq_review_list.dart';
import '../widgets/iq_score_widgets.dart';
import 'iq_training_page.dart';

class IqTestResultPage extends StatefulWidget {
  final int testId;

  /// 直後の遷移では再取得を省くために結果を引き回す。
  final IqTestResult? initialResult;
  final bool timedOut;

  const IqTestResultPage({
    super.key,
    required this.testId,
    this.initialResult,
    this.timedOut = false,
  });

  @override
  State<IqTestResultPage> createState() => _IqTestResultPageState();
}

class _IqTestResultPageState extends State<IqTestResultPage> {
  final IqTestService _testService = IqTestService();
  final IqTrainingService _trainingService = IqTrainingService();

  IqTestResult? _result;
  bool _isLoading = true;
  bool _isCreatingPlan = false;
  String? _error;

  /// 振り返り用: 保存済み回答と、seed から復元した当時の問題。
  List<IqAnswerRecord> _answers = const [];
  Map<String, IqQuestion> _questionsByKey = const {};

  /// 復元した選択肢の並びが当時と一致しているか。
  /// false のときは selectedIndex から「選んだ選択肢」を復元できない。
  bool _optionOrderIsTrustworthy = true;
  bool _isLoadingReview = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialResult != null) {
      _result = widget.initialResult;
      _isLoading = false;
      _loadReview();
    } else {
      // 結果の取得を待ってから振り返りを読む。
      // 並行に走らせると _loadReview 側で _result がまだ null になり、
      // 同じ行をもう一度取りに行っていた (毎回2回フェッチ)。
      _load().then((_) {
        if (mounted) _loadReview();
      });
    }
  }

  Future<void> _load() async {
    try {
      final result = await _testService.getTestResult(widget.testId);
      if (!mounted) return;
      setState(() {
        _result = result;
        _isLoading = false;
        if (result == null) _error = '結果が見つかりませんでした';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '結果の読み込みに失敗しました: $e';
      });
    }
  }

  /// 振り返り用データを読み込む。
  ///
  /// 問題本体は DB に無いため、保存済みの question_seed で当時の出題を
  /// 再構成して回答と突き合わせる。seed が無い古い記録では復元できないので
  /// 振り返りセクション自体を出さない。
  Future<void> _loadReview() async {
    try {
      final answers = await _testService.getAnswers(widget.testId);
      final seed = _result?.questionSeed;

      // seed から当時の出題を復元する。選択肢の並びまで一致して初めて
      // 「あなたが選んだ選択肢」を index から復元できる。
      final reconstructed = seed == null
          ? <IqQuestion>[]
          : IqQuestionBank.standardTest(seed: seed);
      final byKey = {for (final q in reconstructed) q.key: q};

      // 復元集合が回答キーを網羅しているか。
      // seed の意味を変えた修正 (出題そのものも seed で選ぶ) の前に受けた回は
      // 復元が一致しないため、放置すると該当問題が振り返りから静かに消える。
      final answeredKeys = answers.map((a) => a.questionKey).toSet();
      final reconstructionMatches =
          answeredKeys.isNotEmpty && answeredKeys.every(byKey.containsKey);

      // 一致しない場合は正本 (全プール) から引いて問題自体は必ず表示する。
      // ただし選択肢の並びは復元できないので index 由来の表示は使わせない。
      final resolved = reconstructionMatches
          ? byKey
          : {
              for (final q in IqQuestionBank.allQuestions)
                if (answeredKeys.contains(q.key)) q.key: q,
            };

      if (!mounted) return;
      setState(() {
        _answers = answers;
        _questionsByKey = resolved;
        _optionOrderIsTrustworthy = reconstructionMatches;
        _isLoadingReview = false;
      });
    } catch (e) {
      if (!mounted) return;
      // 振り返りが出せなくてもスコア表示は妨げない
      setState(() => _isLoadingReview = false);
    }
  }

  Future<void> _createPlanAndGo() async {
    final result = _result;
    if (result == null || _isCreatingPlan) return;

    setState(() => _isCreatingPlan = true);
    try {
      final plan = await _trainingService.createPlanFromResult(result);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/iq-training'),
          builder: (_) => IqTrainingPage(initialPlan: plan),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('学習プランの作成に失敗しました: $e'),
          backgroundColor: DesignTokens.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCreatingPlan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.background,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface1,
        elevation: 0,
        title: const Text(
          'テスト結果',
          style: TextStyle(color: DesignTokens.textPrimary),
        ),
        iconTheme: const IconThemeData(color: DesignTokens.textSecondary),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: DesignTokens.orange),
            )
          : _error != null || _result == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(DesignTokens.space24),
                    child: Text(
                      _error ?? '結果がありません',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: DesignTokens.textSecondary,
                      ),
                    ),
                  ),
                )
              : _buildResult(_result!),
    );
  }

  Widget _buildResult(IqTestResult result) {
    final weakAreas = result.weakAreas();
    final strongAreas = result.strongAreas();
    final se = IqScoring.standardError(
      result.weightedAccuracy,
      result.questionCount,
    );
    final draft = IqTrainingService.buildPlanDraft(result);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesignTokens.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.timedOut)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: DesignTokens.space16),
              padding: const EdgeInsets.all(DesignTokens.space12),
              decoration: BoxDecoration(
                color: DesignTokens.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                border: Border.all(
                  color: DesignTokens.amber.withValues(alpha: 0.4),
                ),
              ),
              child: const Text(
                '制限時間に達したため、未回答の問題は不正解として集計しています。',
                style: TextStyle(color: DesignTokens.amber, fontSize: 12),
              ),
            ),
          // H4: 未回答が多い回は「実力が低い」のではなく「測れていない」。
          // 同じ見た目で数値だけ出すと利用者が判断を誤る。
          if (!result.isReliable)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: DesignTokens.space16),
              padding: const EdgeInsets.all(DesignTokens.space12),
              decoration: BoxDecoration(
                color: DesignTokens.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                border: Border.all(
                  color: DesignTokens.red.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                '着手できたのは ${result.attemptedCount ?? 0} / '
                '${result.questionCount} 問 '
                '(完答率 ${(result.completionRate * 100).round()}%) です。'
                'この回のスコアは実力ではなく「測れていない」ことを表しています。'
                '最後まで解ける状態で受け直してください。',
                style: const TextStyle(
                  color: DesignTokens.red,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ),
          IqScoreDial(
            iq: result.totalIq,
            percentile: result.percentile,
            lower: (result.totalIq - 1.96 * se).round(),
            upper: (result.totalIq + 1.96 * se).round(),
          ),
          const SizedBox(height: DesignTokens.space16),
          _SummaryRow(result: result),
          const SizedBox(height: DesignTokens.space24),
          const _SectionTitle(
            title: '領域別スコア',
            subtitle: '縦線が総合スコアの位置。ここからの凸凹が学習の入力になります。',
          ),
          const SizedBox(height: DesignTokens.space8),
          ...result.categoryScores.map(
            (score) => IqCategoryBar(
              score: score,
              referenceIq: result.totalIq,
              isTarget: draft.targets.any((t) => t.category == score.category),
            ),
          ),
          const SizedBox(height: DesignTokens.space24),
          const _SectionTitle(title: '読み取り'),
          const SizedBox(height: DesignTokens.space8),
          _ReadingCard(
            basisMessage: draft.basisMessageJa,
            weakAreas: weakAreas,
            strongAreas: strongAreas,
          ),
          const SizedBox(height: DesignTokens.space24),
          _PlanCta(
            draft: draft,
            isLoading: _isCreatingPlan,
            onPressed: _createPlanAndGo,
          ),
          const SizedBox(height: DesignTokens.space24),

          if (!_isLoadingReview && _questionsByKey.isNotEmpty) ...[
            const _SectionTitle(
              title: '問題ごとの振り返り',
              subtitle: '間違えた問題こそ伸びしろです。解説を読んでから学習に進んでください。',
            ),
            const SizedBox(height: DesignTokens.space12),
            IqReviewList(
              answers: _answers,
              questionsByKey: _questionsByKey,
              optionOrderIsTrustworthy: _optionOrderIsTrustworthy,
            ),
            const SizedBox(height: DesignTokens.space24),
          ],

          const IqDisclaimerCard(),
          const SizedBox(height: DesignTokens.space32),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IqTestResult result;

  const _SummaryRow({required this.result});

  @override
  Widget build(BuildContext context) {
    final minutes = result.durationSeconds ~/ 60;
    final seconds = result.durationSeconds % 60;

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: '正答数',
            value: '${result.correctCount}/${result.questionCount}',
          ),
        ),
        const SizedBox(width: DesignTokens.space12),
        Expanded(
          child: _StatTile(
            label: '重み付き正答率',
            value: '${(result.weightedAccuracy * 100).round()}%',
          ),
        ),
        const SizedBox(width: DesignTokens.space12),
        Expanded(
          child: _StatTile(
            label: '所要時間',
            value: '$minutes分$seconds秒',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: DesignTokens.space12,
        horizontal: DesignTokens.space8,
      ),
      decoration: BoxDecoration(
        color: DesignTokens.surface1,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.divider),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: DesignTokens.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: DesignTokens.space4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: DesignTokens.textTertiary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: DesignTokens.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: DesignTokens.space4),
          Text(
            subtitle!,
            style: const TextStyle(
              color: DesignTokens.textTertiary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _ReadingCard extends StatelessWidget {
  final String basisMessage;
  final List<IqCategoryScore> weakAreas;
  final List<IqCategoryScore> strongAreas;

  const _ReadingCard({
    required this.basisMessage,
    required this.weakAreas,
    required this.strongAreas,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: DesignTokens.surface1,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            basisMessage,
            style: const TextStyle(
              color: DesignTokens.textOnDark,
              fontSize: 13,
              height: 1.7,
            ),
          ),
          if (strongAreas.isNotEmpty) ...[
            const SizedBox(height: DesignTokens.space16),
            _Bullet(
              icon: Icons.trending_up,
              color: DesignTokens.green,
              text: '強み: '
                  '${strongAreas.map((s) => s.category.labelJa).join(' / ')}',
            ),
          ],
          if (weakAreas.isNotEmpty) ...[
            const SizedBox(height: DesignTokens.space8),
            _Bullet(
              icon: Icons.trending_down,
              color: DesignTokens.orange,
              text: '伸びしろ: '
                  '${weakAreas.map((s) => s.category.labelJa).join(' / ')}',
            ),
            const SizedBox(height: DesignTokens.space16),
            ...weakAreas.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: DesignTokens.space8),
                child: Text(
                  '・${s.category.labelJa}: ${s.category.trainingHintJa}',
                  style: const TextStyle(
                    color: DesignTokens.textSecondary,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _Bullet({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: DesignTokens.space8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontSize: 13, height: 1.5),
          ),
        ),
      ],
    );
  }
}

/// 結果 → 学習への導線。何がどう決まったかを見せてから押させる。
class _PlanCta extends StatelessWidget {
  final IqTrainingPlanDraft draft;
  final bool isLoading;
  final VoidCallback onPressed;

  const _PlanCta({
    required this.draft,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DesignTokens.space20),
      decoration: BoxDecoration(
        color: DesignTokens.surface1,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        border: Border.all(
          color: DesignTokens.orange.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'この結果から作られる学習プラン',
            style: TextStyle(
              color: DesignTokens.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: DesignTokens.space12),
          ...draft.targets.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: DesignTokens.space8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t.category.labelJa,
                      style: const TextStyle(
                        color: DesignTokens.textOnDark,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    'IQ ${t.baselineIq} → レベル${t.startLevel}'
                    ' / 週${t.weeklySessions}回',
                    style: const TextStyle(
                      color: DesignTokens.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.space8),
          const Text(
            '難度は測定値から自動で決まり、実施後の正答率でさらに上下します。',
            style: TextStyle(
              color: DesignTokens.textTertiary,
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: DesignTokens.space16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onPressed,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.school_outlined),
              label: Text(isLoading ? '作成中...' : 'この内容で学習を始める'),
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
            ),
          ),
        ],
      ),
    );
  }
}
