import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/local_cleanup_result.dart';
import '../services/local_cleanup_service.dart';
import '../utils/web_image_downloader.dart';

class LocalSmartCleanupPage extends StatefulWidget {
  const LocalSmartCleanupPage({super.key});

  @override
  State<LocalSmartCleanupPage> createState() => _LocalSmartCleanupPageState();
}

class _LocalSmartCleanupPageState extends State<LocalSmartCleanupPage> {
  static const _weekDays = <String, String>{
    'SUN': '日曜',
    'MON': '月曜',
    'TUE': '火曜',
    'WED': '水曜',
    'THU': '木曜',
    'FRI': '金曜',
    'SAT': '土曜',
  };

  static const _defaultReportPath =
      r'G:\マイドライブ\C-drive-archive\cleanup-reports\duplicate-report-latest.csv';
  static const _defaultApprovalPath =
      r'G:\マイドライブ\C-drive-archive\cleanup-reports\cleanup-approval-latest.csv';
  static const _reportCommand =
      r'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\kanta\Scripts\SmartCleanup\Invoke-SmartCleanup.ps1"';
  static const _applyCommand =
      r'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\kanta\Scripts\SmartCleanup\Invoke-ApprovedCleanup.ps1" -Apply';
  static const _windowsReleaseUrl =
      'https://github.com/kanta13jp1/my_web_app/releases/latest/download/jibun-windows-companion.zip';
  static const _windowsWorkflowUrl =
      'https://github.com/kanta13jp1/my_web_app/actions/workflows/windows-companion-build.yml';
  static const _windowsGuideUrl =
      'https://github.com/kanta13jp1/my_web_app/blob/main/docs/WINDOWS_COMPANION_APP.md';
  static const _trackingIssueUrl =
      'https://github.com/kanta13jp1/my_web_app/issues/1493';

  final LocalCleanupService _localCleanupService = const LocalCleanupService();
  final List<_DuplicateRow> _duplicates = <_DuplicateRow>[];
  final List<_ApprovalRow> _approvals = <_ApprovalRow>[];
  String? _reportFileName;
  String? _approvalFileName;
  String _statusText = 'CSVを読み込むと、重複候補・承認候補・定期実行コマンドを確認できます。';
  bool _isBusy = false;
  bool _isRunningLocalAction = false;
  int _selectedTab = 0;
  _CleanupFrequency _scheduleFrequency = _CleanupFrequency.weekly;
  _CleanupScheduleKind _scheduleKind = _CleanupScheduleKind.reportOnly;
  String _scheduleWeekday = 'SUN';
  int _scheduleDayOfMonth = 1;
  TimeOfDay _scheduleTime = const TimeOfDay(hour: 9, minute: 30);

  int get _duplicateGroupCount => _duplicates
      .map((row) => row.groupId)
      .where((id) => id > 0)
      .toSet()
      .length;

  int get _reviewableCount => _duplicates.where((row) => !row.isKeeper).length;

  double get _reviewableMb => _duplicates
      .where((row) => !row.isKeeper)
      .fold<double>(0, (total, row) => total + row.sizeMb);

  int get _approvedCount => _approvals.where((row) => row.approved).length;

  double get _approvedMb => _approvals
      .where((row) => row.approved)
      .fold<double>(0, (total, row) => total + row.sizeMb);

  Future<void> _pickDuplicateReport() async {
    await _pickCsvFile(
      onLoaded: (text, fileName) {
        final table = _CsvTable.parse(text);
        final rows = table.rows
            .map(_DuplicateRow.fromMap)
            .where((row) => row.path.isNotEmpty)
            .toList();
        setState(() {
          _duplicates
            ..clear()
            ..addAll(rows);
          _reportFileName = fileName;
          _selectedTab = 0;
          _statusText = rows.isEmpty
              ? '重複レポートに表示できる候補はありません。'
              : '${rows.length}件の重複行を読み込みました。';
        });
      },
    );
  }

