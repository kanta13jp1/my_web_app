import 'package:flutter/material.dart';

import '../models/ai_form_assistant.dart';
import '../services/ai_form_assistant_service.dart';
import '../view_models/ai_form_assistant_view_model.dart';

class AiFormAssistantPage extends StatefulWidget {
  const AiFormAssistantPage({super.key, this.viewModel});

  final AiFormAssistantViewModel? viewModel;

  @override
  State<AiFormAssistantPage> createState() => _AiFormAssistantPageState();
}

class _AiFormAssistantPageState extends State<AiFormAssistantPage> {
  final _formKey = GlobalKey<FormState>();
  final _chatInputController = TextEditingController();
  final Map<String, TextEditingController> _fieldControllers =
      <String, TextEditingController>{};
  late final AiFormAssistantViewModel _viewModel;
  late final bool _ownsViewModel;
  bool _syncingControllers = false;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _viewModel = widget.viewModel ??
        AiFormAssistantViewModel(
          gateway: AiHubFormAssistantGateway(),
          settingsStore: const SharedPreferencesAiFormSettingsStore(),
        );
    for (final field in _viewModel.fields) {
      if (field.kind == AiFormFieldKind.text ||
          field.kind == AiFormFieldKind.multiline) {
        final controller = TextEditingController(
          text: _viewModel.valueFor(field.id).toString(),
        );
        controller.addListener(() {
          if (!_syncingControllers) {
            _viewModel.updateField(field.id, controller.text);
          }
        });
        _fieldControllers[field.id] = controller;
      }
    }
    _viewModel.addListener(_syncControllersFromViewModel);
    _viewModel.initialize();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_syncControllersFromViewModel);
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    _chatInputController.dispose();
    if (_ownsViewModel) _viewModel.dispose();
    super.dispose();
  }

  void _syncControllersFromViewModel() {
    _syncingControllers = true;
    for (final entry in _fieldControllers.entries) {
      final nextValue = _viewModel.valueFor(entry.key).toString();
      if (entry.value.text != nextValue) {
        entry.value.value = entry.value.value.copyWith(
          text: nextValue,
          selection: TextSelection.collapsed(offset: nextValue.length),
          composing: TextRange.empty,
        );
      }
    }
    _syncingControllers = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AIフォーム設定支援'),
        actions: [
          ListenableBuilder(
            listenable: _viewModel,
            builder: (context, _) => IconButton(
              key: const Key('ai-form-save-appbar'),
              tooltip: '設定を保存',
              onPressed: _viewModel.isSaving ? null : _save,
              icon: _viewModel.isSaving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          if (!_viewModel.initialized) {
            return const Center(child: CircularProgressIndicator());
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 960;
              final content = isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 3,
                          child: SingleChildScrollView(
                            child: _buildFormPanel(context),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: _buildAssistantPanel(context)),
                      ],
                    )
                  : ListView(
                      children: [
                        _buildFormPanel(context),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 640,
                          child: _buildAssistantPanel(context),
                        ),
                      ],
                    );
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: content,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFormPanel(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('ai-form-settings-panel'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ワークフロー設定', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                '手入力はいつでも優先されます。AIの提案は確認するまで反映されません。',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              for (var index = 0;
                  index < _viewModel.fields.length;
                  index++) ...[
                _buildField(_viewModel.fields[index]),
                if (index < _viewModel.fields.length - 1)
                  const SizedBox(height: 16),
              ],
              const SizedBox(height: 24),
              if (_viewModel.errorMessage != null) ...[
                Text(
                  _viewModel.errorMessage!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('ai-form-save'),
                  onPressed: _viewModel.isSaving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_viewModel.isSaving ? '保存中...' : '設定を保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(AiFormFieldDefinition field) {
    switch (field.kind) {
      case AiFormFieldKind.text:
      case AiFormFieldKind.multiline:
        return TextFormField(
          key: Key('ai-form-field-${field.id}'),
          controller: _fieldControllers[field.id],
          minLines: field.kind == AiFormFieldKind.multiline ? 3 : 1,
          maxLines: field.kind == AiFormFieldKind.multiline ? 5 : 1,
          maxLength: field.maxLength,
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.description,
            border: const OutlineInputBorder(),
            alignLabelWithHint: field.kind == AiFormFieldKind.multiline,
          ),
          validator: (_) => _viewModel.validationErrorFor(field.id),
        );
      case AiFormFieldKind.choice:
        final value = _viewModel.valueFor(field.id).toString();
        return DropdownButtonFormField<String>(
          key: ValueKey<String>('ai-form-field-${field.id}-$value'),
          initialValue: value,
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.description,
            border: const OutlineInputBorder(),
          ),
          items: field.options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(growable: false),
          onChanged: (next) {
            if (next != null) _viewModel.updateField(field.id, next);
          },
          validator: (_) => _viewModel.validationErrorFor(field.id),
        );
      case AiFormFieldKind.boolean:
        return Card.outlined(
          margin: EdgeInsets.zero,
          child: SwitchListTile(
            key: Key('ai-form-field-${field.id}'),
            title: Text(field.label),
            subtitle: Text(field.description),
            value: _viewModel.valueFor(field.id) == true,
            onChanged: (next) => _viewModel.updateField(field.id, next),
          ),
        );
    }
  }

  Widget _buildAssistantPanel(BuildContext context) {
    final theme = Theme.of(context);
    final proposal = _viewModel.pendingProposal;
    return Card(
      key: const Key('ai-form-chat-panel'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.auto_awesome,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            title: const Text('AI設定アシスタント'),
            subtitle: const Text('現在値を参照して変更案を作成'),
          ),
          Container(
            width: double.infinity,
            color: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: const Text(
              '機密情報やパスワードは入力しないでください。送信内容と現在の設定値がAI処理に使われます。',
              style: TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            child: ListView.builder(
              key: const Key('ai-form-chat-messages'),
              padding: const EdgeInsets.all(12),
              itemCount: _viewModel.messages.length,
              itemBuilder: (context, index) =>
                  _buildChatBubble(context, _viewModel.messages[index]),
            ),
          ),
          if (proposal != null) _buildProposalCard(context, proposal),
          if (_viewModel.isSubmitting) const LinearProgressIndicator(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('ai-form-chat-input'),
                      controller: _chatInputController,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: '例: 毎週月曜に売上を集計し、承認後Slackへ通知したい',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const Key('ai-form-send'),
                    tooltip: '送信',
                    onPressed: _viewModel.isSubmitting ? null : _submitChat,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(BuildContext context, AiFormChatMessage message) {
    final isUser = message.role == AiFormChatRole.user;
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? colors.primaryContainer : colors.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(message.text),
      ),
    );
  }

  Widget _buildProposalCard(BuildContext context, AiFormProposal proposal) {
    final staleCount = proposal.changes.where(_viewModel.isChangeStale).length;
    return Container(
      key: const Key('ai-form-proposal'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${proposal.changes.length}項目の変更案があります',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (staleCount > 0) Text('手入力が新しい$staleCount項目は適用時に保護されます。'),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                key: const Key('ai-form-discard'),
                onPressed: _viewModel.discardPendingProposal,
                child: const Text('破棄'),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                key: const Key('ai-form-review'),
                onPressed: _confirmProposal,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('変更内容を確認'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submitChat() async {
    final request = _chatInputController.text.trim();
    if (request.isEmpty) return;
    _chatInputController.clear();
    await _viewModel.submit(request);
  }

  Future<void> _confirmProposal() async {
    final proposal = _viewModel.pendingProposal;
    if (proposal == null) return;
    final shouldApply = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('AIの変更案を適用しますか？'),
        content: SizedBox(
          width: 520,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: proposal.changes.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final change = proposal.changes[index];
              final stale = _viewModel.isChangeStale(change);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(stale ? Icons.lock_outline : Icons.arrow_forward),
                title: Text(_fieldLabel(change.fieldId)),
                subtitle: Text(
                  stale
                      ? '手入力が更新されたため適用しません'
                      : '${_displayValue(change.value)}${change.reason.isEmpty ? '' : '\n${change.reason}'}',
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('ai-form-apply'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('確認して適用'),
          ),
        ],
      ),
    );
    if (shouldApply != true || !mounted) return;
    final result = _viewModel.applyPendingProposal();
    _formKey.currentState?.validate();
    final message = result.skipped.isEmpty
        ? '${result.applied.length}項目を反映しました。'
        : '${result.applied.length}項目を反映し、手入力が新しい${result.skipped.length}項目は保護しました。';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final saved = await _viewModel.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(saved ? '設定を保存しました。' : '設定を保存できませんでした。')),
    );
  }

  String _fieldLabel(String fieldId) {
    for (final field in _viewModel.fields) {
      if (field.id == fieldId) return field.label;
    }
    return fieldId;
  }

  String _displayValue(Object value) {
    if (value is bool) return value ? '有効' : '無効';
    return value.toString();
  }
}
