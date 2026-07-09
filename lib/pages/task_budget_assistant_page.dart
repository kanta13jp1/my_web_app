import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/task_budget_assistant_service.dart';

class TaskBudgetAssistantPage extends StatefulWidget {
  const TaskBudgetAssistantPage({super.key, this.supabaseClient, this.service});

  final SupabaseClient? supabaseClient;
  final TaskBudgetAssistantService? service;

  @override
  State<TaskBudgetAssistantPage> createState() =>
      _TaskBudgetAssistantPageState();
}

class _TaskBudgetAssistantPageState extends State<TaskBudgetAssistantPage> {
  static const _bg = Color(0xFF0A0A0A);
  static const _panel = Color(0xFF141414);
  static const _line = Color(0xFF262626);
  static const _muted = Color(0xFF94A3B8);
  static const _green = Color(0xFF22C55E);
  static const _amber = Color(0xFFF59E0B);
  static const _blue = Color(0xFF38BDF8);
  static const _red = Color(0xFFEF4444);
  static const _minBudget = 20000;
  static const _maxBudget = 200000;

  late final TaskBudgetAssistantService _service;
  final _titleController = TextEditingController(text: 'Inbox aggregation');
  final _objectiveController = TextEditingController();
  final _budgetController = TextEditingController(text: '20000');
  final _documentsController = TextEditingController();

  String _effort = 'medium';
  bool _loading = true;
  bool _creating = false;
  String? _error;
  TaskBudgetAssistantDetail? _detail;
  List<TaskBudgetAssistantJob> _jobs = const [];

  @override
  void initState() {
    super.initState();
    _service = widget.service ??
        TaskBudgetAssistantService(supabaseClient: widget.supabaseClient);
    _loadJobs();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _objectiveController.dispose();
    _budgetController.dispose();
    _documentsController.dispose();
    super.dispose();
  }

