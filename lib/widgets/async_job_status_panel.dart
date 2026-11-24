import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/async_job.dart';
import '../services/async_job_service.dart';

enum AsyncJobFilterScope {
  all('すべて'),
  active('実行中・待機'),
  completed('完了'),
  failedOrCancelled('失敗・停止');

  const AsyncJobFilterScope(this.label);

  final String label;

  bool matches(AsyncJob job) {
    switch (this) {
      case AsyncJobFilterScope.all:
        return true;
      case AsyncJobFilterScope.active:
        return job.status.isActive;
      case AsyncJobFilterScope.completed:
        return job.status == AsyncJobStatus.completed;
      case AsyncJobFilterScope.failedOrCancelled:
        return job.status == AsyncJobStatus.failed ||
            job.status == AsyncJobStatus.cancelled;
    }
  }
}

class AsyncJobStatusPanel extends StatefulWidget {
  const AsyncJobStatusPanel({
    super.key,
    this.repository,
    this.initialJobs,
    this.autoSubscribeRealtime = true,
    this.onJobSelected,
  });

  final AsyncJobRepository? repository;
  final List<AsyncJob>? initialJobs;
  final bool autoSubscribeRealtime;
  final ValueChanged<AsyncJob>? onJobSelected;

  @override
  State<AsyncJobStatusPanel> createState() => _AsyncJobStatusPanelState();
}

class _AsyncJobStatusPanelState extends State<AsyncJobStatusPanel> {
  final TextEditingController _jobIdController = TextEditingController();
  AsyncJobRepository? _repo;
  StreamSubscription<List<AsyncJob>>? _realtimeSub;

  List<AsyncJob> _jobs = const <AsyncJob>[];
  AsyncJobFilterScope _filter = AsyncJobFilterScope.all;
  bool _loading = false;
  String? _errorText;
  String? _lookupMessage;

  AsyncJobRepository _resolveRepo() {
    return _repo ??= widget.repository ?? SupabaseAsyncJobRepository();
  }

  @override
  void initState() {
    super.initState();
    _repo = widget.repository;
    if (widget.initialJobs != null) {
      _jobs = widget.initialJobs!;
    } else {
      _loadJobs();
    }
    if (widget.autoSubscribeRealtime) {
      _subscribeRealtime();
    }
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _jobIdController.dispose();
    super.dispose();
  }

  void _subscribeRealtime() {
    try {
      _realtimeSub = _resolveRepo().watchJobs().listen(
        (jobs) {
          if (!mounted) return;
          setState(() {
            _jobs = jobs;
            _errorText = null;
          });
        },
        onError: (_) {},
      );
    } catch (_) {
      // Realtime unavailable in offline/uninitialized test harness; polling via refresh remains active.
    }
  }

