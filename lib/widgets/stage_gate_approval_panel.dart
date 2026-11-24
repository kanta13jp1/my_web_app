import 'package:flutter/material.dart';

import '../services/stage_gate_review_service.dart';

/// Admin panel displaying stage-gate approval requests, feedback actions, and
/// transition history (#2593).
class StageGateApprovalPanel extends StatefulWidget {
  const StageGateApprovalPanel({
    super.key,
    this.repository,
    this.initialReviews,
    this.initialHistory,
    this.initialIsAdmin = true,
  });

  final StageGateReviewRepository? repository;
  final List<StageGateReview>? initialReviews;
  final List<StageGateHistoryEntry>? initialHistory;
  final bool initialIsAdmin;

  @override
  State<StageGateApprovalPanel> createState() => _StageGateApprovalPanelState();
}

class _StageGateApprovalPanelState extends State<StageGateApprovalPanel> {
  StageGateReviewRepository? _lazyRepo;
  late List<StageGateReview> _reviews;
  late List<StageGateHistoryEntry> _history;
  late bool _isAdmin;
  bool _loading = false;
  bool _pendingOnly = false;
  String? _statusMessage;
  final Map<String, TextEditingController> _feedbackControllers =
      <String, TextEditingController>{};

  StageGateReviewRepository _repo() =>
      _lazyRepo ??= widget.repository ?? SupabaseStageGateReviewRepository();

  @override
  void initState() {
    super.initState();
    _reviews = List<StageGateReview>.from(
      widget.initialReviews ?? const <StageGateReview>[],
    );
    _history = List<StageGateHistoryEntry>.from(
      widget.initialHistory ?? const <StageGateHistoryEntry>[],
    );
    _isAdmin = widget.initialIsAdmin;
    if (widget.initialReviews == null) {
      _refresh();
    }
  }

  @override
  void dispose() {
    for (final controller in _feedbackControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(StageGateReview review) {
    return _feedbackControllers.putIfAbsent(
      review.id,
      () => TextEditingController(text: review.feedback),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _statusMessage = null;
    });
    try {
      final overview = await _repo().listReviews(
        statusFilter: _pendingOnly ? StageGateDecision.pending : null,
      );
      if (!mounted) return;
      setState(() {
        _reviews = overview.reviews;
        _history = overview.history;
        _isAdmin = overview.isAdmin;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'ステージゲート情報の取得に失敗しました: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _decide(
    StageGateReview review,
    StageGateDecision decision,
  ) async {
    final feedback = _controllerFor(review).text.trim();
    if (decision != StageGateDecision.approved && feedback.isEmpty) {
      setState(() {
        _statusMessage = '却下・差し戻し時はフィードバックを入力してください';
      });
      return;
    }

    setState(() {
      _loading = true;
      _statusMessage = null;
    });
    try {
      final updated = await _repo().decideReview(
        reviewId: review.id,
        decision: decision,
        feedback: feedback,
      );
      if (!mounted) return;
      setState(() {
        final idx = _reviews.indexWhere((item) => item.id == updated.id);
        if (idx >= 0) {
          _reviews[idx] = updated;
        } else {
          _reviews.insert(0, updated);
        }
        _history.insert(
          0,
          StageGateHistoryEntry(
            id: 'local-${_history.length + 1}',
            reviewId: updated.id,
            fromStage: review.currentStage,
            toStage: updated.targetStage,
            decision: decision.wireValue,
            feedback: feedback,
            createdAt: DateTime.now().toUtc(),
          ),
        );
        _statusMessage = '${review.sourceRef} を「${decision.label}」に更新しました';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = '判定の保存に失敗しました: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final visible = _pendingOnly
        ? _reviews
            .where((item) => item.status == StageGateDecision.pending)
            .toList()
        : _reviews;

    return Card(
      key: const ValueKey<String>('stage_gate_approval_panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'ステージゲート承認ワークフロー',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: OutlinedButton(
                    key: const ValueKey<String>('stage_gate_pending_filter'),
                    onPressed: () {
                      setState(() {
                        _pendingOnly = !_pendingOnly;
                      });
                    },
                    child: Text(_pendingOnly ? 'すべて表示' : '審査待ちのみ'),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: IconButton(
                    key: const ValueKey<String>('stage_gate_refresh_button'),
                    tooltip: 'ステージゲート一覧を更新',
                    onPressed: _loading ? null : _refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _isAdmin
                  ? '管理者権限で各フェーズ移行を承認・却下・差し戻しし、履歴を記録します。'
                  : 'あなたの申請済みステージゲート審査状況を確認できます（承認操作は管理者限定）。',
              style: theme.textTheme.bodySmall,
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                key: const ValueKey<String>('stage_gate_status_message'),
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFF0F172A),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (visible.isEmpty)
              Text(
                '表示対象のステージゲート申請はありません。',
                style: theme.textTheme.bodyMedium,
              )
            else
              ...visible.map(
                (review) => _buildReviewCard(context, review, isDark),
              ),
            if (_history.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '直近の承認履歴 (${_history.length}件)',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              ..._history.take(5).map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.history, size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${entry.fromStage.label} -> ${entry.toStage.label} '
                              '(${entry.decision})'
                              '${entry.feedback.isNotEmpty ? ': ${entry.feedback}' : ''}',
                              softWrap: true,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(
    BuildContext context,
    StageGateReview review,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final (Color fg, Color bg) = switch (review.status) {
      StageGateDecision.approved => isDark
          ? (const Color(0xFF6EE7B7), const Color(0xFF064E3B))
          : (const Color(0xFF065F46), const Color(0xFFD1FAE5)),
      StageGateDecision.rejected => isDark
          ? (const Color(0xFFFCA5A5), const Color(0xFF450A0A))
          : (const Color(0xFF991B1B), const Color(0xFFFEE2E2)),
      StageGateDecision.changesRequested => isDark
          ? (const Color(0xFFFCD34D), const Color(0xFF451A03))
          : (const Color(0xFF92400E), const Color(0xFFFEF3C7)),
      StageGateDecision.pending => isDark
          ? (const Color(0xFF93C5FD), const Color(0xFF1E3A8A))
          : (const Color(0xFF1E40AF), const Color(0xFFDBEAFE)),
    };

    return Card(
      key: ValueKey<String>('stage_gate_card_${review.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${review.sourceRef} ${review.title}',
                  style: theme.textTheme.titleSmall,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user, size: 15, color: fg),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${review.status.label}: '
                          '${review.currentStage.label} -> ${review.targetStage.label}',
                          softWrap: true,
                          style: TextStyle(
                            color: fg,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              key: ValueKey<String>('stage_gate_feedback_${review.id}'),
              controller: _controllerFor(review),
              decoration: const InputDecoration(
                labelText: '承認・却下フィードバック',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            if (_isAdmin) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: FilledButton.icon(
                      key: ValueKey<String>('stage_gate_approve_${review.id}'),
                      onPressed: _loading
                          ? null
                          : () => _decide(review, StageGateDecision.approved),
                      icon: const Icon(Icons.check),
                      label: const Text('承認'),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: OutlinedButton.icon(
                      key: ValueKey<String>('stage_gate_changes_${review.id}'),
                      onPressed: _loading
                          ? null
                          : () => _decide(
                                review,
                                StageGateDecision.changesRequested,
                              ),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('差し戻し'),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: OutlinedButton.icon(
                      key: ValueKey<String>('stage_gate_reject_${review.id}'),
                      onPressed: _loading
                          ? null
                          : () => _decide(review, StageGateDecision.rejected),
                      icon: const Icon(Icons.close),
                      label: const Text('却下'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
