import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/krisp_audio_quality_service.dart';

class KrispAudioQualityPage extends StatefulWidget {
  const KrispAudioQualityPage({super.key});

  @override
  State<KrispAudioQualityPage> createState() => _KrispAudioQualityPageState();
}

class _KrispAudioQualityPageState extends State<KrispAudioQualityPage> {
  final _service = const KrispAudioQualityService();
  KrispAudioScenario _selected = KrispAudioScenario.remoteMeeting;
  final Map<KrispAudioScenario, Set<int>> _checkedSteps = {
    for (final scenario in KrispAudioScenario.values) scenario: <int>{},
  };

  KrispAudioPlan get _plan => _service.planFor(_selected);

  Future<void> _copyPlan() async {
    await Clipboard.setData(
      ClipboardData(text: _service.buildShareText(_plan)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('KGI/CSF/KPIをコピーしました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final handoff = plan.scenario == KrispAudioScenario.aiCoachSdk
        ? _service.buildAiCoachHandoff()
        : null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: const Text('Krisp音声品質コックピット'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: '共有文をコピー',
            onPressed: _copyPlan,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Header(plan: plan),
          const SizedBox(height: 16),
          _ScenarioPicker(
            selected: _selected,
            onChanged: (scenario) => setState(() => _selected = scenario),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              final left = Column(
                children: [
                  _GoalPanel(plan: plan),
                  const SizedBox(height: 16),
                  _ChecklistPanel(
                    plan: plan,
                    checked: _checkedSteps[plan.scenario] ?? <int>{},
                    onChanged: (index, checked) {
                      setState(() {
                        final target = _checkedSteps[plan.scenario]!;
                        if (checked) {
                          target.add(index);
                        } else {
                          target.remove(index);
                        }
                      });
                    },
                  ),
                ],
              );
              final right = Column(
                children: [
                  _KpiPanel(plan: plan),
                  const SizedBox(height: 16),
                  _SdkPanel(plan: plan),
                  if (handoff != null) ...[
                    const SizedBox(height: 16),
                    _AiCoachHandoffPanel(handoff: handoff),
                  ],
                  const SizedBox(height: 16),
                  _RiskPanel(plan: plan),
                ],
              );
              if (!wide) {
                return Column(
                  children: [
                    left,
                    const SizedBox(height: 16),
                    right,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: left),
                  const SizedBox(width: 16),
                  Expanded(flex: 5, child: right),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.plan});

  final KrispAudioPlan plan;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFD7E3EA),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0C2030) : const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _scenarioIcon(plan.scenario),
              color: const Color(0xFF0369A1),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  plan.kgi,
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _ReadinessBadge(score: plan.readinessScore),
        ],
      ),
    );
  }
}

class _ScenarioPicker extends StatelessWidget {
  const _ScenarioPicker({
    required this.selected,
    required this.onChanged,
  });

  final KrispAudioScenario selected;
  final ValueChanged<KrispAudioScenario> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<KrispAudioScenario>(
      segments: const [
        ButtonSegment(
          value: KrispAudioScenario.remoteMeeting,
          icon: Icon(Icons.video_call_outlined),
          label: Text('会議'),
        ),
        ButtonSegment(
          value: KrispAudioScenario.podcast,
          icon: Icon(Icons.podcasts_outlined),
          label: Text('収録'),
        ),
        ButtonSegment(
          value: KrispAudioScenario.investorCall,
          icon: Icon(Icons.handshake_outlined),
          label: Text('面談'),
        ),
        ButtonSegment(
          value: KrispAudioScenario.aiCoachSdk,
          icon: Icon(Icons.developer_board_outlined),
          label: Text('SDK'),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (value) => onChanged(value.first),
      showSelectedIcon: false,
    );
  }
}

class _GoalPanel extends StatelessWidget {
  const _GoalPanel({required this.plan});

