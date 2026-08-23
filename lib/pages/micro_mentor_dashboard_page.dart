import 'package:flutter/material.dart';

import '../models/micro_mentor.dart';
import '../services/micro_mentor_service.dart';

class MicroMentorDashboardPage extends StatefulWidget {
  final MicroMentorServiceContract service;

  MicroMentorDashboardPage({super.key, MicroMentorServiceContract? service})
      : service = service ?? MicroMentorService();

  @override
  State<MicroMentorDashboardPage> createState() =>
      _MicroMentorDashboardPageState();
}

class _MicroMentorDashboardPageState extends State<MicroMentorDashboardPage> {
  final _focusController = TextEditingController();
  MicroMentorDashboardSnapshot _snapshot =
      const MicroMentorDashboardSnapshot.empty();
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _focusController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final snapshot = await widget.service.loadDashboard();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _openMentorEditor([MicroMentor? mentor]) async {
    final draft = await showDialog<MicroMentorDraft>(
      context: context,
      builder: (context) => _MentorEditorDialog(mentor: mentor),
    );
    if (draft == null) return;
    await _runBusy(() async {
      await widget.service.saveMentor(mentorId: mentor?.id, draft: draft);
      await _load();
      _showMessage(mentor == null ? 'メンターを追加しました。' : 'メンターを更新しました。');
    });
  }

  Future<void> _toggleMentor(MicroMentor mentor, bool enabled) async {
    await _runBusy(() async {
      await widget.service.setMentorEnabled(mentor.id, enabled);
      await _load();
    });
  }

  Future<void> _generate() async {
    FocusScope.of(context).unfocus();
    await _runBusy(() async {
      final result = await widget.service.generateProposals(
        _focusController.text,
      );
      await _load();
      final suffix = result.failedMentorCount == 0
          ? ''
          : '（${result.failedMentorCount}人は応答なし）';
      _showMessage('${result.proposals.length}件の提案を作成しました$suffix');
    });
  }

  Future<void> _openProposalEditor(MicroMentorProposal proposal) async {
    final edit = await showDialog<_ProposalEdit>(
      context: context,
      builder: (context) => _ProposalEditorDialog(proposal: proposal),
    );
    if (edit == null) return;
    await _runBusy(() async {
      await widget.service.updateProposal(
        proposalId: proposal.id,
        title: edit.title,
        description: edit.description,
        type: edit.type,
        scheduledFor: edit.scheduledFor,
      );
      await _load();
      _showMessage('提案を更新しました。');
    });
  }

