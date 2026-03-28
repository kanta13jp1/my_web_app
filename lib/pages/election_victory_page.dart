import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/local_election_plan.dart';
import '../services/local_election_plan_service.dart';

class ElectionVictoryPage extends StatefulWidget {
  const ElectionVictoryPage({super.key});

  @override
  State<ElectionVictoryPage> createState() => _ElectionVictoryPageState();
}

class _ElectionVictoryPageState extends State<ElectionVictoryPage> {
  final LocalElectionPlanService _service = const LocalElectionPlanService();

  LocalElectionPlanDashboard? _plan;
  bool _isLoading = true;
  String _selectedRegion = 'すべて';

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    final plan = await _service.loadPlan();
    if (!mounted) {
      return;
    }
    setState(() {
      _plan = plan;
      if (!plan.regionLabels.contains(_selectedRegion)) {
        _selectedRegion = 'すべて';
      }
      _isLoading = false;
    });
  }

  Future<void> _savePlan(LocalElectionPlanDashboard plan) async {
    final saved = await _service.savePlan(
      plan.copyWith(updatedAt: DateTime.now()),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _plan = saved;
    });
  }

  Future<void> _copySummary() async {
    final plan = _plan;
    if (plan == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: plan.buildClipboardSummary()));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('管理サマリーをクリップボードにコピーしました')),
    );
  }

  Future<void> _resetPlan(LocalElectionPlanTemplate template) async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('テンプレートを再適用'),
        content: Text(
          template == LocalElectionPlanTemplate.focused
              ? '重点配分テンプレートで現在の県連配分を上書きします。'
              : '均等配分テンプレートで現在の県連配分を上書きします。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('上書きする'),
          ),
        ],
      ),
    );
    if (shouldReset != true) {
      return;
    }

    final plan = await _service.resetPlan(template: template);
    if (!mounted) {
      return;
    }
    setState(() {
      _plan = plan;
      _selectedRegion = 'すべて';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          template == LocalElectionPlanTemplate.focused
              ? '重点配分テンプレートに戻しました'
              : '均等配分テンプレートに戻しました',
        ),
      ),
    );
  }

  Future<void> _editPrefecture(LocalElectionPrefecturePlan target) async {
    final additionalController = TextEditingController(
      text: '${target.additionalSeatTarget}',
    );
    final retentionController = TextEditingController(
      text: '${target.incumbentRetentionTarget}',
    );
    final focusController = TextEditingController(
      text: '${target.focusMunicipalityCount}',
    );
    final newCandidateController = TextEditingController(
      text: '${target.newCandidateTarget}',
    );
    final supportController = TextEditingController(
      text: '${target.closeRaceSupportRounds}',
    );
    final notesController = TextEditingController(text: target.notes);
    var selectedDeadline =
        planningMonthKeys.contains(target.endorsementDeadlineMonth)
            ? target.endorsementDeadlineMonth
            : planningMonthKeys.first;
    var endorsementConfirmed = target.endorsementConfirmed;

    final updated = await showDialog<LocalElectionPrefecturePlan>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('${target.prefecture} 県連プラン'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildNumberField(
                      controller: additionalController,
                      label: '純増目標',
                    ),
                    const SizedBox(height: 12),
                    _buildNumberField(
                      controller: retentionController,
                      label: '現職維持目標',
                    ),
                    const SizedBox(height: 12),
                    _buildNumberField(
                      controller: focusController,
                      label: '重点自治体数',
                    ),
                    const SizedBox(height: 12),
                    _buildNumberField(
                      controller: newCandidateController,
                      label: '新人擁立数',
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDeadline,
                      decoration: const InputDecoration(
                        labelText: '公認内定期限',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final monthKey in planningMonthKeys)
                          DropdownMenuItem<String>(
                            value: monthKey,
                            child: Text(formatMonthKey(monthKey)),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedDeadline = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildNumberField(
                      controller: supportController,
                      label: '接戦区支援回数',
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: endorsementConfirmed,
                      title: const Text('公認内定済み'),
                      subtitle: const Text('月次管理表の期限超過アラートから除外'),
                      onChanged: (value) {
                        setDialogState(() {
                          endorsementConfirmed = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'メモ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    target.copyWith(
                      additionalSeatTarget: _parsePositiveInt(
                        additionalController.text,
                      ),
                      incumbentRetentionTarget: _parsePositiveInt(
                        retentionController.text,
                      ),
                      focusMunicipalityCount: _parsePositiveInt(
                        focusController.text,
                      ),
                      newCandidateTarget: _parsePositiveInt(
                        newCandidateController.text,
                      ),
                      endorsementDeadlineMonth: selectedDeadline,
                      closeRaceSupportRounds: _parsePositiveInt(
                        supportController.text,
                      ),
                      endorsementConfirmed: endorsementConfirmed,
                      notes: notesController.text.trim(),
                    ),
                  );
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );

    additionalController.dispose();
    retentionController.dispose();
    focusController.dispose();
    newCandidateController.dispose();
    supportController.dispose();
    notesController.dispose();

    if (updated == null || _plan == null) {
      return;
    }

    final next = [
      for (final item in _plan!.prefectures)
        if (item.prefecture == updated.prefecture) updated else item,
    ];
    await _savePlan(_plan!.copyWith(prefectures: next));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${updated.prefecture} の計画を保存しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;

    return Scaffold(
      appBar: AppBar(
        title: const Text('統一地方選700 必達管理室'),
        actions: [
          IconButton(
            onPressed: plan == null ? null : _copySummary,
            tooltip: '管理サマリーをコピー',
            icon: const Icon(Icons.content_copy),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'focused') {
                _resetPlan(LocalElectionPlanTemplate.focused);
              } else if (value == 'balanced') {
                _resetPlan(LocalElectionPlanTemplate.balanced);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'focused',
                child: Text('重点配分テンプレートへ戻す'),
              ),
              PopupMenuItem<String>(
                value: 'balanced',
                child: Text('均等配分テンプレートへ戻す'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading || plan == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPlan,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeroCard(plan),
                  const SizedBox(height: 16),
                  _buildAlertStrip(plan),
                  const SizedBox(height: 24),
                  _buildSummaryGrid(plan),
                  const SizedBox(height: 24),
                  _buildTopPrioritySection(plan),
                  const SizedBox(height: 24),
                  _buildMonthlySection(plan),
                  const SizedBox(height: 24),
                  _buildRegionFilter(plan),
                  const SizedBox(height: 12),
                  ...plan
                      .prefecturesForRegion(_selectedRegion)
                      .map(_buildPrefectureCard),
                  const SizedBox(height: 24),
                  Text(
                    '注記: 初期配分と月次KPIはテンプレート計算です。'
                    '2026年4月から2027年3月までの管理ボードとして、各県連の実数で上書きして使う前提です。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeroCard(LocalElectionPlanDashboard plan) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '2027年春の統一地方選に向けた管理型ダッシュボード',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '現在 ${plan.currentLocalMembers}人から '
              '${plan.targetLocalMembers}人へ。'
              '必要純増 ${plan.requiredNetIncrease}人を、'
              '県連別配分と月次KPIで管理します。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildHeroMetric(
                  label: '現在',
                  value: '${plan.currentLocalMembers}',
                  color: const Color(0xFF0F766E),
                ),
                _buildHeroMetric(
                  label: '目標',
                  value: '${plan.targetLocalMembers}',
                  color: const Color(0xFF2563EB),
                ),
                _buildHeroMetric(
                  label: '必要純増',
                  value: '${plan.requiredNetIncrease}',
                  color: const Color(0xFFB91C1C),
                ),
                _buildHeroMetric(
                  label: '2023実績',
                  value:
                      '${plan.previousUnifiedElectionFirstHalfWins}+${plan.previousUnifiedElectionSecondHalfWins}',
                  color: const Color(0xFF7C3AED),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertStrip(LocalElectionPlanDashboard plan) {
    final gap = plan.allocationGap;
    final overdue = plan.overdueEndorsementCount();
    final dueSoon = plan.dueSoonEndorsementCount();
    final gapLabel = gap >= 0 ? '未配分ギャップ $gap人' : '超過配分 ${gap.abs()}人';
    final color = gap == 0 && overdue == 0
        ? Colors.green
        : overdue > 0 || gap != 0
            ? Colors.red
            : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              gap == 0 && overdue == 0
                  ? '県連配分は必要純増 ${plan.requiredNetIncrease}人を満たしています。'
                      '次は公認内定の前倒しと月次レビューの固定化です。'
                  : '$gapLabel、期限超過県連 $overdue、'
                      '60日以内に期限到来 $dueSoon。'
                      '「700」の看板ではなく、月次レビューで詰める運用が必要です。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(LocalElectionPlanDashboard plan) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildSummaryCard(
          title: '県連配分済み純増',
          value: '${plan.allocatedNetIncrease}',
          subtitle: '必要 ${plan.requiredNetIncrease} に対して',
          color: const Color(0xFF0F766E),
        ),
        _buildSummaryCard(
          title: '現職維持目標',
          value: '${plan.totalIncumbentRetentionTarget}',
          subtitle: '県連入力の合計値',
          color: const Color(0xFFB45309),
        ),
        _buildSummaryCard(
          title: '重点自治体',
          value: '${plan.totalFocusMunicipalityCount}',
          subtitle: '全国合計',
          color: const Color(0xFF1D4ED8),
        ),
        _buildSummaryCard(
          title: '新人擁立',
          value: '${plan.totalNewCandidateTarget}',
          subtitle: '全国合計',
          color: const Color(0xFF7C3AED),
        ),
        _buildSummaryCard(
          title: '公認内定済み県連',
          value: '${plan.confirmedEndorsementCount}/${plan.prefectures.length}',
          subtitle: '期限管理に使用',
          color: const Color(0xFF0F766E),
        ),
        _buildSummaryCard(
          title: '接戦区支援回数',
          value: '${plan.totalCloseRaceSupportRounds}',
          subtitle: '全国合計',
          color: const Color(0xFFBE123C),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(subtitle),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopPrioritySection(LocalElectionPlanDashboard plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '重点県連',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in plan.topPriorityPrefectures(limit: 8))
              SizedBox(
                width: 250,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.prefecture,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '純増 ${item.additionalSeatTarget} / 新人 ${item.newCandidateTarget}',
                        ),
                        Text(
                          '重点自治体 ${item.focusMunicipalityCount} / 支援 ${item.closeRaceSupportRounds}回',
                        ),
                        Text(
                          '公認内定期限 ${formatMonthKey(item.endorsementDeadlineMonth)}',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthlySection(LocalElectionPlanDashboard plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '月次KPI',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          '2026年4月から2027年3月までの累計管理です。'
          '公認内定は「その月に期限到来する県連数」を別列で表示します。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('月')),
              DataColumn(label: Text('現職維持累計')),
              DataColumn(label: Text('重点自治体累計')),
              DataColumn(label: Text('新人擁立累計')),
              DataColumn(label: Text('内定期限到来')),
              DataColumn(label: Text('内定期限累計')),
              DataColumn(label: Text('接戦区支援累計')),
            ],
            rows: [
              for (final month in plan.monthlyCheckpoints)
                DataRow(
                  cells: [
                    DataCell(Text(month.label)),
                    DataCell(
                      Text('${month.cumulativeIncumbentRetentionTarget}'),
                    ),
                    DataCell(Text('${month.cumulativeFocusMunicipalityCount}')),
                    DataCell(Text('${month.cumulativeNewCandidateTarget}')),
                    DataCell(Text('${month.endorsementsDueThisMonth}県連')),
                    DataCell(Text('${month.cumulativeEndorsementsDue}県連')),
                    DataCell(Text('${month.cumulativeCloseRaceSupportRounds}')),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegionFilter(LocalElectionPlanDashboard plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '県連別配分',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final label in plan.regionLabels)
              ChoiceChip(
                label: Text(label),
                selected: _selectedRegion == label,
                onSelected: (_) {
                  setState(() {
                    _selectedRegion = label;
                  });
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrefectureCard(LocalElectionPrefecturePlan plan) {
    final now = DateTime.now();
    final overdue = plan.isEndorsementOverdue(now);
    final dueSoon = plan.isEndorsementDueSoon(now);
    final accent = overdue
        ? Colors.red
        : dueSoon
            ? Colors.orange
            : plan.endorsementConfirmed
                ? Colors.green
                : Colors.blueGrey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${plan.prefecture} 県連',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(plan.region),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _editPrefecture(plan),
                  icon: const Icon(Icons.edit),
                  label: const Text('編集'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetricChip('純増', '${plan.additionalSeatTarget}'),
                _buildMetricChip('現職維持', '${plan.incumbentRetentionTarget}'),
                _buildMetricChip('重点自治体', '${plan.focusMunicipalityCount}'),
                _buildMetricChip('新人', '${plan.newCandidateTarget}'),
                _buildMetricChip(
                  '公認内定期限',
                  formatMonthKey(plan.endorsementDeadlineMonth),
                  color: accent,
                ),
                _buildMetricChip('接戦区支援', '${plan.closeRaceSupportRounds}回'),
                _buildMetricChip(
                  '内定状況',
                  plan.endorsementConfirmed
                      ? '完了'
                      : overdue
                          ? '期限超過'
                          : dueSoon
                              ? '期限接近'
                              : '進行中',
                  color: accent,
                ),
              ],
            ),
            if (plan.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                plan.notes,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, {Color? color}) {
    final chipColor = color ?? Colors.blueGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: chipColor.withValues(alpha: 0.95),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  int _parsePositiveInt(String raw) {
    final value = int.tryParse(raw.trim()) ?? 0;
    return clampPositiveInt(value);
  }
}
