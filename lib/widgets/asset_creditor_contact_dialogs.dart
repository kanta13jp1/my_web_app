import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/models/contact_log.dart';
import 'package:my_web_app/services/asset_creditor_contact_service.dart';

/// 個別の支払先への連絡テンプレ提示・コピー・合意内容記録モーダル (#3292 / #3288)。
class CreditorContactTemplateAndLogDialog extends StatefulWidget {
  final AssetLiabilityDebtRow row;
  final DateTime? dueDate;
  final DateTime baseDate;
  final List<CreditorContactLog> existingLogs;
  final Future<void> Function(CreditorContactLog log) onSaveLog;

  const CreditorContactTemplateAndLogDialog({
    super.key,
    required this.row,
    required this.dueDate,
    required this.baseDate,
    required this.existingLogs,
    required this.onSaveLog,
  });

  @override
  State<CreditorContactTemplateAndLogDialog> createState() =>
      _CreditorContactTemplateAndLogDialogState();
}

class _CreditorContactTemplateAndLogDialogState
    extends State<CreditorContactTemplateAndLogDialog> {
  CreditorContactTemplateKind _kind = CreditorContactTemplateKind.changeDueDate;
  CreditorContactChannel _channel = CreditorContactChannel.phone;
  late final TextEditingController _templateController;
  late final TextEditingController _repController;
  late final TextEditingController _agreementController;
  late final TextEditingController _noteController;
  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _templateController = TextEditingController(
      text: AssetCreditorContactService.buildTemplateText(
        row: widget.row,
        dueDate: widget.dueDate,
        kind: _kind,
      ),
    );
    _repController = TextEditingController();
    _agreementController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _templateController.dispose();
    _repController.dispose();
    _agreementController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _selectTemplateKind(CreditorContactTemplateKind nextKind) {
    setState(() {
      _kind = nextKind;
      _templateController.text = AssetCreditorContactService.buildTemplateText(
        row: widget.row,
        dueDate: widget.dueDate,
        kind: nextKind,
      );
    });
  }

  Future<void> _copyTemplate() async {
    await Clipboard.setData(ClipboardData(text: _templateController.text));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('連絡テンプレートをコピーしました。')),
    );
  }

  Future<void> _submit() async {
    if (_saving) {
      return;
    }
    final followUp = AssetCreditorContactService.suggestNextFollowUpDate(
      contactedAt: widget.baseDate,
      dueDate: widget.dueDate,
    );
    final log = CreditorContactLog(
      id: 'contact_${widget.row.id}_${DateTime.now().microsecondsSinceEpoch}',
      accountId: widget.row.id,
      accountName: widget.row.name,
      contactedAt: widget.baseDate,
      channel: _channel,
      templateKind: _kind,
      representative: _repController.text.trim(),
      agreedSummary: _agreementController.text.trim(),
      nextFollowUpDate: followUp,
      note: _noteController.text.trim(),
    );
    setState(() {
      _saving = true;
      _errorText = null;
    });
    try {
      await widget.onSaveLog(log);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(log);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _errorText = '連絡記録の保存に失敗しました: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final followUp = AssetCreditorContactService.suggestNextFollowUpDate(
      contactedAt: widget.baseDate,
      dueDate: widget.dueDate,
    );
    final followUpLabel = DateFormat('yyyy/MM/dd').format(followUp);

    return AlertDialog(
      title: Text('${widget.row.name} への連絡テンプレ・記録'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final kind in CreditorContactTemplateKind.values)
                    ChoiceChip(
                      key: Key('creditor_template_kind_${kind.name}'),
                      label: Text(kind.label),
                      selected: _kind == kind,
                      onSelected: (_) => _selectTemplateKind(kind),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('creditor_template_preview'),
                controller: _templateController,
                minLines: 4,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: '連絡テンプレート文面',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  key: const Key('creditor_template_copy_button'),
                  onPressed: _copyTemplate,
                  icon: const Icon(Icons.content_copy, size: 16),
                  label: const Text('テンプレをコピー'),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<CreditorContactChannel>(
                key: const Key('creditor_contact_channel_dropdown'),
                initialValue: _channel,
                decoration: const InputDecoration(
                  labelText: '連絡方法',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final channel in CreditorContactChannel.values)
                    DropdownMenuItem<CreditorContactChannel>(
                      value: channel,
                      child: Text(channel.label),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _channel = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('creditor_contact_rep_field'),
                controller: _repController,
                decoration: const InputDecoration(
                  labelText: '担当者・受付窓口（任意）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('creditor_contact_agreement_field'),
                controller: _agreementController,
                decoration: const InputDecoration(
                  labelText: '合意内容・約束（次回リマインド表示）',
                  hintText: '例: 支払日を28日へ変更承諾済み',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('creditor_contact_note_field'),
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: '補足メモ（任意）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '次回フォロー予定日: $followUpLabel',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F766E),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  key: const Key('creditor_contact_error_text'),
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  key: const Key('creditor_contact_retry_button'),
                  onPressed: _saving ? null : _submit,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('再送・再試行'),
                ),
              ],
              if (widget.existingLogs.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  '過去の連絡記録',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 4),
                for (final log in widget.existingLogs.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${DateFormat('yyyy/MM/dd').format(log.contactedAt)} '
                      '[${log.channel.label}/${log.templateKind.label}] '
                      '${log.agreedSummary.isNotEmpty ? log.agreedSummary : log.note}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('creditor_contact_cancel_button'),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton.icon(
          key: const Key('creditor_contact_save_button'),
          onPressed: _saving ? null : _submit,
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: Text(_saving ? '保存中...' : '連絡記録を保存'),
        ),
      ],
    );
  }
}

/// 期限超過・高金利先の一括連絡テンプレ生成・送信ログ管理ダイアログ (#3288)。
class BulkCreditorContactDialog extends StatefulWidget {
  final List<CreditorContactTask> tasks;
  final List<AssetLiabilityDebtRow> debtRows;
  final DateTime baseDate;
  final List<CreditorContactLog> allLogs;
  final Future<void> Function(CreditorContactLog log) onSaveLog;

  const BulkCreditorContactDialog({
    super.key,
    required this.tasks,
    required this.debtRows,
    required this.baseDate,
    required this.allLogs,
    required this.onSaveLog,
  });

  @override
  State<BulkCreditorContactDialog> createState() =>
      _BulkCreditorContactDialogState();
}

class _BulkCreditorContactDialogState extends State<BulkCreditorContactDialog> {
  CreditorContactTemplateKind _kind = CreditorContactTemplateKind.changeDueDate;
  bool _showHistory = false;
  bool _saving = false;
  String? _errorText;
  CreditorContactTask? _failedTask;
  late List<CreditorContactTask> _tasks;
  late List<CreditorContactLog> _logs;

  @override
  void initState() {
    super.initState();
    _tasks = List<CreditorContactTask>.from(widget.tasks);
    _logs = List<CreditorContactLog>.from(widget.allLogs);
  }

  AssetLiabilityDebtRow? _findRow(String accountId) {
    for (final row in widget.debtRows) {
      if (row.id == accountId) {
        return row;
      }
    }
    return null;
  }

  Future<void> _sendSingle(CreditorContactTask task) async {
    if (_saving) {
      return;
    }
    final followUp = AssetCreditorContactService.suggestNextFollowUpDate(
      contactedAt: widget.baseDate,
      dueDate: task.dueDate,
    );
    final log = CreditorContactLog(
      id: 'bulk_contact_${task.accountId}_${DateTime.now().microsecondsSinceEpoch}',
      accountId: task.accountId,
      accountName: task.accountName,
      contactedAt: widget.baseDate,
      channel: CreditorContactChannel.phone,
      templateKind: _kind,
      agreedSummary: '${_kind.label} について連絡送信済み',
      nextFollowUpDate: followUp,
    );
    setState(() {
      _saving = true;
      _errorText = null;
      _failedTask = null;
    });
    try {
      await widget.onSaveLog(log);
      if (!mounted) {
        return;
      }
      final updatedLogs = <CreditorContactLog>[log, ..._logs];
      setState(() {
        _saving = false;
        _logs = updatedLogs;
        _tasks = AssetCreditorContactService.buildContactTasks(
          rows: widget.debtRows,
          baseDate: widget.baseDate,
          logs: updatedLogs,
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _errorText = '${task.accountName} の送信記録に失敗しました: $error';
        _failedTask = task;
      });
    }
  }

  Future<void> _sendAllPending() async {
    final pending =
        _tasks.where((task) => !task.isContacted).toList(growable: false);
    for (final task in pending) {
      await _sendSingle(task);
      if (!mounted || _errorText != null) {
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _tasks.where((task) => !task.isContacted).length;

    return AlertDialog(
      title: const Text('期限超過・高金利先 一括連絡テンプレ'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    key: const Key('bulk_contact_tasks_tab'),
                    label: Text('対象一覧（未連絡 $pendingCount件）'),
                    selected: !_showHistory,
                    onSelected: (_) => setState(() => _showHistory = false),
                  ),
                  ChoiceChip(
                    key: const Key('bulk_contact_history_tab'),
                    label: Text('送信ログ一覧（${_logs.length}件）'),
                    selected: _showHistory,
                    onSelected: (_) => setState(() => _showHistory = true),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_errorText != null) ...[
                Text(
                  _errorText!,
                  key: const Key('bulk_contact_error_text'),
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_failedTask != null) ...[
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    key: const Key('bulk_contact_retry_button'),
                    onPressed: _saving ? null : () => _sendSingle(_failedTask!),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('再送'),
                  ),
                ],
                const SizedBox(height: 8),
              ],
              if (!_showHistory) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final kind in CreditorContactTemplateKind.values)
                      ChoiceChip(
                        key: Key('bulk_contact_kind_${kind.name}'),
                        label: Text(kind.label),
                        selected: _kind == kind,
                        onSelected: (_) => setState(() => _kind = kind),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_tasks.isEmpty)
                  const Text(
                    '現在、期限超過または高金利の連絡優先先はありません。',
                    style: TextStyle(fontSize: 12),
                  )
                else
                  for (final task in _tasks) ...[
                    Builder(
                      builder: (context) {
                        final row = _findRow(task.accountId);
                        final previewText = row == null
                            ? '${task.accountName} 宛て ${_kind.label} 相談テンプレート'
                            : AssetCreditorContactService.buildTemplateText(
                                row: row,
                                dueDate: task.dueDate,
                                kind: _kind,
                              );
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      task.accountName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (task.isOverdue)
                                      const Chip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text(
                                          '期限超過/当日',
                                          style: TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    if (task.isHighInterest)
                                      Chip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text(
                                          '年利 ${(task.annualRate * 100).toStringAsFixed(1)}%',
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    Chip(
                                      key: Key(
                                        'bulk_contact_status_${task.accountId}',
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      label: Text(
                                        task.status.label,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ),
                                  ],
                                ),
                                if (task.nextFollowUpDate != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '次回フォロー: ${DateFormat('yyyy/MM/dd').format(task.nextFollowUpDate!)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F766E),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  previewText,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: OutlinedButton.icon(
                                    key: Key(
                                      'bulk_contact_send_${task.accountId}',
                                    ),
                                    onPressed: _saving
                                        ? null
                                        : () => _sendSingle(task),
                                    icon: const Icon(
                                      Icons.send_outlined,
                                      size: 16,
                                    ),
                                    label: Text(
                                      task.isContacted ? '再連絡を記録' : '送信ログを保存',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
              ] else ...[
                if (_logs.isEmpty)
                  const Text(
                    '送信ログはまだ登録されていません。',
                    style: TextStyle(fontSize: 12),
                  )
                else
                  for (final log in _logs)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${log.accountName}（${log.templateKind.label} / ${log.channel.label}）',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '${DateFormat('yyyy/MM/dd').format(log.contactedAt)} '
                        '${log.agreedSummary.isNotEmpty ? log.agreedSummary : log.note}'
                        '${log.nextFollowUpDate == null ? '' : ' / 次回 ${DateFormat('yyyy/MM/dd').format(log.nextFollowUpDate!)}'}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('bulk_contact_close_button'),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
        if (!_showHistory && pendingCount > 0)
          FilledButton.icon(
            key: const Key('bulk_contact_send_all_button'),
            onPressed: _saving ? null : _sendAllPending,
            icon: const Icon(Icons.done_all, size: 18),
            label: Text(_saving ? '送信中...' : '未連絡を一括記録'),
          ),
      ],
    );
  }
}
