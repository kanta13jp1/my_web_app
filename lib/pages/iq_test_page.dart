// IQテストのハブページ。測定と学習への入口。

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/iq_question_bank.dart';
import '../models/iq_test.dart';
import '../services/iq_test_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/iq_score_widgets.dart';
import 'iq_test_questions_page.dart';
import 'iq_test_result_page.dart';
import 'iq_training_page.dart';

class IqTestPage extends StatefulWidget {
  const IqTestPage({super.key});

  @override
  State<IqTestPage> createState() => _IqTestPageState();
}

class _IqTestPageState extends State<IqTestPage> {
  final IqTestService _service = IqTestService();

  IqTestResult? _latest;
  List<IqTestResult> _history = [];
  bool _isLoading = true;
  bool _isStarting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final latest = await _service.getLatestResult();
      final history = await _service.getHistory();
      if (!mounted) return;
      setState(() {
        _latest = latest;
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '読み込みに失敗しました: $e';
      });
    }
  }

  Future<void> _startTest() async {
    if (_isStarting) return;
    setState(() => _isStarting = true);

    try {
      // 選択肢の並びを毎回変えて、正解位置の丸暗記を防ぐ
      final seed = math.Random().nextInt(1 << 31);
      final test = await _service.startTest(questionSeed: seed);
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/iq-test-questions'),
          builder: (_) => IqTestQuestionsPage(
            testId: test.id,
            questionSeed: seed,
          ),
        ),
      );
      if (mounted) await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('テストの開始に失敗しました: $e'),
          backgroundColor: DesignTokens.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isStarting = false);
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
          'IQテスト',
          style: TextStyle(color: DesignTokens.textPrimary),
        ),
        iconTheme: const IconThemeData(color: DesignTokens.textSecondary),
        actions: [
          IconButton(
            tooltip: 'トレーニング',
            icon: const Icon(
              Icons.school_outlined,
              color: DesignTokens.textSecondary,
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                settings: const RouteSettings(name: '/iq-training'),
                builder: (_) => const IqTrainingPage(),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: DesignTokens.orange),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: DesignTokens.orange,
              backgroundColor: DesignTokens.surface1,
              child: ListView(
                padding: const EdgeInsets.all(DesignTokens.space20),
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(color: DesignTokens.red),
                    ),
                    const SizedBox(height: DesignTokens.space16),
                  ],
                  if (_latest != null) ...[
                    IqScoreDial(
                      iq: _latest!.totalIq,
                      percentile: _latest!.percentile,
                      label: '最新の推定IQ',
                    ),
                    const SizedBox(height: DesignTokens.space16),
                    ..._latest!.categoryScores.map(
                      (s) => IqCategoryBar(
                        score: s,
                        referenceIq: _latest!.totalIq,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.space16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                settings: const RouteSettings(
                                  name: '/iq-test-result',
                                ),
                                builder: (_) =>
                                    IqTestResultPage(testId: _latest!.id),
                              ),
                            ),
                            icon: const Icon(
                              Icons.analytics_outlined,
                              size: 18,
                            ),
                            label: const Text('詳しい結果'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: DesignTokens.textSecondary,
                              side: const BorderSide(
                                color: DesignTokens.divider,
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: DesignTokens.space12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: DesignTokens.space12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                settings: const RouteSettings(
                                  name: '/iq-training',
                                ),
                                builder: (_) => const IqTrainingPage(),
                              ),
                            ),
                            icon: const Icon(Icons.school_outlined, size: 18),
                            label: const Text('学習プラン'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: DesignTokens.orange,
                              side: BorderSide(
                                color:
                                    DesignTokens.orange.withValues(alpha: 0.5),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: DesignTokens.space12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_history.length >= 2) ...[
                      const SizedBox(height: DesignTokens.space24),
                      _HistoryChart(history: _history),
                    ],
                  ] else
                    _buildIntro(),
                  const SizedBox(height: DesignTokens.space24),
                  _buildStartCard(),
                  const SizedBox(height: DesignTokens.space20),
                  const IqDisclaimerCard(),
                  const SizedBox(height: DesignTokens.space32),
                ],
              ),
            ),
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space20),
      decoration: BoxDecoration(
        color: DesignTokens.surface1,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        border: Border.all(color: DesignTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '5つの領域を測ります',
            style: TextStyle(
              color: DesignTokens.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: DesignTokens.space4),
          const Text(
            '総合スコアより、領域ごとの凸凹のほうが学習には役立ちます。',
            style: TextStyle(
              color: DesignTokens.textTertiary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: DesignTokens.space16),
          ...IqCategory.values.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: DesignTokens.space12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(
                      color: DesignTokens.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.labelJa,
                          style: const TextStyle(
                            color: DesignTokens.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          c.descriptionJa,
                          style: const TextStyle(
                            color: DesignTokens.textSecondary,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartCard() {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space20),
      decoration: BoxDecoration(
        color: DesignTokens.surface1,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        border: Border.all(color: DesignTokens.orange.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MetaItem(
                icon: Icons.help_outline,
                label: '${IqQuestionBank.totalQuestions}問',
              ),
              _MetaItem(
                icon: Icons.timer_outlined,
                label: '${IqQuestionBank.timeLimit.inMinutes}分',
              ),
              _MetaItem(
                icon: Icons.category_outlined,
                label: '${IqCategory.values.length}領域',
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isStarting ? null : _startTest,
              icon: _isStarting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(
                _isStarting
                    ? '準備中...'
                    : _latest == null
                        ? 'テストを始める'
                        : 'もう一度受ける',
              ),
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
          const SizedBox(height: DesignTokens.space12),
          const Text(
            '静かな場所で、中断せずに一気に解いてください。',
            style: TextStyle(
              color: DesignTokens.textTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: DesignTokens.orange, size: 20),
        const SizedBox(height: DesignTokens.space4),
        Text(
          label,
          style: const TextStyle(
            color: DesignTokens.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// 推移の簡易チャート。絶対値より変化を見せる。
class _HistoryChart extends StatelessWidget {
  final List<IqTestResult> history;

  const _HistoryChart({required this.history});

  @override
  Widget build(BuildContext context) {
    final values = history.map((h) => h.totalIq).toList();
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    // 全部同じ値だと高さ0で潰れるので下限レンジを設ける
    final range = math.max(maxValue - minValue, 10);

    return Container(
      padding: const EdgeInsets.all(DesignTokens.space20),
      decoration: BoxDecoration(
        color: DesignTokens.surface1,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'スコアの推移',
            style: TextStyle(
              color: DesignTokens.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: DesignTokens.space16),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: history.map((h) {
                final ratio = (h.totalIq - minValue) / range;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${h.totalIq}',
                          style: const TextStyle(
                            color: DesignTokens.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: DesignTokens.space4),
                        Container(
                          height: 20 + ratio * 60,
                          decoration: BoxDecoration(
                            color: DesignTokens.indigo,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: DesignTokens.space8),
          const Text(
            '左が古い回。再受験は練習効果で上がりやすいため、'
            '上昇幅そのものを能力の伸びとは読まないでください。',
            style: TextStyle(
              color: DesignTokens.textTertiary,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
