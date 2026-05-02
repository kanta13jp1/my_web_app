import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/self_touch_tracker_service.dart';

class SelfTouchTrackerPage extends StatefulWidget {
  const SelfTouchTrackerPage({
    super.key,
    this.service = const SelfTouchTrackerService(),
  });

  final SelfTouchTrackerService service;

  @override
  State<SelfTouchTrackerPage> createState() => _SelfTouchTrackerPageState();
}

class _SelfTouchTrackerPageState extends State<SelfTouchTrackerPage> {
  final _noteController = TextEditingController();
  final _timeFormatter = DateFormat('M/d HH:mm');

  bool _loading = true;
  bool _saving = false;
  String _selectedTrigger = 'stuck';
  int _intensity = 3;
  List<SelfTouchEvent> _events = const <SelfTouchEvent>[];
  SelfTouchStats _stats = const SelfTouchStats(
    totalCount: 0,
    todayCount: 0,
    last7DaysCount: 0,
    last30MinutesCount: 0,
    dailyCounts: <DateTime, int>{},
    weeklyCounts: <DateTime, int>{},
  );

  static const List<_TriggerOption> _triggers = <_TriggerOption>[
    _TriggerOption(
      id: 'stuck',
      label: '行き詰まり',
      icon: Icons.psychology_alt_outlined,
      color: Color(0xFF3D5AFE),
    ),
    _TriggerOption(
      id: 'word_search',
      label: '言葉が出ない',
      icon: Icons.chat_bubble_outline,
      color: Color(0xFF0891B2),
    ),
    _TriggerOption(
      id: 'stress',
      label: '緊張',
      icon: Icons.monitor_heart_outlined,
      color: Color(0xFFE53935),
    ),
    _TriggerOption(
      id: 'boredom',
      label: '退屈',
      icon: Icons.hourglass_empty,
      color: Color(0xFFFF6B35),
    ),
    _TriggerOption(
      id: 'focus',
      label: '集中時',
      icon: Icons.center_focus_strong,
      color: Color(0xFF059669),
    ),
  ];

  _TriggerOption get _selectedTriggerOption => _triggers.firstWhere(
        (trigger) => trigger.id == _selectedTrigger,
        orElse: () => _triggers.first,
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final snapshot = await widget.service.loadSnapshot();
    if (!mounted) return;
    setState(() {
      _events = snapshot.events;
      _stats = snapshot.stats;
      _loading = false;
    });
  }

