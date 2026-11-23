import 'package:flutter/material.dart';

import '../models/daily_journal_entry.dart';
import '../services/daily_journal_streak_service.dart';

class DailyJournalStreakPanel extends StatefulWidget {
  const DailyJournalStreakPanel({
    super.key,
    this.service = const DailyJournalStreakService(),
    this.debugNow,
  });

  final DailyJournalStreakService service;
  final DateTime? debugNow;

  @override
  State<DailyJournalStreakPanel> createState() =>
      _DailyJournalStreakPanelState();
}

class _DailyJournalStreakPanelState extends State<DailyJournalStreakPanel> {
  final TextEditingController _taskTitleController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();

  UserStreakProfile _profile = UserStreakProfile.empty();
  List<DailyJournalEntry> _entries = const <DailyJournalEntry>[];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _taskTitleController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await widget.service.loadProfile();
    final entries = await widget.service.loadEntries();
    if (!mounted) {
      return;
    }
    setState(() {
      _profile = profile;
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _recordCompletion() async {
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
    });
    final title = _taskTitleController.text.trim().isEmpty
        ? 'デイリー学習タスク'
        : _taskTitleController.text.trim();
    final note = _summaryController.text.trim();

    await widget.service.recordTaskCompletion(
      taskTitle: title,
      summary: note,
      now: widget.debugNow,
    );
    _taskTitleController.clear();
    _summaryController.clear();
    final nextProfile = await widget.service.loadProfile();
    final nextEntries = await widget.service.loadEntries();
    if (!mounted) {
      return;
    }
    setState(() {
      _profile = nextProfile;
      _entries = nextEntries;
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          label:
              '連続記録 ${_profile.currentStreak}日、最長 ${_profile.longestStreak}日、合計 ${_profile.totalCompletedTasks}件',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StreakStatBox(
                boxKey: const Key('journal_current_streak_box'),
                label: '現在のストリーク',
                value: '${_profile.currentStreak}日',
                accent: const Color(0xFFB45309),
              ),
              _StreakStatBox(
                boxKey: const Key('journal_longest_streak_box'),
                label: '最長ストリーク',
                value: '${_profile.longestStreak}日',
                accent: const Color(0xFF4F46E5),
              ),
              _StreakStatBox(
                boxKey: const Key('journal_total_tasks_box'),
                label: '累計完了タスク',
                value: '${_profile.totalCompletedTasks}件',
                accent: const Color(0xFF047857),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'タスク完了と日次ジャーナル自動記録',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('journal_task_title_input'),
                  controller: _taskTitleController,
                  decoration: const InputDecoration(
                    labelText: '完了したタスク名',
                    hintText: '例: FSRS復習セットを完了',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('journal_summary_input'),
                  controller: _summaryController,
                  decoration: const InputDecoration(
                    labelText: '振り返りメモ（省略時は自動要約）',
                    hintText: '学んだこと・次回メモ',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  key: const Key('journal_record_task_button'),
                  onPressed: _saving ? null : _recordCompletion,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(_saving ? '記録中...' : 'タスク完了を記録してストリーク更新'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '日次ジャーナル履歴',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_entries.isEmpty)
          Text(
            'まだジャーナル記録がありません。タスク完了を記録すると日次エントリが自動生成されます。',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          )
        else
          for (var i = 0; i < _entries.length; i++)
            Container(
              key: Key('journal_entry_$i'),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.event_note_outlined,
                        size: 16,
                        color: Color(0xFF4F46E5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _entries[i].dateKey,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _entries[i].taskTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _entries[i].summary,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _StreakStatBox extends StatelessWidget {
  const _StreakStatBox({
    required this.boxKey,
    required this.label,
    required this.value,
    required this.accent,
  });

  final Key boxKey;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: boxKey,
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: accent,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