  Future<void> _loadJobs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final jobs = await _service.listJobs();
      if (!mounted) return;
      setState(() => _jobs = jobs);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadJob(TaskBudgetAssistantJob job) async {
    setState(() => _loading = true);
    try {
      final detail = await _service.loadJob(job.id);
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createJob() async {
    final title = _titleController.text.trim();
    final objective = _objectiveController.text.trim();
    final budget = int.tryParse(_budgetController.text.trim()) ?? 0;
    final documents = _parseDocuments(_documentsController.text);

    if (title.isEmpty || objective.isEmpty || documents.isEmpty) {
      _showMessage('Title, objective, and documents are required.');
      return;
    }
    if (budget < _minBudget) {
      _showMessage('Token budget must be at least 20,000.');
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final detail = await _service.createJob(
        title: title,
        objective: objective,
        budgetTokens: budget,
        effort: _effort,
        documents: documents,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _jobs = [detail.job, ..._jobs.where((job) => job.id != detail.job.id)];
      });
      _showMessage('Saved ${detail.job.consumedTokens} tokens.');
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  List<TaskBudgetAssistantDocument> _parseDocuments(String raw) {
    final blocks = raw
        .split(RegExp(r'\n\s*-{3,}\s*\n|\n\s*\n'))
        .map((block) => block.trim())
        .where((block) => block.isNotEmpty)
        .toList();
    return [
      for (var index = 0; index < blocks.length; index++)
        if (_documentContent(blocks[index]).isNotEmpty)
          TaskBudgetAssistantDocument(
            title: _documentTitle(blocks[index], index),
            content: _documentContent(blocks[index]),
          ),
    ];
  }

  String _documentTitle(String block, int index) {
    final lines = block.split('\n').map((line) => line.trim()).toList();
    if (lines.length > 1 && lines.first.length <= 80) return lines.first;
    return 'Document ${index + 1}';
  }

  String _documentContent(String block) {
    final lines = block.split('\n').map((line) => line.trim()).toList();
    if (lines.length > 1 && lines.first.length <= 80) {
      return lines.skip(1).join('\n').trim();
    }
    return block.trim();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _syncBudgetFromSlider(double value) {
    _budgetController.text = value.round().toString();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: const Text('Task Budget Assistant'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadJobs,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _amber,
        onRefresh: _loadJobs,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) ...[
              _errorBanner(_error!),
              const SizedBox(height: 12),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 920;
                if (!wide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _composer(),
                      const SizedBox(height: 16),
                      _dashboard(),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: _composer()),
                    const SizedBox(width: 16),
                    Expanded(flex: 6, child: _dashboard()),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    final budget = int.tryParse(_budgetController.text) ?? _minBudget;
    return _section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeader(
            icon: Icons.tune,
            title: 'Run setup',
            color: _amber,
          ),
          const SizedBox(height: 14),
          _textField(
            controller: _titleController,
            label: 'Title',
            icon: Icons.label_outline,
          ),
          const SizedBox(height: 12),
          _textField(
            controller: _objectiveController,
            label: 'Objective',
            icon: Icons.flag_outlined,
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _textField(
                  key: const Key('task-budget-budget-field'),
                  controller: _budgetController,
                  label: 'Token budget',
                  icon: Icons.token,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 152,
                child: DropdownButtonFormField<String>(
                  key: const Key('task-budget-effort-field'),
                  initialValue: _effort,
                  isExpanded: true,
                  dropdownColor: _panel,
                  decoration: _inputDecoration(
                    label: 'Effort',
                    icon: Icons.speed,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'low',
                      child: Text(
                        'low',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'medium',
                      child: Text(
                        'medium',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'high',
                      child: Text(
                        'high',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'xhigh',
                      child: Text(
                        'xhigh',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _effort = value);
                  },
                ),
              ),
            ],
          ),
          Slider(
            min: _minBudget.toDouble(),
            max: _maxBudget.toDouble(),
            divisions: 18,
            value: budget.clamp(_minBudget, _maxBudget).toDouble(),
            activeColor: _amber,
            inactiveColor: _line,
            onChanged: _syncBudgetFromSlider,
          ),
          const Text(
            'Minimum 20,000 tokens',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _textField(
            key: const Key('task-budget-documents-field'),
            controller: _documentsController,
            label: 'Documents',
            icon: Icons.description_outlined,
            maxLines: 10,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const Key('task-budget-create-button'),
            onPressed: _creating ? null : _createJob,
            icon: _creating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: const Text('Start job'),
          ),
        ],
      ),
    );
  }

  Widget _dashboard() {
    final detail = _detail;
    final job = detail?.job;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                icon: Icons.dashboard_outlined,
                title: 'Progress',
                color: _blue,
              ),
              const SizedBox(height: 14),
              if (_loading && job == null)
                const Center(child: CircularProgressIndicator(color: _amber))
              else if (job == null)
                const Text('No selected job', style: TextStyle(color: _muted))
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: _metric(
                        icon: Icons.timelapse,
                        label: 'Status',
                        value: job.status,
                        color: _statusColor(job.status),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _metric(
                        icon: Icons.percent,
                        label: 'Progress',
                        value: '${job.progressPercent}%',
                        color: _blue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _metric(
                        icon: Icons.token,
                        label: 'Tokens',
                        value: '${job.consumedTokens}/${job.budgetTokens}',
                        color: _amber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    value: job.progressPercent.clamp(0, 100).toDouble() / 100,
                    backgroundColor: _line,
                    color: _statusColor(job.status),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  job.summary.isEmpty ? job.objective : job.summary,
                  key: const Key('task-budget-summary-text'),
                  style: const TextStyle(color: Colors.white70, height: 1.45),
                ),
                const SizedBox(height: 14),
                _stepList(detail!.steps),
                const SizedBox(height: 14),
                _artifact(job),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _jobsList(),
      ],
    );
  }

  Widget _jobsList() {
    return _section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.history,
            title: 'Recent jobs',
            color: _green,
          ),
          const SizedBox(height: 10),
          if (_jobs.isEmpty)
            const Text('No jobs yet', style: TextStyle(color: _muted))
          else
            for (final job in _jobs.take(8))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  job.stoppedSafely
                      ? Icons.health_and_safety_outlined
                      : Icons.task_alt,
                  color: _statusColor(job.status),
                ),
                title: Text(
                  job.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  '${job.status}  ${job.consumedTokens}/${job.budgetTokens}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted),
                ),
                trailing: IconButton(
                  tooltip: 'Open',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _loadJob(job),
                ),
              ),
        ],
      ),
    );
  }

  Widget _stepList(List<TaskBudgetAssistantStep> steps) {
    if (steps.isEmpty) {
      return const Text('No steps recorded', style: TextStyle(color: _muted));
    }
    return Column(
      children: [
        for (final step in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  step.status == 'budget_safed'
                      ? Icons.shield_outlined
                      : Icons.check_circle_outline,
                  color: _statusColor(step.status),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${step.status}  ${step.totalTokens} tokens',
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                      if (step.notes.isNotEmpty)
                        Text(
                          step.notes,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _artifact(TaskBudgetAssistantJob job) {
    final artifact = job.artifact;
    final documents =
        ((artifact['documents'] ?? artifact['extracted']) as List?) ?? const [];
    final folders = (artifact['folders'] as List?) ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Artifacts',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final folder in folders.take(6))
              _chip(
                Icons.folder_outlined,
                folder is Map
                    ? (folder['folder'] ?? 'Folder').toString()
                    : folder.toString(),
                _blue,
              ),
            for (final doc in documents.take(4))
              _chip(
                Icons.article_outlined,
                doc is Map ? (doc['title'] ?? 'Document').toString() : 'Doc',
                _amber,
              ),
          ],
        ),
      ],
    );
  }

  Widget _section({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: child,
    );
  }

  Widget _metric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _textField({
    Key? key,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      key: key,
      controller: controller,
      maxLines: maxLines,
      minLines: maxLines == 1 ? 1 : 3,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label: label, icon: icon),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _muted),
      prefixIcon: Icon(icon, color: _muted),
      filled: true,
      fillColor: _bg,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _amber),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _red.withValues(alpha: 0.4)),
      ),
      child: Text(error, style: const TextStyle(color: Colors.white70)),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return _green;
      case 'budget_safed':
        return _amber;
      case 'failed':
        return _red;
      case 'running':
      case 'queued':
        return _blue;
      default:
        return _muted;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}
