import 'package:flutter/material.dart';

import '../application/dev_review_controller.dart';
import '../domain/dev_review_models.dart';

class DevReviewTrackingView extends StatefulWidget {
  const DevReviewTrackingView({
    super.key,
    required this.controller,
  });

  final DevReviewTrackingController controller;

  @override
  State<DevReviewTrackingView> createState() => _DevReviewTrackingViewState();
}

class _DevReviewTrackingViewState extends State<DevReviewTrackingView> {
  final TextEditingController _titleController = TextEditingController(
    text: 'リリース前レビュー (#2743)',
  );
  final TextEditingController _repoController = TextEditingController(
    text: 'kanta13jp1/my_web_app',
  );
  final TextEditingController _numberController = TextEditingController(
    text: '2743',
  );
  final TextEditingController _approverController = TextEditingController(
    text: 'tech-lead',
  );
  final TextEditingController _assigneeController = TextEditingController(
    text: 'developer',
  );
  final TextEditingController _filterAssigneeController =
      TextEditingController();

  String _targetType = 'pr';

  @override
  void dispose() {
    _titleController.dispose();
    _repoController.dispose();
    _numberController.dispose();
    _approverController.dispose();
    _assigneeController.dispose();
    _filterAssigneeController.dispose();
    super.dispose();
  }

