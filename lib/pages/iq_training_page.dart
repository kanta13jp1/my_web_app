// IQトレーニングのプランページ。
//
// テスト結果 (領域別IQ) から決まった対象領域・開始レベルを表示し、
// 実施状況に応じて現在レベルを再計算して見せる。

import 'package:flutter/material.dart';

import '../models/iq_test.dart';
import '../services/iq_test_service.dart';
import '../services/iq_training_service.dart';
import '../theme/design_tokens.dart';
import 'iq_training_drill_page.dart';

class IqTrainingPage extends StatefulWidget {
  final IqTrainingPlan? initialPlan;

  const IqTrainingPage({super.key, this.initialPlan});

  @override
  State<IqTrainingPage> createState() => _IqTrainingPageState();
}

class _IqTrainingPageState extends State<IqTrainingPage> {
  final IqTrainingService _service = IqTrainingService();
  final IqTestService _testService = IqTestService();

  IqTrainingPlan? _plan;
  List<IqTrainingSession> _sessions = [];

  /// 最新の完了テストID。プランの元になったテストより新しければ、
  /// プランは古い測定値に基づいたままなので作り直しを促す。
  int? _latestTestId;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _plan = widget.initialPlan;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final plan = _plan ?? await _service.getActivePlan();
      if (plan == null) {
        if (!mounted) return;
        setState(() {
          _plan = null;
          _isLoading = false;
        });
        return;
      }