  Future<void> _pickApprovalCsv() async {
    await _pickCsvFile(
      onLoaded: (text, fileName) {
        final table = _CsvTable.parse(text);
        final rows = table.rows
            .map(_ApprovalRow.fromMap)
            .where(
              (row) =>
                  row.localPath.isNotEmpty || row.googleCopyPath.isNotEmpty,
            )
            .toList();
        setState(() {
          _approvals
            ..clear()
            ..addAll(rows);
          _approvalFileName = fileName;
          _selectedTab = 1;
          _statusText = rows.isEmpty
              ? '承認候補はありません。現在のレポートは確認のみで安全です。'
              : '${rows.length}件の承認候補を読み込みました。';
        });
      },
    );
  }

  Future<void> _pickCsvFile({
    required void Function(String text, String fileName) onLoaded,
  }) async {
    setState(() => _isBusy = true);
    try {
      final result = await FilePicker.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: const <String>['csv'],
      );
      if (result == null || result.files.isEmpty) {
        return;
      }
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        throw const FormatException('選択したCSVを読み込めませんでした。');
      }
      final text = _decodeCsv(bytes);
      if (!mounted) {
        return;
      }
      onLoaded(text, file.name);
    } catch (error) {
      if (mounted) {
        _showMessage('CSVの読み込みに失敗しました: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  void _toggleApproval(int index, bool? value) {
    if (value == null || index < 0 || index >= _approvals.length) {
      return;
    }
    setState(() {
      _approvals[index] = _approvals[index].copyWith(approved: value);
      _statusText = value ? '承認候補を1件オンにしました。' : '承認候補を1件オフにしました。';
    });
  }

  void _downloadApprovalCsv() {
    downloadCsvFile(_buildApprovalCsv(), 'cleanup-approval-latest.csv');
    _showMessage('承認CSVを保存しました。');
  }

  Future<void> _copyApprovalCsv() async {
    await _copyText(_buildApprovalCsv(), '承認CSVをクリップボードへコピーしました。');
  }

  Future<void> _pickScheduleTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduleTime,
    );
    if (picked == null) {
      return;
    }
    setState(() => _scheduleTime = picked);
  }

  Future<void> _runLocalAction(
    String label,
    Future<LocalCleanupResult> Function() action,
  ) async {
    if (_isRunningLocalAction) {
      return;
    }
    setState(() => _isRunningLocalAction = true);
    try {
      final result = await action();
      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = result.success ? '$label が完了しました。' : '$label が完了しませんでした。';
      });
      _showMessage(result.displayMessage);
    } finally {
      if (mounted) {
        setState(() => _isRunningLocalAction = false);
      }
    }
  }

  void _openUrl(String url) {
    openWebUrl(url);
  }

  Future<void> _copyText(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    _showMessage(message);
  }

  String _buildApprovalCsv() {
    const headers = <String>[
      'Approved',
      'Action',
      'GroupId',
      'SizeMB',
      'Hash',
      'LocalPath',
      'GoogleCopyPath',
      'Note',
    ];
    final records = <List<String>>[
      headers,
      ..._approvals.map((row) => row.toCsvRow()),
    ];
    return records.map(_encodeCsvRow).join('\r\n');
  }

  String get _scheduleTaskName {
    return _scheduleKind == _CleanupScheduleKind.reportOnly
        ? 'Codex Smart Cleanup Report'
        : 'Codex Smart Cleanup Apply Approved';
  }

  String get _scheduleTaskRun {
    return _scheduleKind == _CleanupScheduleKind.reportOnly
        ? _reportCommand
        : _applyCommand;
  }

  String get _scheduleCreateCommand {
    final dayArg = switch (_scheduleFrequency) {
      _CleanupFrequency.daily => '',
      _CleanupFrequency.weekly => ' /D $_scheduleWeekday',
      _CleanupFrequency.monthly => ' /D $_scheduleDayOfMonth',
    };
    return 'schtasks.exe /Create /TN "$_scheduleTaskName" '
        '/TR \'$_scheduleTaskRun\' '
        '/SC ${_scheduleFrequency.schtasksName}$dayArg '
        '/ST ${_formatTaskTime(_scheduleTime)} /F';
  }

  String get _scheduleQueryCommand {
    return 'schtasks.exe /Query /TN "$_scheduleTaskName" /V /FO LIST';
  }

  String get _scheduleRunCommand {
    return 'schtasks.exe /Run /TN "$_scheduleTaskName"';
  }

  String get _scheduleDeleteCommand {
    return 'schtasks.exe /Delete /TN "$_scheduleTaskName" /F';
  }

  String get _scheduleSummary {
    final cadence = switch (_scheduleFrequency) {
      _CleanupFrequency.daily => '毎日',
      _CleanupFrequency.weekly =>
        _weekDays[_scheduleWeekday] ?? _scheduleWeekday,
      _CleanupFrequency.monthly => '毎月$_scheduleDayOfMonth日',
    };
    final action =
        _scheduleKind == _CleanupScheduleKind.reportOnly ? 'レポート生成' : '承認済み適用';
    return '$cadence ${_formatTaskTime(_scheduleTime)} / $action';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ローカルPCスマート整理'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(theme),
                    const SizedBox(height: 16),
                    _buildWindowsInstallPanel(theme),
                    const SizedBox(height: 16),
                    _buildMetrics(wide),
                    const SizedBox(height: 16),
                    _buildActionPanel(theme, wide),
                    const SizedBox(height: 16),
                    _buildSchedulePanel(theme, wide),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SegmentedButton<int>(
                        selected: <int>{_selectedTab},
                        segments: const <ButtonSegment<int>>[
                          ButtonSegment<int>(
                            value: 0,
                            icon: Icon(Icons.folder_open),
                            label: Text('重複'),
                          ),
                          ButtonSegment<int>(
                            value: 1,
                            icon: Icon(Icons.fact_check_outlined),
                            label: Text('承認'),
                          ),
                        ],
                        onSelectionChanged: (values) {
                          setState(() => _selectedTab = values.first);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _selectedTab == 0
                          ? _buildDuplicateSection(theme)
                          : _buildApprovalSection(theme),
                    ),
                    const SizedBox(height: 16),
                    _buildAutomationPanel(theme),
                    const SizedBox(height: 24),
                    Text(
                      'この画面はローカルファイルを直接削除しません。承認CSVを作成し、PowerShellスクリプトとWindowsタスクスケジューラで実行します。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.cleaning_services_outlined,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PC整理レポート',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _statusText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (_isBusy)
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildWindowsInstallPanel(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final supported = _localCleanupService.isSupported;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: supported
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                supported ? Icons.desktop_windows : Icons.install_desktop,
                color: supported
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  supported ? 'Windowsアプリ版で実行中' : 'Windowsアプリ版をインストール',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: supported ? colorScheme.onPrimaryContainer : null,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            supported
                ? 'このビルドではレポート生成、承認適用、スケジュール操作をアプリから直接実行できます。'
                : 'Windows版ではCドライブの重複スキャン、承認済みクリーンアップ、タスク登録をローカルで実行できます。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: supported
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => _openUrl(_windowsReleaseUrl),
                icon: const Icon(Icons.download_for_offline_outlined),
                label: const Text('最新版'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openUrl(_windowsWorkflowUrl),
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('ビルド'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openUrl(_windowsGuideUrl),
                icon: const Icon(Icons.article_outlined),
                label: const Text('手順'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openUrl(_trackingIssueUrl),
                icon: const Icon(Icons.task_alt),
                label: const Text('Issue #1493'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics(bool wide) {
    final tiles = <Widget>[
      _MetricTile(
        icon: Icons.folder_copy_outlined,
        label: '重複グループ',
        value: '$_duplicateGroupCount',
      ),
      _MetricTile(
        icon: Icons.rule_outlined,
        label: '確認対象',
        value: '$_reviewableCount',
        detail: _formatSize(_reviewableMb),
      ),
      _MetricTile(
        icon: Icons.verified_outlined,
        label: '承認済み',
        value: '$_approvedCount',
        detail: _formatSize(_approvedMb),
      ),
    ];

    if (wide) {
      return Row(
        children: [
          for (var index = 0; index < tiles.length; index++) ...[
            if (index > 0) const SizedBox(width: 12),
            Expanded(child: tiles[index]),
          ],
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: tiles
          .map(
            (tile) => SizedBox(
              width: 220,
              child: tile,
            ),
          )
          .toList(),
    );
  }

  Widget _buildActionPanel(ThemeData theme, bool wide) {
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _isBusy ? null : _pickDuplicateReport,
                icon: const Icon(Icons.upload_file),
                label: const Text('重複CSV'),
              ),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _pickApprovalCsv,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('承認CSV'),
              ),
              OutlinedButton.icon(
                onPressed: _downloadApprovalCsv,
                icon: const Icon(Icons.download),
                label: const Text('承認CSV保存'),
              ),
              OutlinedButton.icon(
                onPressed: _copyApprovalCsv,
                icon: const Icon(Icons.content_copy),
                label: const Text('承認CSVコピー'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/windows-app'),
                icon: const Icon(Icons.desktop_windows_outlined),
                label: const Text('Windows版'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (wide)
            Row(
              children: [
                Expanded(
                  child: _PathLine(
                    label: '重複',
                    value: _reportFileName ?? _defaultReportPath,
                    onCopy: () => _copyText(
                      _defaultReportPath,
                      '重複CSVの標準パスをコピーしました。',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PathLine(
                    label: '承認',
                    value: _approvalFileName ?? _defaultApprovalPath,
                    onCopy: () => _copyText(
                      _defaultApprovalPath,
                      '承認CSVの標準パスをコピーしました。',
                    ),
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                _PathLine(
                  label: '重複',
                  value: _reportFileName ?? _defaultReportPath,
                  onCopy: () => _copyText(
                    _defaultReportPath,
                    '重複CSVの標準パスをコピーしました。',
                  ),
                ),
                const SizedBox(height: 8),
                _PathLine(
                  label: '承認',
                  value: _approvalFileName ?? _defaultApprovalPath,
                  onCopy: () => _copyText(
                    _defaultApprovalPath,
                    '承認CSVの標準パスをコピーしました。',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDuplicateSection(ThemeData theme) {
    if (_duplicates.isEmpty) {
      return const _EmptyState(
        icon: Icons.folder_open,
        title: '重複CSVを読み込んでください',
        message: 'duplicate-report-latest.csvを選ぶと、ハッシュ一致の重複をグループで確認できます。',
      );
    }

    final groups = <int, List<_DuplicateRow>>{};
    for (final row in _duplicates) {
      groups.putIfAbsent(row.groupId, () => <_DuplicateRow>[]).add(row);
    }

    final entries = groups.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      key: const ValueKey<String>('duplicates'),
      children: [
        for (final entry in entries) ...[
          _DuplicateGroupPanel(groupId: entry.key, rows: entry.value),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildApprovalSection(ThemeData theme) {
    if (_approvals.isEmpty) {
      return const _EmptyState(
        icon: Icons.fact_check_outlined,
        title: '承認候補はありません',
        message: 'cleanup-approval-latest.csvに候補が出た時だけ、ここでApprovedを切り替えます。',
      );
    }

    return Column(
      key: const ValueKey<String>('approvals'),
      children: [
        for (var index = 0; index < _approvals.length; index++) ...[
          _ApprovalRowTile(
            row: _approvals[index],
            onChanged: (value) => _toggleApproval(index, value),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildSchedulePanel(ThemeData theme, bool wide) {
    final colorScheme = theme.colorScheme;
    final controls = <Widget>[
      _ScheduleControl(
        label: '頻度',
        child: SegmentedButton<_CleanupFrequency>(
          selected: <_CleanupFrequency>{_scheduleFrequency},
          segments: const <ButtonSegment<_CleanupFrequency>>[
            ButtonSegment<_CleanupFrequency>(
              value: _CleanupFrequency.daily,
              icon: Icon(Icons.today_outlined),
              label: Text('毎日'),
            ),
            ButtonSegment<_CleanupFrequency>(
              value: _CleanupFrequency.weekly,
              icon: Icon(Icons.view_week_outlined),
              label: Text('毎週'),
            ),
            ButtonSegment<_CleanupFrequency>(
              value: _CleanupFrequency.monthly,
              icon: Icon(Icons.calendar_month_outlined),
              label: Text('毎月'),
            ),
          ],
          onSelectionChanged: (values) {
            setState(() => _scheduleFrequency = values.first);
          },
        ),
      ),
      if (_scheduleFrequency == _CleanupFrequency.weekly)
        _ScheduleControl(
          label: '曜日',
          child: DropdownButtonFormField<String>(
            initialValue: _scheduleWeekday,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: _weekDays.entries
                .map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _scheduleWeekday = value);
              }
            },
          ),
        ),
      if (_scheduleFrequency == _CleanupFrequency.monthly)
        _ScheduleControl(
          label: '日付',
          child: DropdownButtonFormField<int>(
            initialValue: _scheduleDayOfMonth,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: List<DropdownMenuItem<int>>.generate(
              28,
              (index) => DropdownMenuItem<int>(
                value: index + 1,
                child: Text('${index + 1}日'),
              ),
            ),
            onChanged: (value) {
              if (value != null) {
                setState(() => _scheduleDayOfMonth = value);
              }
            },
          ),
        ),
      _ScheduleControl(
        label: '時刻',
        child: OutlinedButton.icon(
          onPressed: _pickScheduleTime,
          icon: const Icon(Icons.schedule),
          label: Text(_formatTaskTime(_scheduleTime)),
        ),
      ),
      _ScheduleControl(
        label: '内容',
        child: SegmentedButton<_CleanupScheduleKind>(
          selected: <_CleanupScheduleKind>{_scheduleKind},
          segments: const <ButtonSegment<_CleanupScheduleKind>>[
            ButtonSegment<_CleanupScheduleKind>(
              value: _CleanupScheduleKind.reportOnly,
              icon: Icon(Icons.assignment_outlined),
              label: Text('レポート'),
            ),
            ButtonSegment<_CleanupScheduleKind>(
              value: _CleanupScheduleKind.applyApproved,
              icon: Icon(Icons.recycling_outlined),
              label: Text('承認適用'),
            ),
          ],
          onSelectionChanged: (values) {
            setState(() => _scheduleKind = values.first);
          },
        ),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_repeat, color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '定期実行',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _scheduleSummary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < controls.length; index++) ...[
                  if (index > 0) const SizedBox(width: 12),
                  Expanded(child: controls[index]),
                ],
              ],
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: controls
                  .map(
                    (control) => SizedBox(
                      width: 260,
                      child: control,
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 14),
          _CommandLine(
            label: '登録/更新',
            command: _scheduleCreateCommand,
            onCopy: () => _copyText(
              _scheduleCreateCommand,
              'スケジュール登録コマンドをコピーしました。',
            ),
          ),
          const SizedBox(height: 8),
          _CommandLine(
            label: '状態確認',
            command: _scheduleQueryCommand,
            onCopy: () => _copyText(
              _scheduleQueryCommand,
              'スケジュール確認コマンドをコピーしました。',
            ),
          ),
          const SizedBox(height: 8),
          _CommandLine(
            label: '今すぐ実行',
            command: _scheduleRunCommand,
            onCopy: () => _copyText(
              _scheduleRunCommand,
              'スケジュール実行コマンドをコピーしました。',
            ),
          ),
          const SizedBox(height: 8),
          _CommandLine(
            label: '削除',
            command: _scheduleDeleteCommand,
            onCopy: () => _copyText(
              _scheduleDeleteCommand,
              'スケジュール削除コマンドをコピーしました。',
            ),
          ),
          if (_localCleanupService.isSupported) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _isRunningLocalAction
                      ? null
                      : () => _runLocalAction(
                            'スケジュール登録',
                            () => _localCleanupService.runGeneratedCommand(
                              _scheduleCreateCommand,
                              action: 'Schedule create',
                            ),
                          ),
                  icon: const Icon(Icons.event_available),
                  label: const Text('登録'),
                ),
                OutlinedButton.icon(
                  onPressed: _isRunningLocalAction
                      ? null
                      : () => _runLocalAction(
                            'スケジュール確認',
                            () => _localCleanupService.runGeneratedCommand(
                              _scheduleQueryCommand,
                              action: 'Schedule query',
                            ),
                          ),
                  icon: const Icon(Icons.search),
                  label: const Text('確認'),
                ),
                OutlinedButton.icon(
                  onPressed: _isRunningLocalAction
                      ? null
                      : () => _runLocalAction(
                            'スケジュール実行',
                            () => _localCleanupService.runGeneratedCommand(
                              _scheduleRunCommand,
                              action: 'Schedule run',
                            ),
                          ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('実行'),
                ),
                OutlinedButton.icon(
                  onPressed: _isRunningLocalAction
                      ? null
                      : () => _runLocalAction(
                            'スケジュール削除',
                            () => _localCleanupService.runGeneratedCommand(
                              _scheduleDeleteCommand,
                              action: 'Schedule delete',
                            ),
                          ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('削除'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAutomationPanel(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ローカル実行',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _CommandLine(
            label: 'レポート生成',
            command: _reportCommand,
            onCopy: () => _copyText(
              _reportCommand,
              'レポート生成コマンドをコピーしました。',
            ),
          ),
          const SizedBox(height: 8),
          _CommandLine(
            label: '承認適用',
            command: _applyCommand,
            onCopy: () => _copyText(
              _applyCommand,
              '承認適用コマンドをコピーしました。',
            ),
          ),
          if (_localCleanupService.isSupported) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _isRunningLocalAction
                      ? null
                      : () => _runLocalAction(
                            'レポート生成',
                            _localCleanupService.runReport,
                          ),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('レポート生成'),
                ),
                OutlinedButton.icon(
                  onPressed: _isRunningLocalAction
                      ? null
                      : () => _runLocalAction(
                            '承認適用',
                            _localCleanupService.applyApprovedCleanup,
                          ),
                  icon: const Icon(Icons.recycling_outlined),
                  label: const Text('承認適用'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleControl extends StatelessWidget {
  const _ScheduleControl({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _DuplicateGroupPanel extends StatelessWidget {
  const _DuplicateGroupPanel({
    required this.groupId,
    required this.rows,
  });

  final int groupId;
  final List<_DuplicateRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final reviewableMb = rows
        .where((row) => !row.isKeeper)
        .fold<double>(0, (total, row) => total + row.sizeMb);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Group $groupId',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${rows.length} files / ${_formatSize(reviewableMb)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final row in rows) ...[
            _DuplicateFileLine(row: row),
            if (row != rows.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _DuplicateFileLine extends StatelessWidget {
  const _DuplicateFileLine({required this.row});

  final _DuplicateRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final chipColor = row.isKeeper
        ? colorScheme.primaryContainer
        : row.recommendation == 'ReviewRemoveLocalCopy'
            ? colorScheme.errorContainer
            : colorScheme.tertiaryContainer;
    final chipTextColor = row.isKeeper
        ? colorScheme.onPrimaryContainer
        : row.recommendation == 'ReviewRemoveLocalCopy'
            ? colorScheme.onErrorContainer
            : colorScheme.onTertiaryContainer;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            row.isKeeper ? Icons.check_circle_outline : Icons.pending_actions,
            color: chipTextColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: chipColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        row.recommendationLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: chipTextColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${_formatSize(row.sizeMb)}  ${row.lastWriteTime}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  row.path,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalRowTile extends StatelessWidget {
  const _ApprovalRowTile({
    required this.row,
    required this.onChanged,
  });

  final _ApprovalRow row;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              row.approved ? colorScheme.primary : colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: row.approved,
            onChanged: onChanged,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${row.action} / Group ${row.groupId} / ${_formatSize(row.sizeMb)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                _LabeledPath(label: 'Local', value: row.localPath),
                const SizedBox(height: 4),
                _LabeledPath(label: 'Google', value: row.googleCopyPath),
                if (row.note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    row.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (detail != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          detail!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PathLine extends StatelessWidget {
  const _PathLine({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          IconButton(
            tooltip: 'コピー',
            onPressed: onCopy,
            icon: const Icon(Icons.content_copy, size: 18),
          ),
        ],
      ),
    );
  }
}

class _CommandLine extends StatelessWidget {
  const _CommandLine({
    required this.label,
    required this.command,
    required this.onCopy,
  });

  final String label;
  final String command;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                command,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'コピー',
            onPressed: onCopy,
            icon: const Icon(Icons.content_copy, size: 18),
          ),
        ],
      ),
    );
  }
}

class _LabeledPath extends StatelessWidget {
  const _LabeledPath({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      key: ValueKey<String>(title),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CsvTable {
  const _CsvTable(this.rows);

  final List<Map<String, String>> rows;

  factory _CsvTable.parse(String text) {
    final records = _parseRecords(text);
    if (records.isEmpty) {
      return const _CsvTable(<Map<String, String>>[]);
    }
    final headers = records.first
        .map((header) => header.replaceFirst('\ufeff', '').trim())
        .toList();
    final rows = <Map<String, String>>[];
    for (final record in records.skip(1)) {
      final row = <String, String>{};
      for (var index = 0; index < headers.length; index++) {
        row[headers[index]] = index < record.length ? record[index] : '';
      }
      if (row.values.any((value) => value.trim().isNotEmpty)) {
        rows.add(row);
      }
    }
    return _CsvTable(rows);
  }

  static List<List<String>> _parseRecords(String text) {
    final records = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var inQuotes = false;

    void finishCell() {
      row.add(cell.toString());
      cell.clear();
    }

    void finishRow() {
      finishCell();
      if (row.any((value) => value.trim().isNotEmpty)) {
        records.add(row);
      }
      row = <String>[];
    }

    for (var index = 0; index < text.length; index++) {
      final char = text[index];
      if (inQuotes) {
        if (char == '"') {
          if (index + 1 < text.length && text[index + 1] == '"') {
            cell.write('"');
            index++;
          } else {
            inQuotes = false;
          }
        } else {
          cell.write(char);
        }
        continue;
      }

      if (char == '"') {
        inQuotes = true;
      } else if (char == ',') {
        finishCell();
      } else if (char == '\n') {
        finishRow();
      } else if (char == '\r') {
        if (index + 1 >= text.length || text[index + 1] != '\n') {
          finishRow();
        }
      } else {
        cell.write(char);
      }
    }

    if (inQuotes || cell.isNotEmpty || row.isNotEmpty) {
      finishRow();
    }
    return records;
  }
}

class _DuplicateRow {
  const _DuplicateRow({
    required this.groupId,
    required this.recommendation,
    required this.sizeMb,
    required this.hash,
    required this.lastWriteTime,
    required this.path,
  });

  final int groupId;
  final String recommendation;
  final double sizeMb;
  final String hash;
  final String lastWriteTime;
  final String path;

  bool get isKeeper => recommendation == 'Keep';

  String get recommendationLabel {
    switch (recommendation) {
      case 'Keep':
        return '保持';
      case 'ReviewRemoveLocalCopy':
        return 'ローカル削除候補';
      case 'ReviewDuplicate':
        return '重複確認';
      default:
        return recommendation.isEmpty ? '未分類' : recommendation;
    }
  }

  factory _DuplicateRow.fromMap(Map<String, String> row) {
    return _DuplicateRow(
      groupId: _parseInt(_read(row, 'GroupId')),
      recommendation: _read(row, 'Recommendation'),
      sizeMb: _parseDouble(_read(row, 'SizeMB')),
      hash: _read(row, 'Hash'),
      lastWriteTime: _read(row, 'LastWriteTime'),
      path: _read(row, 'Path'),
    );
  }
}

class _ApprovalRow {
  const _ApprovalRow({
    required this.approved,
    required this.action,
    required this.groupId,
    required this.sizeMb,
    required this.hash,
    required this.localPath,
    required this.googleCopyPath,
    required this.note,
  });

  final bool approved;
  final String action;
  final int groupId;
  final double sizeMb;
  final String hash;
  final String localPath;
  final String googleCopyPath;
  final String note;

  _ApprovalRow copyWith({bool? approved}) {
    return _ApprovalRow(
      approved: approved ?? this.approved,
      action: action,
      groupId: groupId,
      sizeMb: sizeMb,
      hash: hash,
      localPath: localPath,
      googleCopyPath: googleCopyPath,
      note: note,
    );
  }

  List<String> toCsvRow() {
    return <String>[
      approved ? 'true' : 'false',
      action,
      '$groupId',
      sizeMb.toStringAsFixed(2),
      hash,
      localPath,
      googleCopyPath,
      note,
    ];
  }

  factory _ApprovalRow.fromMap(Map<String, String> row) {
    return _ApprovalRow(
      approved: _parseBool(_read(row, 'Approved')),
      action: _read(row, 'Action'),
      groupId: _parseInt(_read(row, 'GroupId')),
      sizeMb: _parseDouble(_read(row, 'SizeMB')),
      hash: _read(row, 'Hash'),
      localPath: _read(row, 'LocalPath'),
      googleCopyPath: _read(row, 'GoogleCopyPath'),
      note: _read(row, 'Note'),
    );
  }
}

enum _CleanupFrequency {
  daily('DAILY'),
  weekly('WEEKLY'),
  monthly('MONTHLY');

  const _CleanupFrequency(this.schtasksName);

  final String schtasksName;
}

enum _CleanupScheduleKind {
  reportOnly,
  applyApproved,
}

String _decodeCsv(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}

String _read(Map<String, String> row, String key) {
  return row[key]?.trim() ?? '';
}

int _parseInt(String value) {
  return int.tryParse(value.trim()) ?? 0;
}

double _parseDouble(String value) {
  return double.tryParse(value.trim()) ?? 0;
}

bool _parseBool(String value) {
  switch (value.trim().toLowerCase()) {
    case 'true':
    case 'yes':
    case 'y':
    case '1':
    case 'approved':
      return true;
    default:
      return false;
  }
}

String _formatSize(double sizeMb) {
  if (sizeMb >= 1024) {
    return '${(sizeMb / 1024).toStringAsFixed(2)} GB';
  }
  if (sizeMb >= 10) {
    return '${sizeMb.toStringAsFixed(1)} MB';
  }
  return '${sizeMb.toStringAsFixed(2)} MB';
}

String _formatTaskTime(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _encodeCsvRow(List<String> values) {
  return values.map(_encodeCsvCell).join(',');
}

String _encodeCsvCell(String value) {
  final normalized = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final needsQuote = normalized.contains(',') ||
      normalized.contains('"') ||
      normalized.contains('\n') ||
      normalized.startsWith(' ') ||
      normalized.endsWith(' ');
  final escaped = normalized.replaceAll('"', '""');
  return needsQuote ? '"$escaped"' : escaped;
}