  final KrispAudioPlan plan;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'KGI / CSF',
      icon: Icons.account_tree_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan.kgi,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
          ),
          const SizedBox(height: 12),
          ...plan.csf.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: Color(0xFF0284C7),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistPanel extends StatelessWidget {
  const _ChecklistPanel({
    required this.plan,
    required this.checked,
    required this.onChanged,
  });

  final KrispAudioPlan plan;
  final Set<int> checked;
  final void Function(int index, bool checked) onChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '実行チェック',
      icon: Icons.fact_check_outlined,
      child: Column(
        children: [
          for (var i = 0; i < plan.setupSteps.length; i++)
            CheckboxListTile(
              value: checked.contains(i),
              onChanged: (value) => onChanged(i, value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(plan.setupSteps[i]),
            ),
        ],
      ),
    );
  }
}

class _KpiPanel extends StatelessWidget {
  const _KpiPanel({required this.plan});

  final KrispAudioPlan plan;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'KPI',
      icon: Icons.speed_outlined,
      child: Column(
        children: [
          for (final kpi in plan.kpis)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          kpi.label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text('${kpi.current}${kpi.unit} / ${kpi.target}'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: kpi.progress,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(999),
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFE2E8F0),
                    color: const Color(0xFF0EA5E9),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SdkPanel extends StatelessWidget {
  const _SdkPanel({required this.plan});

  final KrispAudioPlan plan;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Krisp連携',
      icon: Icons.hub_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(label: 'Mode', value: plan.sdkMode),
          _InfoRow(label: 'Issue', value: '#${plan.issueNumber}'),
          _InfoRow(label: 'Source', value: plan.sourceUrl),
          const SizedBox(height: 12),
          ...plan.qualityChecks.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.tune_outlined,
                    size: 18,
                    color: Color(0xFF0F766E),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskPanel extends StatelessWidget {
  const _RiskPanel({required this.plan});

  final KrispAudioPlan plan;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'リスク',
      icon: Icons.report_problem_outlined,
      child: Column(
        children: [
          for (final risk in plan.risks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_outlined,
                    size: 18,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(risk)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AiCoachHandoffPanel extends StatelessWidget {
  const _AiCoachHandoffPanel({required this.handoff});

  final KrispAiCoachHandoff handoff;

  @override
  Widget build(BuildContext context) {
    final blockers = handoff.blockers.toList();
    final statusColor = handoff.readyForSdkSpike
        ? const Color(0xFF059669)
        : const Color(0xFFD97706);
    return _Panel(
      title: 'AI coach handoff',
      icon: Icons.record_voice_over_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              handoff.readyForSdkSpike
                  ? 'Ready for SDK spike'
                  : 'Blocked by ${blockers.length} external SDK gate(s)',
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Gates',
            value: '${handoff.satisfiedGateCount}/${handoff.gates.length}',
          ),
          _InfoRow(label: 'Issue', value: '#${handoff.issueNumber}'),
          const SizedBox(height: 8),
          ...handoff.gates.map(
            (gate) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    gate.satisfied
                        ? Icons.check_circle_outline
                        : Icons.lock_outline,
                    size: 18,
                    color: gate.satisfied
                        ? const Color(0xFF059669)
                        : const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${gate.label} (${gate.owner})',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          gate.nextAction,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 24),
          Text(
            'Pipeline',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < handoff.pipeline.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: const Color(0xFFE0F2FE),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Color(0xFF0369A1),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${handoff.pipeline[i].label}: '
                      '${handoff.pipeline[i].input} -> '
                      '${handoff.pipeline[i].output}',
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

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFD7E3EA),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF0369A1)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _ReadinessBadge extends StatelessWidget {
  const _ReadinessBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 80
        ? const Color(0xFF059669)
        : score >= 60
            ? const Color(0xFF0284C7)
            : const Color(0xFFD97706);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$score',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          Text('pt', style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

IconData _scenarioIcon(KrispAudioScenario scenario) {
  switch (scenario) {
    case KrispAudioScenario.remoteMeeting:
      return Icons.video_call_outlined;
    case KrispAudioScenario.podcast:
      return Icons.podcasts_outlined;
    case KrispAudioScenario.investorCall:
      return Icons.handshake_outlined;
    case KrispAudioScenario.aiCoachSdk:
      return Icons.developer_board_outlined;
  }
}