      final sessions = await _service.getSessions(plan.id);
      // プランが最新の測定に追随しているかを判定するため、
      // 最新テストの ID も取る。ここを見ないと、再テストで弱点が変わっても
      // 古い領域を鍛え続けていることにユーザーが気づけない。
      final latest = await _testService.getLatestResult();
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _sessions = sessions;
        _latestTestId = latest?.id;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '学習プランの読み込みに失敗しました: $e';
      });
    }
  }

  /// 最新のテスト結果からプランを作り直す。
  Future<void> _regenerateFromLatestTest() async {
    try {
      final latest = await _testService.getLatestResult();
      if (!mounted) return;

      if (latest == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('先にIQテストを受けてください'),
            backgroundColor: DesignTokens.red,
          ),
        );
        return;
      }

      final plan = await _service.createPlanFromResult(latest);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _sessions = [];
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('プランの再作成に失敗しました: $e'),
          backgroundColor: DesignTokens.red,
        ),
      );
    }
  }

  Future<void> _startDrill(IqTrainingTarget target) async {
    final plan = _plan;
    if (plan == null) return;

    final level = IqTrainingService.currentLevelFor(
      target: target,
      sessions: _sessions,
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/iq-training-drill'),
        builder: (_) => IqTrainingDrillPage(
          planId: plan.id,
          category: target.category,
          level: level,
        ),
      ),
    );

    // ドリル完了後の実績を反映する
    if (mounted) await _load();
  }

  /// 今週 (月曜起点) に実施したセッション数。
  int _sessionsThisWeek(IqCategory category) {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return _sessions
        .where(
          (s) => s.category == category && s.completedAt.isAfter(startOfWeek),
        )
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.background,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface1,
        elevation: 0,
        title: const Text(
          'IQトレーニング',
          style: TextStyle(color: DesignTokens.textPrimary),
        ),
        iconTheme: const IconThemeData(color: DesignTokens.textSecondary),
        actions: [
          IconButton(
            tooltip: '最新のテスト結果でプランを作り直す',
            icon: const Icon(Icons.refresh, color: DesignTokens.textSecondary),
            onPressed: _regenerateFromLatestTest,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: DesignTokens.orange),
            )
          : _error != null
              ? _buildError()
              : _plan == null
                  ? _buildEmpty()
                  : _buildPlan(_plan!),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: DesignTokens.textSecondary),
            ),
            const SizedBox(height: DesignTokens.space16),
            TextButton(onPressed: _load, child: const Text('再試行')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.school_outlined,
              size: 48,
              color: DesignTokens.textDisabled,
            ),
            const SizedBox(height: DesignTokens.space16),
            const Text(
              '学習プランがありません',
              style: TextStyle(
                color: DesignTokens.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: DesignTokens.space8),
            const Text(
              'IQテストを受けると、領域別スコアから\n'
              '弱点に合わせた学習プランが自動で作られます。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: DesignTokens.textSecondary,
                fontSize: 13,
                height: 1.6,
              ),
            ),
            const SizedBox(height: DesignTokens.space20),
            ElevatedButton(
              onPressed: _regenerateFromLatestTest,
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('最新のテスト結果から作成'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlan(IqTrainingPlan plan) {
    final totalSessions = _sessions.length;
    final readyForRetest = IqTrainingService.shouldRetest(_sessions);
    final remaining = IqTrainingService.sessionsUntilRetest(_sessions);

    return RefreshIndicator(
      onRefresh: _load,
      color: DesignTokens.orange,
      backgroundColor: DesignTokens.surface1,
      child: ListView(
        padding: const EdgeInsets.all(DesignTokens.space20),
        children: [
          _PlanHeader(
            plan: plan,
            totalSessions: totalSessions,
            readyForRetest: readyForRetest,
            remainingForRetest: remaining,
            isStale:
                _latestTestId != null && _latestTestId! > plan.sourceTestId,
            onRegenerate: _regenerateFromLatestTest,
          ),
          const SizedBox(height: DesignTokens.space24),
          const Text(
            '学習対象',
            style: TextStyle(
              color: DesignTokens.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: DesignTokens.space4),
          const Text(
            'レベルはテストの領域別スコアで決まり、実施後の正答率で自動調整されます。',
            style: TextStyle(
              color: DesignTokens.textTertiary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: DesignTokens.space16),
          ...plan.targets.map((target) {
            final level = IqTrainingService.currentLevelFor(
              target: target,
              sessions: _sessions,
            );
            final done = _sessionsThisWeek(target.category);
            final categorySessions =
                _sessions.where((s) => s.category == target.category).toList();

            return Padding(
              padding: const EdgeInsets.only(bottom: DesignTokens.space16),
              child: _TargetCard(
                target: target,
                currentLevel: level,
                doneThisWeek: done,
                recentSessions: categorySessions.take(5).toList(),
                onStart: () => _startDrill(target),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PlanHeader extends StatelessWidget {
  final IqTrainingPlan plan;
  final int totalSessions;
  final bool readyForRetest;
  final int remainingForRetest;

  /// プランより新しいテスト結果が存在するか。
  final bool isStale;
  final VoidCallback onRegenerate;

  const _PlanHeader({
    required this.plan,
    required this.totalSessions,
    required this.readyForRetest,
    required this.remainingForRetest,
    required this.isStale,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DesignTokens.space20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0A2E), Color(0xFF0A1A3E)],
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        border: Border.all(color: DesignTokens.indigo.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'テスト#${plan.sourceTestId} の結果にもとづくプラン',
            style: const TextStyle(
              color: DesignTokens.textTertiary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: DesignTokens.space8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '基準 IQ ${plan.baselineIq}',
                style: const TextStyle(
                  color: DesignTokens.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '実施 $totalSessions 回',
                style: const TextStyle(
                  color: DesignTokens.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space16),
          Container(
            padding: const EdgeInsets.all(DesignTokens.space12),
            decoration: BoxDecoration(
              color: (readyForRetest
                      ? DesignTokens.green
                      : DesignTokens.textSecondary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
            ),
            child: Row(
              children: [
                Icon(
                  readyForRetest ? Icons.check_circle_outline : Icons.timelapse,
                  size: 16,
                  color: readyForRetest
                      ? DesignTokens.green
                      : DesignTokens.textSecondary,
                ),
                const SizedBox(width: DesignTokens.space8),
                Expanded(
                  child: Text(
                    readyForRetest
                        ? '再テストの目安に達しました。もう一度受けて変化を確認しましょう。'
                        : '再テストの目安まであと $remainingForRetest 回。'
                            '回数が少ないうちは測り直しても誤差しか見えません。',
                    style: TextStyle(
                      color: readyForRetest
                          ? DesignTokens.green
                          : DesignTokens.textSecondary,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // このプランより新しいテスト結果があるなら、鍛えている領域が
          // 現在の弱点と食い違っている可能性がある。黙って古い配分を
          // 続けさせず、作り直しの導線をその場に出す。
          if (isStale) ...[
            const SizedBox(height: DesignTokens.space12),
            Container(
              padding: const EdgeInsets.all(DesignTokens.space12),
              decoration: BoxDecoration(
                color: DesignTokens.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                border: Border.all(
                  color: DesignTokens.amber.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.update,
                        size: 16,
                        color: DesignTokens.amber,
                      ),
                      SizedBox(width: DesignTokens.space8),
                      Expanded(
                        child: Text(
                          'このプランより新しいテスト結果があります。'
                          '弱点が変わっている場合、今の配分は最新の測定と'
                          'ずれています。',
                          style: TextStyle(
                            color: DesignTokens.amber,
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DesignTokens.space8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onRegenerate,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DesignTokens.amber,
                        side: BorderSide(
                          color: DesignTokens.amber.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: DesignTokens.space8,
                        ),
                      ),
                      child: const Text('最新の結果でプランを作り直す'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TargetCard extends StatelessWidget {
  final IqTrainingTarget target;
  final int currentLevel;
  final int doneThisWeek;
  final List<IqTrainingSession> recentSessions;
  final VoidCallback onStart;

  const _TargetCard({
    required this.target,
    required this.currentLevel,
    required this.doneThisWeek,
    required this.recentSessions,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final levelChanged = currentLevel != target.startLevel;
    final weeklyProgress =
        (doneThisWeek / target.weeklySessions).clamp(0.0, 1.0);

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
          Row(
            children: [
              Expanded(
                child: Text(
                  target.category.labelJa,
                  style: const TextStyle(
                    color: DesignTokens.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.space12,
                  vertical: DesignTokens.space4,
                ),
                decoration: BoxDecoration(
                  color: DesignTokens.orange.withValues(alpha: 0.18),
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusCircle),
                ),
                child: Text(
                  'レベル $currentLevel',
                  style: const TextStyle(
                    color: DesignTokens.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space8),
          Text(
            target.category.descriptionJa,
            style: const TextStyle(
              color: DesignTokens.textSecondary,
              fontSize: 12,
              height: 1.6,
            ),
          ),
          const SizedBox(height: DesignTokens.space12),
          Container(
            padding: const EdgeInsets.all(DesignTokens.space12),
            decoration: BoxDecoration(
              color: DesignTokens.surface2,
              borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'テスト時のこの領域のスコア: IQ ${target.baselineIq}'
                  ' → 開始レベル ${target.startLevel}',
                  style: const TextStyle(
                    color: DesignTokens.textTertiary,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
                if (levelChanged) ...[
                  const SizedBox(height: DesignTokens.space4),
                  Text(
                    currentLevel > target.startLevel
                        ? '正答率が高かったためレベル $currentLevel に上げています。'
                        : '正答率が低かったためレベル $currentLevel に下げています。',
                    style: TextStyle(
                      color: currentLevel > target.startLevel
                          ? DesignTokens.green
                          : DesignTokens.amber,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: DesignTokens.space8),
                Text(
                  'コツ: ${target.category.trainingHintJa}',
                  style: const TextStyle(
                    color: DesignTokens.textSecondary,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.space16),
          Row(
            children: [
              Text(
                '今週 $doneThisWeek / ${target.weeklySessions} 回',
                style: const TextStyle(
                  color: DesignTokens.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: DesignTokens.space12),
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusCircle),
                  child: LinearProgressIndicator(
                    value: weeklyProgress,
                    backgroundColor: DesignTokens.surface3,
                    valueColor: AlwaysStoppedAnimation(
                      weeklyProgress >= 1
                          ? DesignTokens.green
                          : DesignTokens.orange,
                    ),
                    minHeight: 6,
                  ),
                ),
              ),
            ],
          ),
          if (recentSessions.isNotEmpty) ...[
            const SizedBox(height: DesignTokens.space12),
            Row(
              children: [
                const Text(
                  '直近: ',
                  style: TextStyle(
                    color: DesignTokens.textTertiary,
                    fontSize: 11,
                  ),
                ),
                ...recentSessions.reversed.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(right: DesignTokens.space4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.space8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (s.accuracy >= 0.85
                                ? DesignTokens.green
                                : s.accuracy <= 0.5
                                    ? DesignTokens.red
                                    : DesignTokens.textSecondary)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(
                          DesignTokens.radiusSmall,
                        ),
                      ),
                      child: Text(
                        '${(s.accuracy * 100).round()}%',
                        style: TextStyle(
                          color: s.accuracy >= 0.85
                              ? DesignTokens.green
                              : s.accuracy <= 0.5
                                  ? DesignTokens.red
                                  : DesignTokens.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: DesignTokens.space16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('トレーニング開始'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: DesignTokens.space12,
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
