import 'package:flutter/material.dart';

import '../services/eval_approval_service.dart';

class EvalApprovalPage extends StatefulWidget {
  const EvalApprovalPage({super.key, this.service});

  final EvalApprovalGateway? service;

  @override
  State<EvalApprovalPage> createState() => _EvalApprovalPageState();
}

class _EvalApprovalPageState extends State<EvalApprovalPage> {
  late final EvalApprovalGateway _service;
  final _reasonController = TextEditingController();
  final Map<String, String> _selectedOptions = {};

  List<EvalApprovalRequest> _requests = const [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? EvalApprovalService();
    _load();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await _service.loadRequests();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        for (final request in requests.where((item) => item.isPending)) {
          final defaultOption = request.defaultOptionId;
          if (defaultOption != null) {
            _selectedOptions.putIfAbsent(request.id, () => defaultOption);
          }
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(
    EvalApprovalRequest request,
    EvalApprovalDecision decision,
  ) async {
    if (_submitting) return;
    final selectedOption = _selectedOptions[request.id];
    if (decision == EvalApprovalDecision.approved &&
        request.options.isNotEmpty &&
        selectedOption == null) {
      setState(() => _error = '承認する案を選択してください。');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final updated = await _service.decide(
        requestId: request.id,
        decision: decision,
        selectedOptionId: selectedOption,
        reason: _reasonController.text,
      );
      if (!mounted) return;
      setState(() {
        _requests = [
          for (final item in _requests)
            if (item.id == updated.id) updated else item,
        ];
        _reasonController.clear();
      });
      final execution = updated.execution;
      final detail = execution == null
          ? ''
          : ' タスク${execution.tasksCreated}件・予定${execution.calendarEventsCreated}件を登録しました。';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == EvalApprovalDecision.approved
                ? '承認しました。$detail'
                : '否認しました。',
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _requests.where((item) => item.isPending).toList();
    final recent = _requests.where((item) => !item.isPending).take(8).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('CEO Eval'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _QueueHeader(pendingCount: pending.length, running: _loading),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _MessageBand(
                message: _error!,
                icon: Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
              ),
            ],
            const SizedBox(height: 16),
            if (_loading && _requests.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (pending.isEmpty)
              const _EmptyDecisionState()
            else
              _DecisionPanel(
                request: pending.first,
                selectedOptionId: _selectedOptions[pending.first.id],
                reasonController: _reasonController,
                submitting: _submitting,
                onOptionSelected: (value) =>
                    setState(() => _selectedOptions[pending.first.id] = value),
                onApprove: () =>
                    _decide(pending.first, EvalApprovalDecision.approved),
                onReject: () =>
                    _decide(pending.first, EvalApprovalDecision.rejected),
              ),
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 28),
              Text(
                '直近の決断',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...recent.map(_RecentDecisionTile.new),
            ],
          ],
        ),
      ),
    );
  }
}

class _QueueHeader extends StatelessWidget {
  const _QueueHeader({required this.pendingCount, required this.running});

  final int pendingCount;
  final bool running;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.fact_check_outlined,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '判断待ち $pendingCount件',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                running ? 'AI作業を同期中' : 'AI作業はバックグラウンドで継続中',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (running)
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }
}

class _DecisionPanel extends StatelessWidget {
  const _DecisionPanel({
    required this.request,
    required this.selectedOptionId,
    required this.reasonController,
    required this.submitting,
    required this.onOptionSelected,
    required this.onApprove,
    required this.onReject,
  });

  final EvalApprovalRequest request;
  final String? selectedOptionId;
  final TextEditingController reasonController;
  final bool submitting;
  final ValueChanged<String> onOptionSelected;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('eval_decision_panel'),
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
              Expanded(
                child: Text(
                  request.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const Chip(label: Text('要決断')),
            ],
          ),
          if (request.summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(request.summary),
          ],
          if (request.options.isNotEmpty) ...[
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(
                key: const Key('eval_option_selector'),
                showSelectedIcon: true,
                emptySelectionAllowed: false,
                segments: [
                  for (final option in request.options)
                    ButtonSegment<String>(
                      value: option.id,
                      label: Text(
                        option.recommended
                            ? '${option.label}（推奨）'
                            : option.label,
                      ),
                    ),
                ],
                selected: selectedOptionId == null
                    ? const <String>{}
                    : <String>{selectedOptionId!},
                onSelectionChanged: submitting
                    ? null
                    : (values) => onOptionSelected(values.first),
              ),
            ),
            const SizedBox(height: 12),
            for (final option in request.options)
              if (option.id == selectedOptionId && option.summary.isNotEmpty)
                Text(
                  option.summary,
                  key: const Key('eval_selected_option_summary'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
          ],
          const SizedBox(height: 20),
          _BackgroundProgress(request: request),
          const SizedBox(height: 20),
          TextField(
            key: const Key('eval_reason_field'),
            controller: reasonController,
            enabled: !submitting,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '理由・補足（任意）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const Key('eval_approve_button'),
                onPressed: submitting ? null : onApprove,
                icon: submitting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('承認'),
              ),
              OutlinedButton.icon(
                key: const Key('eval_reject_button'),
                onPressed: submitting ? null : onReject,
                icon: const Icon(Icons.close),
                label: const Text('否認'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackgroundProgress extends StatelessWidget {
  const _BackgroundProgress({required this.request});

  final EvalApprovalRequest request;

  @override
  Widget build(BuildContext context) {
    final steps = request.backgroundSteps.isEmpty
        ? const [
            EvalBackgroundStep(label: '情報収集', status: 'completed'),
            EvalBackgroundStep(label: '選択肢生成', status: 'completed'),
            EvalBackgroundStep(label: 'CEO判断', status: 'running'),
          ]
        : request.backgroundSteps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI作業',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [for (final step in steps) _ProgressStep(step: step)],
        ),
      ],
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({required this.step});

  final EvalBackgroundStep step;

  @override
  Widget build(BuildContext context) {
    final color = step.isCompleted
        ? const Color(0xFF2E7D32)
        : step.isRunning
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          step.isCompleted
              ? Icons.check_circle
              : step.isRunning
                  ? Icons.sync
                  : Icons.radio_button_unchecked,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 5),
        Text(step.label),
      ],
    );
  }
}

class _RecentDecisionTile extends StatelessWidget {
  const _RecentDecisionTile(this.request);

  final EvalApprovalRequest request;

  @override
  Widget build(BuildContext context) {
    final approved = request.status == 'approved';
    final execution = request.execution;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        approved ? Icons.check_circle_outline : Icons.cancel_outlined,
        color: approved
            ? const Color(0xFF2E7D32)
            : Theme.of(context).colorScheme.error,
      ),
      title: Text(request.title),
      subtitle: execution == null
          ? null
          : Text(
              'タスク${execution.tasksCreated}件・予定${execution.calendarEventsCreated}件',
            ),
      trailing: Text(approved ? '承認済み' : '否認済み'),
    );
  }
}

class _EmptyDecisionState extends StatelessWidget {
  const _EmptyDecisionState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.task_alt,
            size: 44,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            '判断待ちはありません',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MessageBand extends StatelessWidget {
  const _MessageBand({
    required this.message,
    required this.icon,
    required this.color,
  });

  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