  Future<void> _setProposalStatus(
    MicroMentorProposal proposal,
    MicroMentorProposalStatus status,
  ) async {
    if (status == MicroMentorProposalStatus.rejected) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('提案を却下しますか？'),
          content: Text('「${proposal.title}」を却下済みにします。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('戻る'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('却下する'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await _runBusy(() async {
      await widget.service.setProposalStatus(proposal.id, status);
      await _load();
      _showMessage(
        status == MicroMentorProposalStatus.accepted
            ? '提案を採用しました。'
            : '提案を却下しました。',
      );
    });
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      _showMessage(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('マイクロAIメンター'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            tooltip: '再読み込み',
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => _openMentorEditor(),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('メンターを追加'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _snapshot.mentors.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _snapshot.mentors.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 42),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('再試行'),
              ),
            ],
          ),
        ),
      );
    }

    final activeCount =
        _snapshot.mentors.where((mentor) => mentor.enabled).length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 700 ? 16.0 : 28.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            112,
          ),
          children: [
            _buildFocusBand(activeCount),
            const SizedBox(height: 28),
            _SectionHeader(
              title: 'メンター',
              count: _snapshot.mentors.length,
              icon: Icons.groups_2_outlined,
            ),
            const SizedBox(height: 12),
            if (_snapshot.mentors.isEmpty)
              _EmptyState(
                icon: Icons.person_add_alt_1_outlined,
                title: 'メンター未登録',
                actionLabel: '最初のメンターを追加',
                onAction: _busy ? null : () => _openMentorEditor(),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _snapshot.mentors
                    .map(
                      (mentor) => SizedBox(
                        width: constraints.maxWidth < 700
                            ? constraints.maxWidth - horizontalPadding * 2
                            : 340,
                        child: _MentorCard(
                          mentor: mentor,
                          busy: _busy,
                          onEdit: () => _openMentorEditor(mentor),
                          onEnabledChanged: (enabled) =>
                              _toggleMentor(mentor, enabled),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            const SizedBox(height: 32),
            _SectionHeader(
              title: '提案',
              count: _snapshot.proposals.length,
              icon: Icons.view_agenda_outlined,
            ),
            const SizedBox(height: 12),
            if (_snapshot.proposals.isEmpty)
              const _EmptyState(icon: Icons.inbox_outlined, title: '提案はまだありません')
            else
              ..._snapshot.proposals.map(
                (proposal) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ProposalCard(
                    proposal: proposal,
                    mentor: _mentorById(proposal.mentorId),
                    busy: _busy,
                    onEdit: () => _openProposalEditor(proposal),
                    onAccept: () => _setProposalStatus(
                      proposal,
                      MicroMentorProposalStatus.accepted,
                    ),
                    onReject: () => _setProposalStatus(
                      proposal,
                      MicroMentorProposalStatus.rejected,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFocusBand(int activeCount) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                color: colors.onPrimaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '相談テーマ',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.onPrimaryContainer,
                      ),
                ),
              ),
              Text(
                '$activeCount人が参加',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('micro-mentor-focus'),
            controller: _focusController,
            enabled: !_busy,
            minLines: 1,
            maxLines: 3,
            maxLength: microMentorFocusMaxLength,
            decoration: const InputDecoration(
              labelText: 'テーマ',
              hintText: '例: 来週の運動と学習の時間を整えたい',
              filled: true,
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _generate(),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const Key('generate-mentor-proposals'),
              onPressed: _busy || activeCount == 0 ? null : _generate,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: const Text('全員に提案を依頼'),
            ),
          ),
        ],
      ),
    );
  }

  MicroMentor? _mentorById(String id) {
    for (final mentor in _snapshot.mentors) {
      if (mentor.id == id) return mentor;
    }
    return null;
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        Text('$count', style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}

class _MentorCard extends StatelessWidget {
  final MicroMentor mentor;
  final bool busy;
  final VoidCallback onEdit;
  final ValueChanged<bool> onEnabledChanged;

  const _MentorCard({
    required this.mentor,
    required this.busy,
    required this.onEdit,
    required this.onEnabledChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colors.secondaryContainer,
                  foregroundColor: colors.onSecondaryContainer,
                  child: const Icon(Icons.psychology_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mentor.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        mentor.domain,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: busy ? null : onEdit,
                  tooltip: 'メンター設定を編集',
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(mentor.role),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Chip(
                  avatar: const Icon(
                    Icons.record_voice_over_outlined,
                    size: 17,
                  ),
                  label: Text(mentor.tone),
                ),
                ...mentor.values.map((value) => Chip(label: Text(value))),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    mentor.enabled ? '参加中' : '停止中',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Switch(
                  value: mentor.enabled,
                  onChanged: busy ? null : onEnabledChanged,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  final MicroMentorProposal proposal;
  final MicroMentor? mentor;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _ProposalCard({
    required this.proposal,
    required this.mentor,
    required this.busy,
    required this.onEdit,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (proposal.status) {
      MicroMentorProposalStatus.proposed => Colors.amber.shade800,
      MicroMentorProposalStatus.accepted => Colors.green.shade700,
      MicroMentorProposalStatus.rejected => Theme.of(
          context,
        ).colorScheme.outline,
    };
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  proposal.type == MicroMentorProposalType.schedule
                      ? Icons.event_outlined
                      : Icons.checklist_outlined,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        proposal.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${mentor?.name ?? 'メンター'} ・ ${proposal.type.label}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: statusColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    proposal.status.label,
                    style: TextStyle(color: statusColor, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(proposal.description),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, size: 18),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    proposal.rationale,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            if (proposal.scheduledFor != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 18),
                  const SizedBox(width: 7),
                  Text(_formatDateTime(proposal.scheduledFor!)),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  key: Key('edit-proposal-${proposal.id}'),
                  onPressed: busy ||
                          proposal.status == MicroMentorProposalStatus.rejected
                      ? null
                      : onEdit,
                  tooltip: '提案を編集',
                  icon: const Icon(Icons.edit_outlined),
                ),
                if (proposal.status == MicroMentorProposalStatus.proposed) ...[
                  IconButton(
                    key: Key('reject-proposal-${proposal.id}'),
                    onPressed: busy ? null : onReject,
                    tooltip: '提案を却下',
                    icon: const Icon(Icons.close),
                  ),
                  IconButton(
                    key: Key('accept-proposal-${proposal.id}'),
                    onPressed: busy ? null : onAccept,
                    tooltip: '提案を採用',
                    icon: const Icon(Icons.check),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (actionLabel != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _MentorEditorDialog extends StatefulWidget {
  final MicroMentor? mentor;

  const _MentorEditorDialog({this.mentor});

  @override
  State<_MentorEditorDialog> createState() => _MentorEditorDialogState();
}

class _MentorEditorDialogState extends State<_MentorEditorDialog> {
  static const _tones = <String>['穏やか', '率直', '励ます', '分析的'];
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _domainController;
  late final TextEditingController _roleController;
  late final TextEditingController _valuesController;
  late String _tone;

  @override
  void initState() {
    super.initState();
    final mentor = widget.mentor;
    _nameController = TextEditingController(text: mentor?.name ?? '');
    _domainController = TextEditingController(text: mentor?.domain ?? '');
    _roleController = TextEditingController(text: mentor?.role ?? '');
    _valuesController = TextEditingController(
      text: mentor?.values.join('、') ?? '',
    );
    _tone = _tones.contains(mentor?.tone) ? mentor!.tone : _tones.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _domainController.dispose();
    _roleController.dispose();
    _valuesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.mentor == null ? 'メンターを追加' : 'メンター設定'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('mentor-name-field'),
                  controller: _nameController,
                  maxLength: microMentorNameMaxLength,
                  decoration: const InputDecoration(labelText: '名前'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('mentor-domain-field'),
                  controller: _domainController,
                  maxLength: microMentorDomainMaxLength,
                  decoration: const InputDecoration(labelText: '担当領域'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('mentor-role-field'),
                  controller: _roleController,
                  minLines: 2,
                  maxLines: 3,
                  maxLength: microMentorRoleMaxLength,
                  decoration: const InputDecoration(labelText: '役割'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('mentor-tone-field'),
                  initialValue: _tone,
                  decoration: const InputDecoration(labelText: '口調'),
                  items: _tones
                      .map(
                        (tone) =>
                            DropdownMenuItem(value: tone, child: Text(tone)),
                      )
                      .toList(growable: false),
                  onChanged: (value) => setState(() => _tone = value ?? _tone),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('mentor-values-field'),
                  controller: _valuesController,
                  maxLength: microMentorValuesInputMaxLength,
                  decoration: const InputDecoration(
                    labelText: '大切な価値観',
                    hintText: '継続、健康、家族',
                  ),
                  validator: _required,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const Key('save-mentor'),
          onPressed: _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? '入力してください' : null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      MicroMentorDraft(
        name: _nameController.text,
        domain: _domainController.text,
        role: _roleController.text,
        tone: _tone,
        values: _valuesController.text.split(RegExp(r'[,、\n]')),
      ),
    );
  }
}

class _ProposalEditorDialog extends StatefulWidget {
  final MicroMentorProposal proposal;

  const _ProposalEditorDialog({required this.proposal});

  @override
  State<_ProposalEditorDialog> createState() => _ProposalEditorDialogState();
}

class _ProposalEditorDialogState extends State<_ProposalEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late MicroMentorProposalType _type;
  DateTime? _scheduledFor;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.proposal.title);
    _descriptionController = TextEditingController(
      text: widget.proposal.description,
    );
    _type = widget.proposal.type;
    _scheduledFor = widget.proposal.scheduledFor;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('提案を編集'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<MicroMentorProposalType>(
                  key: const Key('proposal-type-field'),
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: '種類'),
                  items: MicroMentorProposalType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    setState(() => _type = value ?? _type);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('proposal-title-field'),
                  controller: _titleController,
                  maxLength: microMentorProposalTitleMaxLength,
                  decoration: const InputDecoration(labelText: '見出し'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('proposal-description-field'),
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: microMentorProposalDescriptionMaxLength,
                  decoration: const InputDecoration(labelText: '内容'),
                  validator: _required,
                ),
                if (_type == MicroMentorProposalType.schedule) ...[
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text(
                      _scheduledFor == null
                          ? '日時未設定'
                          : _formatDateTime(_scheduledFor!),
                    ),
                    trailing: IconButton(
                      onPressed: _pickDate,
                      tooltip: '日付を選択',
                      icon: const Icon(Icons.edit_calendar_outlined),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const Key('save-proposal'),
          onPressed: _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? '入力してください' : null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
      initialDate: _scheduledFor ?? now,
    );
    if (selected == null || !mounted) return;
    setState(() {
      final current = _scheduledFor;
      _scheduledFor = DateTime(
        selected.year,
        selected.month,
        selected.day,
        current?.hour ?? 9,
        current?.minute ?? 0,
      );
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _ProposalEdit(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _type,
        scheduledFor:
            _type == MicroMentorProposalType.schedule ? _scheduledFor : null,
      ),
    );
  }
}

class _ProposalEdit {
  final String title;
  final String description;
  final MicroMentorProposalType type;
  final DateTime? scheduledFor;

  const _ProposalEdit({
    required this.title,
    required this.description,
    required this.type,
    this.scheduledFor,
  });
}

String _formatDateTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${value.year}/${twoDigits(value.month)}/${twoDigits(value.day)} '
      '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}
