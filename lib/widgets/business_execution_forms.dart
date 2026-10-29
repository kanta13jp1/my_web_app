import 'package:flutter/material.dart';

import '../models/business_execution.dart';
import '../view_models/business_execution_controller.dart';

String _number(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : '$value';

Widget _field(
  TextEditingController controller,
  String label, {
  int limit = 120,
  bool numeric = false,
  int lines = 1,
  bool enabled = true,
}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        enabled: enabled,
        maxLength: limit,
        maxLines: lines,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : lines > 1
                ? TextInputType.multiline
                : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );

class BusinessExecutionPlanForm extends StatefulWidget {
  const BusinessExecutionPlanForm({
    super.key,
    required this.now,
    required this.saving,
    required this.onSave,
    required this.onCancel,
  });

  final DateTime now;
  final bool saving;
  final Future<void> Function(BusinessExecutionPlan) onSave;
  final VoidCallback onCancel;

  @override
  State<BusinessExecutionPlanForm> createState() =>
      _BusinessExecutionPlanFormState();
}

class _BusinessExecutionPlanFormState extends State<BusinessExecutionPlanForm> {
  final _issue = TextEditingController();
  final _owner = TextEditingController(text: '自分');
  final _outcome = TextEditingController();
  final _outcomeUnit = TextEditingController();
  final _outcomeTarget = TextEditingController();
  final _action = TextEditingController();
  final _actionUnit = TextEditingController();
  final _dailyTarget = TextEditingController();
  final _start = TextEditingController();
  final _due = TextEditingController();
  String? _error;
  late final String _id;

  @override
  void initState() {
    super.initState();
    _id = DateTime.now().microsecondsSinceEpoch.toString();
    _start.text = dayKey(widget.now);
    _due.text = dayKey(DateTime(widget.now.year, widget.now.month + 1, 0));
  }

  @override
  void dispose() {
    for (final controller in [
      _issue,
      _owner,
      _outcome,
      _outcomeUnit,
      _outcomeTarget,
      _action,
      _actionUnit,
      _dailyTarget,
      _start,
      _due,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    try {
      final plan = BusinessExecutionPlan(
        id: _id,
        issue: _issue.text.trim(),
        owner: _owner.text.trim(),
        outcome: _outcome.text.trim(),
        outcomeUnit: _outcomeUnit.text.trim(),
        outcomeTarget: double.tryParse(_outcomeTarget.text.trim()) ?? double.nan,
        action: _action.text.trim(),
        actionUnit: _actionUnit.text.trim(),
        dailyTarget: double.tryParse(_dailyTarget.text.trim()) ?? double.nan,
        startDate: _start.text.trim(),
        dueDate: _due.text.trim(),
      );
      setState(() => _error = null);
      await widget.onSave(plan);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('1. 課題と成果目標'),
        const SizedBox(height: 12),
        _field(
          _issue,
          '解決したい課題',
          limit: 500,
          lines: 3,
          enabled: !widget.saving,
        ),
        _field(_owner, '担当者（連絡は送信されません）', limit: 80, enabled: !widget.saving),
        _field(_outcome, '成果指標（KPI）例：月内の相談申込数', enabled: !widget.saving),
        _field(_outcomeUnit, '成果の単位 例：件', limit: 20, enabled: !widget.saving),
        _field(_outcomeTarget, '期間終了時の成果目標', numeric: true, limit: 20, enabled: !widget.saving),
        const Text('2. 毎日の行動'),
        const SizedBox(height: 12),
        _field(_action, '行動指標（KDI）例：顧客へのヒアリング', enabled: !widget.saving),
        _field(_actionUnit, '行動の単位 例：回', limit: 20, enabled: !widget.saving),
        _field(_dailyTarget, '1日あたりの行動目標', numeric: true, limit: 20, enabled: !widget.saving),
        _field(_start, '開始日 YYYY-MM-DD', limit: 10, enabled: !widget.saving),
        _field(_due, '期限 YYYY-MM-DD（開始日と同じ月）', limit: 10, enabled: !widget.saving),
        const Text(
          '開始日から期限まで毎日を対象にします。休日も含みます。'
          '成果は「大きいほどよい」指標の期間内累計値や到達値を使います。'
          '費用削減率など小さいほどよい指標には未対応です。',
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: widget.saving ? null : _save,
          child: Text(widget.saving ? '保存確認中…' : '計画を端末に保存'),
        ),
        TextButton(
          onPressed: widget.saving ? null : widget.onCancel,
          child: const Text('キャンセル（入力は破棄）'),
        ),
      ],
    );
  }
}

class BusinessExecutionDetail extends StatefulWidget {
  const BusinessExecutionDetail({
    super.key,
    required this.plan,
    required this.controller,
  });

  final BusinessExecutionPlan plan;
  final BusinessExecutionController controller;

  @override
  State<BusinessExecutionDetail> createState() => _BusinessExecutionDetailState();
}

class _BusinessExecutionDetailState extends State<BusinessExecutionDetail> {
  final _actual = TextEditingController();
  final _outcomeActual = TextEditingController();
  final _note = TextEditingController();
  final _reflection = TextEditingController();
  String? _day;
  String? _message;

  @override
  void initState() {
    super.initState();
    final dates = widget.plan.expectedDates(widget.controller.now());
    if (dates.isNotEmpty) _selectDay(dates.last);
    _reflection.text = widget.plan.reflection;
  }

  @override
  void didUpdateWidget(covariant BusinessExecutionDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_day == null) {
      final dates = widget.plan.expectedDates(widget.controller.now());
      if (dates.isNotEmpty) _selectDay(dates.last);
    }
  }

  void _selectDay(String day) {
    _day = day;
    final report = widget.plan.reports[day];
    _actual.text = report == null ? '' : _number(report.actual);
    _outcomeActual.text = report?.outcomeActual == null
        ? ''
        : _number(report!.outcomeActual!);
    _note.text = report?.note ?? '';
    _message = null;
  }

  @override
  void dispose() {
    _actual.dispose();
    _outcomeActual.dispose();
    _note.dispose();
    _reflection.dispose();
    super.dispose();
  }

  Future<void> _saveReport() async {
    if (_day == null) return;
    try {
      final outcomeText = _outcomeActual.text.trim();
      final report = BusinessDailyReport(
        actual: double.tryParse(_actual.text.trim()) ?? double.nan,
        outcomeActual: outcomeText.isEmpty
            ? null
            : double.tryParse(outcomeText) ?? double.nan,
        note: _note.text.trim(),
      );
      final saved = await widget.controller.report(widget.plan.id, _day!, report);
      if (mounted) {
        setState(() => _message = saved ? '日次実績を保存して読み戻しました。' : null);
      }
    } on FormatException catch (error) {
      setState(() => _message = error.message);
    }
  }

  Future<void> _saveReflection() async {
    final saved = await widget.controller.reflect(
      widget.plan.id,
      _reflection.text,
    );
    if (mounted) {
      setState(() => _message = saved ? '月次の振り返りを保存して読み戻しました。' : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final now = widget.controller.now();
    final dates = plan.expectedDates(now);
    final missing = plan.missingDates(now);
    final outcome = plan.latestOutcome;
    final saving = widget.controller.saving;
    final readOnly = plan.archived;
    final expired = dayKey(now).compareTo(plan.dueDate) > 0;
    final reports = plan.reports.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(plan.outcome, style: Theme.of(context).textTheme.titleLarge),
        TextButton(
          onPressed: saving
              ? null
              : () => widget.controller.setArchived(plan.id, !plan.archived),
          child: Text(
            readOnly ? 'この計画を再開' : '履歴を残してアーカイブ（未保存入力は破棄）',
          ),
        ),
        if (readOnly) const Text('アーカイブ済み・閲覧のみ'),
        Text('課題: ${plan.issue}'),
        Text('担当: ${plan.owner}'),
        Text('期間: ${plan.startDate}〜${plan.dueDate}'),
        Text(
          '成果目標: ${_number(plan.outcomeTarget)} ${plan.outcomeUnit}',
        ),
        Text(
          '毎日の行動: ${plan.action} / '
          '${_number(plan.dailyTarget)} ${plan.actionUnit}',
        ),
        const Divider(height: 32),
        Text(
          expired ? '期間終了・月次の振り返り' : '今月の途中経過',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          '行動実績の合計: ${_number(plan.totalActions)} ${plan.actionUnit}\n'
          '今日までの行動目標: '
          '${_number(dates.length * plan.dailyTarget)} ${plan.actionUnit}',
        ),
        Text(
          outcome == null
              ? '成果実績（KPI）は未入力です。'
              : '成果実績（${outcome.key}時点）: '
                  '${_number(outcome.value.outcomeActual!)} ${plan.outcomeUnit}'
                  ' / 目標 ${_number(plan.outcomeTarget)} ${plan.outcomeUnit}',
        ),
        const Text('成果実績は最新の入力値を表示し、日ごとの値を足し合わせません。'),
        Text('未入力: ${missing.length}日（今日を含む対象日のみ）'),
        if (missing.isNotEmpty) Text(missing.join(' / ')),
        const Text('未入力は0として扱いません。行動をしなかった日は実績0を記録できます。'),
        const Divider(height: 32),
        Text('日次の実績', style: Theme.of(context).textTheme.titleMedium),
        if (!readOnly && dates.isEmpty)
          const Text('計画の開始日を迎えると実績を入力できます。'),
        if (!readOnly && dates.isNotEmpty) ...[
          const Text('日付を切り替えると、この日の未保存入力は破棄されます。'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('report-date-$_day'),
            initialValue: _day,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '実績の日付',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final day in dates.reversed)
                DropdownMenuItem(
                  value: day,
                  child: Text(
                    '$day ${plan.reports.containsKey(day) ? '記録済み' : '未入力'}',
                  ),
                ),
            ],
            onChanged: saving
                ? null
                : (value) {
                    if (value != null) setState(() => _selectDay(value));
                  },
          ),
          const SizedBox(height: 12),
          _field(
            _actual,
            'この日の行動実績（${plan.actionUnit}）',
            numeric: true,
            limit: 20,
            enabled: !saving,
          ),
          _field(
            _outcomeActual,
            'この日時点の成果実績（任意・${plan.outcomeUnit}）',
            numeric: true,
            limit: 20,
            enabled: !saving,
          ),
          _field(
            _note,
            '日次の振り返り・次の一手',
            lines: 3,
            limit: 500,
            enabled: !saving,
          ),
          FilledButton(
            onPressed: saving || _day == null ? null : _saveReport,
            child: Text(
              plan.reports.containsKey(_day) ? 'この日の記録を更新' : 'この日の記録を保存',
            ),
          ),
        ],
        const Divider(height: 32),
        if (readOnly)
          Text('月次の振り返り: ${plan.reflection}')
        else ...[
        _field(
          _reflection,
          '月次の振り返り（続けること・変えること・次月の行動）',
          limit: 1000,
          lines: 4,
          enabled: !saving,
        ),
        FilledButton.tonal(
          onPressed: saving ? null : _saveReflection,
          child: const Text('月次の振り返りを保存'),
        ),
        ],
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(liveRegion: true, child: Text(_message!)),
          ),
        const Divider(height: 32),
        const Text('保存済みの日次記録'),
        if (reports.isEmpty) const Text('まだ実績がありません。'),
        for (final entry in reports)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.key}: ${_number(entry.value.actual)} '
                    '${plan.actionUnit}',
                  ),
                  if (entry.value.outcomeActual != null)
                    Text(
                      '成果: ${_number(entry.value.outcomeActual!)} '
                      '${plan.outcomeUnit}',
                    ),
                  if (entry.value.note.isNotEmpty) Text(entry.value.note),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