  Future<void> _submitCreateSession() async {
    final targetNum = int.tryParse(_numberController.text.trim()) ?? 0;
    await widget.controller.createSession(
      title: _titleController.text,
      targetType: _targetType,
      githubRepo: _repoController.text,
      targetNumber: targetNum,
      approver: _approverController.text,
      assignee: _assigneeController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('開発レビュー承認・GitHub 連動トラッキング'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        actions: <Widget>[
          IconButton(
            key: const Key('dev_review_refresh_btn'),
            tooltip: '再読み込み',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: widget.controller.loadSessions,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (BuildContext context, Widget? child) {
          final state = widget.controller.state;
          if (state.isLoading && state.sessions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (state.errorMessage != null) ...<Widget>[
                      _FeedbackCard(
                        cardKey: const Key('dev_review_error_banner'),
                        message: state.errorMessage!,
                        reasons: state.blockedReasons,
                        isError: true,
                        onRetry: widget.controller.loadSessions,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (state.statusNotice != null) ...<Widget>[
                      _FeedbackCard(
                        cardKey: const Key('dev_review_status_banner'),
                        message: state.statusNotice!,
                        reasons: const <String>[],
                        isError: false,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _CreateReviewSessionCard(
                      titleController: _titleController,
                      repoController: _repoController,
                      numberController: _numberController,
                      approverController: _approverController,
                      assigneeController: _assigneeController,
                      targetType: _targetType,
                      isSubmitting: state.isSubmitting,
                      onTargetTypeChanged: (String? next) {
                        if (next != null) {
                          setState(() => _targetType = next);
                        }
                      },
                      onCreate: _submitCreateSession,
                    ),
                    const SizedBox(height: 16),
                    _FilterBarCard(
                      statusFilter: state.statusFilter,
                      assigneeController: _filterAssigneeController,
                      onStatusChanged: (String status) {
                        widget.controller.loadSessions(
                          statusFilter: status,
                          assigneeFilter: _filterAssigneeController.text,
                        );
                      },
                      onApplyAssignee: () {
                        widget.controller.loadSessions(
                          statusFilter: state.statusFilter,
                          assigneeFilter: _filterAssigneeController.text,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    if (state.sessions.isEmpty)
                      Card(
                        color: colorScheme.surfaceContainerLow,
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('登録済みの開発レビューセッションはありません。'),
                        ),
                      )
                    else
                      for (final session in state.sessions) ...<Widget>[
                        _SessionCard(
                          session: session,
                          isSubmitting: state.isSubmitting,
                          onApproveItem: (DevReviewChecklistItem item) {
                            widget.controller.updateItemStatus(
                              sessionId: session.id,
                              itemId: item.id,
                              status: DevReviewItemStatus.approved,
                              assignee: item.assignee,
                            );
                          },
                          onFlagItem: (DevReviewChecklistItem item) {
                            widget.controller.updateItemStatus(
                              sessionId: session.id,
                              itemId: item.id,
                              status: DevReviewItemStatus.changesRequested,
                              assignee: item.assignee,
                            );
                          },
                          onSyncGithub: () {
                            widget.controller.syncGithub(
                              sessionId: session.id,
                              state: session.githubSnapshot?.state ?? 'open',
                              reviewDecision:
                                  session.githubSnapshot?.reviewDecision ??
                                      'none',
                              fetchLive: true,
                            );
                          },
                          onAdvancePhase: () {
                            widget.controller.advancePhase(session: session);
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.cardKey,
    required this.message,
    required this.reasons,
    required this.isError,
    this.onRetry,
  });

  final Key cardKey;
  final String message;
  final List<String> reasons;
  final bool isError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg =
        isError ? colorScheme.errorContainer : colorScheme.secondaryContainer;
    final fg = isError
        ? colorScheme.onErrorContainer
        : colorScheme.onSecondaryContainer;
    return Semantics(
      liveRegion: true,
      child: Card(
        key: cardKey,
        color: bg,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                message,
                style:
                    Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg),
              ),
              for (final reason in reasons)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '• $reason',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: fg),
                  ),
                ),
              if (onRetry != null) ...<Widget>[
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('dev_review_retry_btn'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: fg,
                  ),
                  onPressed: onRetry,
                  child: const Text('再読み込み'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateReviewSessionCard extends StatelessWidget {
  const _CreateReviewSessionCard({
    required this.titleController,
    required this.repoController,
    required this.numberController,
    required this.approverController,
    required this.assigneeController,
    required this.targetType,
    required this.isSubmitting,
    required this.onTargetTypeChanged,
    required this.onCreate,
  });

  final TextEditingController titleController;
  final TextEditingController repoController;
  final TextEditingController numberController;
  final TextEditingController approverController;
  final TextEditingController assigneeController;
  final String targetType;
  final bool isSubmitting;
  final ValueChanged<String?> onTargetTypeChanged;
  final Future<void> Function() onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'レビューチェックリスト・テスト観点自動生成 (GitHub 連動)',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('dev_review_title_field'),
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'レビュー件名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    key: const Key('dev_review_target_type_dropdown'),
                    isExpanded: true,
                    initialValue: targetType,
                    decoration: const InputDecoration(
                      labelText: '対象種別',
                      border: OutlineInputBorder(),
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'pr',
                        child: Text('Pull Request'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'issue',
                        child: Text('Issue'),
                      ),
                    ],
                    onChanged: onTargetTypeChanged,
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: TextField(
                    key: const Key('dev_review_repo_field'),
                    controller: repoController,
                    decoration: const InputDecoration(
                      labelText: 'GitHub リポジトリ (owner/repo)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: TextField(
                    key: const Key('dev_review_number_field'),
                    controller: numberController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '番号 (#)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    key: const Key('dev_review_assignee_field'),
                    controller: assigneeController,
                    decoration: const InputDecoration(
                      labelText: '初期担当者',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    key: const Key('dev_review_approver_field'),
                    controller: approverController,
                    decoration: const InputDecoration(
                      labelText: '最終承認者',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                key: const Key('dev_review_create_btn'),
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: isSubmitting
                    ? null
                    : () {
                        onCreate();
                      },
                child: Text(isSubmitting ? '生成中...' : 'チェックリスト自動生成・登録'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBarCard extends StatelessWidget {
  const _FilterBarCard({
    required this.statusFilter,
    required this.assigneeController,
    required this.onStatusChanged,
    required this.onApplyAssignee,
  });

  final String statusFilter;
  final TextEditingController assigneeController;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onApplyAssignee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const filters = <(String, String)>[
      ('all', 'すべて'),
      ('pending', '未着手'),
      ('in_review', 'レビュー中'),
      ('changes_requested', '要修正'),
      ('approved', '承認済み'),
    ];
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '進行中指摘事項・担当者フィルタ',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final (value, label) in filters)
                  ChoiceChip(
                    key: Key('dev_review_filter_$value'),
                    label: Text(label),
                    selected: statusFilter == value,
                    onSelected: (_) => onStatusChanged(value),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 240,
                  child: TextField(
                    key: const Key('dev_review_filter_assignee_field'),
                    controller: assigneeController,
                    decoration: const InputDecoration(
                      labelText: '担当者で絞り込み',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                OutlinedButton(
                  key: const Key('dev_review_apply_filter_btn'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: onApplyAssignee,
                  child: const Text('絞り込み適用'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.isSubmitting,
    required this.onApproveItem,
    required this.onFlagItem,
    required this.onSyncGithub,
    required this.onAdvancePhase,
  });

  final DevReviewSession session;
  final bool isSubmitting;
  final ValueChanged<DevReviewChecklistItem> onApproveItem;
  final ValueChanged<DevReviewChecklistItem> onFlagItem;
  final VoidCallback onSyncGithub;
  final VoidCallback onAdvancePhase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final snapshot = session.githubSnapshot;
    final nextPhase = session.currentPhase.nextPhase;

    return Card(
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              session.title,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: <Widget>[
                Chip(label: Text('現在フェーズ: ${session.currentPhase.labelJa}')),
                Chip(
                  label: Text(
                    '承認進捗: ${session.approvedCount}/${session.items.length}',
                  ),
                ),
                Chip(label: Text('承認者: ${session.approver}')),
                if (snapshot != null)
                  Chip(
                    key: Key('dev_review_gh_badge_${session.id}'),
                    label: Text(
                      'GitHub #${snapshot.number}: '
                      '${snapshot.state} / ${snapshot.reviewDecision}',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            for (final item in session.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '[${item.kind.labelJa}] ${item.title}',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text('状態: ${item.status.labelJa}'),
                          Text('担当: ${item.assignee}'),
                          if (!item.isApproved)
                            TextButton(
                              key: Key(
                                'dev_review_approve_${session.id}_${item.id}',
                              ),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                              onPressed: isSubmitting
                                  ? null
                                  : () => onApproveItem(item),
                              child: const Text('承認する'),
                            ),
                          TextButton(
                            key: Key(
                              'dev_review_flag_${session.id}_${item.id}',
                            ),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed:
                                isSubmitting ? null : () => onFlagItem(item),
                            child: const Text('要修正'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                OutlinedButton(
                  key: Key('dev_review_sync_gh_${session.id}'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: isSubmitting ? null : onSyncGithub,
                  child: const Text('GitHub 承認同期'),
                ),
                if (nextPhase != null)
                  FilledButton(
                    key: Key('dev_review_advance_${session.id}'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: isSubmitting ? null : onAdvancePhase,
                    child: Text('${nextPhase.labelJa} へ進める'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
