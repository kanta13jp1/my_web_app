import 'package:flutter/material.dart';
import 'package:my_web_app/services/maintenance_service.dart';

class MaintenanceManagementPage extends StatefulWidget {
  const MaintenanceManagementPage({super.key, this.service});

  final MaintenanceService? service;

  @override
  State<MaintenanceManagementPage> createState() =>
      _MaintenanceManagementPageState();
}

class _MaintenanceManagementPageState extends State<MaintenanceManagementPage> {
  late final MaintenanceService _service;
  List<MaintenanceWindow> _windows = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MaintenanceService();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _service.listWindows();
      if (!mounted) return;
      setState(() => _windows = rows);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditor([MaintenanceWindow? window]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _MaintenanceWindowDialog(
        service: _service,
        window: window,
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(MaintenanceWindow window) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('計画停止を削除'),
        content:
            Text('${_formatDateTime(window.startsAt.toLocal())} の予定を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.deleteWindow(window.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('削除しました')),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('計画停止管理'),
        actions: [
          IconButton(
            tooltip: '更新',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          IconButton(
            tooltip: '追加',
            icon: const Icon(Icons.add),
            onPressed: () => _openEditor(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SummaryCard(windows: _windows),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_error!),
                      ),
                    ),
                  if (_windows.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('登録済みの計画停止はありません。'),
                      ),
                    )
                  else
                    ..._windows.map(
                      (window) => _WindowCard(
                        window: window,
                        onEdit: () => _openEditor(window),
                        onDelete: () => _delete(window),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('計画停止を追加'),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.windows});

  final List<MaintenanceWindow> windows;

  @override
  Widget build(BuildContext context) {
    final active = windows.where((window) => window.isActive).length;
    final upcoming = windows
        .where((window) => window.startsAt.isAfter(DateTime.now()))
        .length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            _Metric(label: '登録', value: windows.length.toString()),
            _Metric(label: '停止中', value: active.toString()),
            _Metric(label: '予定', value: upcoming.toString()),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _WindowCard extends StatelessWidget {
  const _WindowCard({
    required this.window,
    required this.onEdit,
    required this.onDelete,
  });

  final MaintenanceWindow window;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          window.scope == 'system' ? Icons.public : Icons.extension,
          color: window.isActive ? colors.error : colors.primary,
        ),
        title: Text(
          '${window.scope == 'system' ? '全体' : window.affectedFeatures.join(', ')} '
          '${_formatDateTime(window.startsAt.toLocal())} - ${_formatDateTime(window.endsAt.toLocal())}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${window.severity} / ${window.noticeDaysBefore}日前通知\n${window.displayMessage}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: Wrap(
          children: [
            IconButton(
              tooltip: '編集',
              icon: const Icon(Icons.edit),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: '削除',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceWindowDialog extends StatefulWidget {
  const _MaintenanceWindowDialog({
    required this.service,
    this.window,
  });

  final MaintenanceService service;
  final MaintenanceWindow? window;

  @override
  State<_MaintenanceWindowDialog> createState() =>
      _MaintenanceWindowDialogState();
}

class _MaintenanceWindowDialogState extends State<_MaintenanceWindowDialog> {
  late String _scope;
  late String _severity;
  late int _noticeDays;
  late DateTime _startsAt;
  late DateTime _endsAt;
  late final TextEditingController _featuresController;
  late final TextEditingController _messageController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final window = widget.window;
    final now = DateTime.now();
    _scope = window?.scope ?? 'system';
    _severity = window?.severity ?? 'info';
    _noticeDays = window?.noticeDaysBefore ?? 3;
    _startsAt = window?.startsAt.toLocal() ?? now.add(const Duration(days: 3));
    _endsAt =
        window?.endsAt.toLocal() ?? now.add(const Duration(days: 3, hours: 2));
    _featuresController = TextEditingController(
      text: window?.affectedFeatures.join(', ') ?? '',
    );
    _messageController = TextEditingController(text: window?.messageJa ?? '');
  }

  @override
  void dispose() {
    _featuresController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool starts}) async {
    final current = starts ? _startsAt : _endsAt;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    final picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (starts) {
        _startsAt = picked;
        if (!_endsAt.isAfter(_startsAt)) {
          _endsAt = _startsAt.add(const Duration(hours: 2));
        }
      } else {
        _endsAt = picked;
      }
    });
  }

  Future<void> _save() async {
    final features = _featuresController.text
        .split(',')
        .map((item) => normalizeFeatureKey(item))
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (_scope == 'feature' && features.isEmpty) {
      _showError('影響機能を1つ以上入力してください。');
      return;
    }
    if (!_endsAt.isAfter(_startsAt)) {
      _showError('終了日時は開始日時より後にしてください。');
      return;
    }
    if (_messageController.text.trim().isEmpty) {
      _showError('メッセージを入力してください。');
      return;
    }
    setState(() => _saving = true);
    final current = widget.window;
    final window = MaintenanceWindow(
      id: current?.id ?? '',
      scope: _scope,
      affectedFeatures: _scope == 'system' ? const [] : features,
      startsAt: _startsAt,
      endsAt: _endsAt,
      noticeDaysBefore: _noticeDays,
      messageJa: _messageController.text.trim(),
      severity: _severity,
    );
    try {
      if (current == null) {
        await widget.service.createWindow(window);
      } else {
        await widget.service.updateWindow(window);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.window == null ? '計画停止を追加' : '計画停止を編集'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'system', label: Text('全体')),
                  ButtonSegment(value: 'feature', label: Text('機能別')),
                ],
                selected: {_scope},
                onSelectionChanged: (values) {
                  setState(() => _scope = values.first);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _featuresController,
                enabled: _scope == 'feature',
                decoration: const InputDecoration(
                  labelText: '影響機能',
                  hintText: 'ai-hub, blog-management',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDateTime(starts: true),
                      icon: const Icon(Icons.event),
                      label: Text('開始 ${_formatDateTime(_startsAt)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDateTime(starts: false),
                      icon: const Icon(Icons.event_available),
                      label: Text('終了 ${_formatDateTime(_endsAt)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _severity,
                decoration: const InputDecoration(
                  labelText: '重要度',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'info', child: Text('info')),
                  DropdownMenuItem(value: 'warning', child: Text('warning')),
                  DropdownMenuItem(value: 'critical', child: Text('critical')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _severity = value);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('事前通知'),
                  Expanded(
                    child: Slider(
                      value: _noticeDays.toDouble(),
                      min: 0,
                      max: 14,
                      divisions: 14,
                      label: '$_noticeDays日前',
                      onChanged: (value) {
                        setState(() => _noticeDays = value.round());
                      },
                    ),
                  ),
                  SizedBox(width: 56, child: Text('$_noticeDays日前')),
                ],
              ),
              TextField(
                controller: _messageController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '表示メッセージ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('キャンセル'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: const Text('保存'),
        ),
      ],
    );
  }
}

String _formatDateTime(DateTime value) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${value.year}/${two(value.month)}/${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}