  Future<void> _record() async {
    if (_saving) return;
    setState(() => _saving = true);
    final trigger = _selectedTrigger;
    final intensity = _intensity;
    final note = _noteController.text;
    final snapshot = await widget.service.recordEvent(
      trigger: trigger,
      intensity: intensity,
      note: note,
    );
    if (!mounted) return;
    setState(() {
      _events = snapshot.events;
      _stats = snapshot.stats;
      _saving = false;
    });
    _noteController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('記録しました')),
    );
    if (snapshot.stats.shouldPromptReplacement) {
      await _showReplacementSheet();
    }
  }

  Future<void> _delete(SelfTouchEvent event) async {
    final snapshot = await widget.service.deleteEvent(id: event.id);
    if (!mounted) return;
    setState(() {
      _events = snapshot.events;
      _stats = snapshot.stats;
    });
  }

  Future<void> _showReplacementSheet() async {
    final trigger = _selectedTriggerOption;
    final plans = widget.service.replacementPlans(
      trigger: _selectedTrigger,
      intensity: _intensity,
    );
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: trigger.color.withValues(alpha: 0.12),
                      child: Icon(trigger.icon, color: trigger.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${trigger.label}の置き換え',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...plans.map(
                  (plan) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ReplacementPlanTile(plan: plan),
                  ),
                ),
                const Text(
                  '強い苦痛、抜毛、皮膚の傷、日常生活への支障がある場合は専門家へ相談してください。',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dailyBuckets = widget.service.dailyBuckets(stats: _stats, now: now);
    final weeklyBuckets = widget.service.weeklyBuckets(stats: _stats, now: now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('自己接触トラッカー'),
        actions: [
          IconButton(
            onPressed: _showReplacementSheet,
            icon: const Icon(Icons.self_improvement_outlined),
            tooltip: '行き詰まり・思考サポート',
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: '再読み込み',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStatsHeader(),
                const SizedBox(height: 12),
                _buildQuickRecordCard(),
                if (_stats.shouldPromptReplacement) ...[
                  const SizedBox(height: 12),
                  _buildPromptCard(),
                ],
                const SizedBox(height: 12),
                _buildFrequencyCard(
                  title: '日別頻度',
                  icon: Icons.calendar_view_week_outlined,
                  buckets: dailyBuckets,
                  accent: const Color(0xFF3D5AFE),
                ),
                const SizedBox(height: 12),
                _buildFrequencyCard(
                  title: '週別頻度',
                  icon: Icons.stacked_bar_chart,
                  buckets: weeklyBuckets,
                  accent: const Color(0xFF059669),
                ),
                const SizedBox(height: 12),
                _buildRecentEventsCard(),
              ],
            ),
    );
  }

  Widget _buildStatsHeader() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatPill(
          label: '今日',
          value: '${_stats.todayCount}',
          icon: Icons.today_outlined,
          color: const Color(0xFF3D5AFE),
        ),
        _StatPill(
          label: '7日',
          value: '${_stats.last7DaysCount}',
          icon: Icons.query_stats,
          color: const Color(0xFF059669),
        ),
        _StatPill(
          label: '30分',
          value: '${_stats.last30MinutesCount}',
          icon: Icons.timer_outlined,
          color: const Color(0xFFFF6B35),
        ),
        _StatPill(
          label: '累計',
          value: '${_stats.totalCount}',
          icon: Icons.storage_outlined,
          color: const Color(0xFF607D8B),
        ),
      ],
    );
  }

  Widget _buildQuickRecordCard() {
    final selected = _selectedTriggerOption;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(selected.icon, color: selected.color),
                const SizedBox(width: 8),
                Text(
                  'ワンタップ記録',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _triggers.map((trigger) {
                return ChoiceChip(
                  avatar: Icon(trigger.icon, size: 18),
                  label: Text(trigger.label),
                  selected: _selectedTrigger == trigger.id,
                  selectedColor: trigger.color.withValues(alpha: 0.16),
                  onSelected: (_) {
                    setState(() => _selectedTrigger = trigger.id);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('強さ $_intensity / 5'),
            Slider(
              value: _intensity.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: '$_intensity',
              onChanged: (value) => setState(() => _intensity = value.round()),
            ),
            TextField(
              controller: _noteController,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'メモ',
                prefixIcon: Icon(Icons.edit_note_outlined),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _record,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.touch_app_outlined),
                label: const Text('いま記録'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptCard() {
    return Card(
      color: const Color(0xFFFFF7ED),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline, color: Color(0xFFFF6B35)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _stats.last30MinutesCount >= 3
                    ? '30分以内の記録が増えています。手をふさぐ代替動作に切り替えます。'
                    : '今日の記録が増えています。短いリセットを入れます。',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: _showReplacementSheet,
              child: const Text('見る'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencyCard({
    required String title,
    required IconData icon,
    required List<SelfTouchFrequencyBucket> buckets,
    required Color accent,
  }) {
    final maxCount = buckets.fold<int>(
      1,
      (max, bucket) => bucket.count > max ? bucket.count : max,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            ...buckets.map((bucket) {
              final ratio = bucket.count / maxCount;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        bucket.label,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 10,
                          color: accent,
                          backgroundColor: accent.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${bucket.count}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentEventsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Color(0xFF607D8B)),
                const SizedBox(width: 8),
                Text('最近の記録', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            if (_events.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('まだ記録がありません')),
              )
            else
              ..._events.take(12).map((event) {
                final trigger = _triggers.firstWhere(
                  (item) => item.id == event.trigger,
                  orElse: () => _triggers.first,
                );
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: trigger.color.withValues(alpha: 0.12),
                    child: Icon(trigger.icon, color: trigger.color),
                  ),
                  title: Text('${trigger.label}  強さ${event.intensity}'),
                  subtitle: Text(
                    [
                      _timeFormatter.format(event.occurredAt),
                      if (event.note.isNotEmpty) event.note,
                    ].join('  /  '),
                  ),
                  trailing: IconButton(
                    onPressed: () => _delete(event),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: '削除',
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _TriggerOption {
  const _TriggerOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReplacementPlanTile extends StatelessWidget {
  const _ReplacementPlanTile({required this.plan});

  final SelfTouchReplacementPlan plan;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${plan.title}  ${plan.durationSeconds}秒',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...plan.steps.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('・'),
                    Expanded(child: Text(step)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