  Future<void> _loadJobs() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final fetched = await _resolveRepo().listJobs();
      if (!mounted) return;
      setState(() {
        _jobs = fetched;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText = 'ジョブ一覧の取得に失敗しました: $e';
      });
    }
  }

  Future<void> _lookupByJobId() async {
    final targetId = _jobIdController.text.trim();
    if (targetId.isEmpty) {
      await _loadJobs();
      return;
    }
    setState(() {
      _loading = true;
      _errorText = null;
      _lookupMessage = null;
    });
    try {
      final found = await _resolveRepo().fetchJobStatus(targetId);
      if (!mounted) return;
      if (found == null) {
        setState(() {
          _loading = false;
          _lookupMessage = 'Job ID "$targetId" は見つかりませんでした';
        });
        return;
      }
      final updated = <AsyncJob>[
        found,
        ..._jobs.where((j) => j.id != found.id),
      ];
      setState(() {
        _jobs = updated;
        _loading = false;
        _lookupMessage = 'Job ID "${found.id}" (${found.status.label}) を取得しました';
      });
      widget.onJobSelected?.call(found);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText = 'ジョブ照会に失敗しました: $e';
      });
    }
  }

  Future<void> _cancelJob(AsyncJob job) async {
    try {
      final cancelled = await _resolveRepo().cancelJob(job.id);
      if (!mounted) return;
      setState(() {
        _jobs = _jobs
            .map((j) => j.id == cancelled.id ? cancelled : j)
            .toList(growable: false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = 'ジョブのキャンセルに失敗しました: $e';
      });
    }
  }

  Color _badgeForeground(BuildContext context, AsyncJobStatus status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (status) {
      case AsyncJobStatus.queued:
        return isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E);
      case AsyncJobStatus.running:
        return isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
      case AsyncJobStatus.completed:
        return isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);
      case AsyncJobStatus.failed:
        return isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);
      case AsyncJobStatus.cancelled:
        return isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    }
  }

  Color _badgeBackground(BuildContext context, AsyncJobStatus status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (status) {
      case AsyncJobStatus.queued:
        return isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
      case AsyncJobStatus.running:
        return isDark ? const Color(0xFF172554) : const Color(0xFFDBEAFE);
      case AsyncJobStatus.completed:
        return isDark ? const Color(0xFF022C22) : const Color(0xFFD1FAE5);
      case AsyncJobStatus.failed:
        return isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
      case AsyncJobStatus.cancelled:
        return isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleJobs = _jobs.where(_filter.matches).toList(growable: false);
    final theme = Theme.of(context);

    return Card(
      key: const ValueKey<String>('async_job_status_panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '非同期ジョブ実行状況 (${visibleJobs.length}/${_jobs.length})',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>('async_job_refresh_button'),
                  tooltip: '最新状態に更新',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: _loading ? null : _loadJobs,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 240,
                  child: TextField(
                    key: const ValueKey<String>('async_job_lookup_field'),
                    controller: _jobIdController,
                    decoration: const InputDecoration(
                      labelText: 'Job ID で照会',
                      hintText: 'job-id を入力',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _lookupByJobId(),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    key: const ValueKey<String>('async_job_lookup_button'),
                    onPressed: _loading ? null : _lookupByJobId,
                    icon: const Icon(Icons.search),
                    label: const Text('照会'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AsyncJobFilterScope.values
                  .map(
                    (scope) => ChoiceChip(
                      key: ValueKey<String>(
                        'async_job_filter_${scope.name}',
                      ),
                      label: Text(scope.label),
                      selected: _filter == scope,
                      onSelected: (_) {
                        setState(() {
                          _filter = scope;
                        });
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
            if (_loading) ...<Widget>[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_lookupMessage != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _lookupMessage!,
                key: const ValueKey<String>('async_job_lookup_message'),
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (_errorText != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                key: const ValueKey<String>('async_job_error_banner'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            if (visibleJobs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  '該当する非同期ジョブはありません',
                  key: ValueKey<String>('async_job_empty_state'),
                ),
              )
            else
              Column(
                children: visibleJobs
                    .map(
                      (job) => _buildJobCard(context, job),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, AsyncJob job) {
    final fg = _badgeForeground(context, job.status);
    final bg = _badgeBackground(context, job.status);
    final theme = Theme.of(context);
    final resultText = job.resultPayload != null
        ? const JsonEncoder.withIndent('  ').convert(job.resultPayload)
        : null;

    return Card(
      key: ValueKey<String>('async_job_card_${job.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(job.status.icon, size: 16, color: fg),
                      const SizedBox(width: 6),
                      Text(
                        job.status.label,
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  job.title,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  '${job.progressPercent}%',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'ID: ${job.id} / 種別: ${job.jobType}',
              style: theme.textTheme.bodySmall,
            ),
            if (job.status.isActive) ...<Widget>[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: job.progressPercent / 100.0),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: 48,
                  child: TextButton(
                    key: ValueKey<String>('async_job_cancel_${job.id}'),
                    onPressed: () => _cancelJob(job),
                    child: const Text('キャンセル'),
                  ),
                ),
              ),
            ],
            if (job.status == AsyncJobStatus.completed &&
                resultText != null) ...<Widget>[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  resultText,
                  key: ValueKey<String>('async_job_result_${job.id}'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
            if (job.status == AsyncJobStatus.failed &&
                job.errorMessage != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'エラー: ${job.errorMessage}',
                key: ValueKey<String>('async_job_err_${job.id}'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
