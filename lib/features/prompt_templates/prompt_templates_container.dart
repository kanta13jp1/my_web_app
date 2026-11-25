import 'package:flutter/material.dart';

import 'application/prompt_templates_controller.dart';
import 'data/supabase_prompt_template_repository.dart';
import 'domain/prompt_template_models.dart';
import 'presentation/prompt_templates_view.dart';

/// 5要素構造化プロンプトテンプレート管理 Feature の Container ウィジェット (#2665).
class PromptTemplatesContainer extends StatefulWidget {
  const PromptTemplatesContainer({
    super.key,
    this.repository,
    this.controller,
    this.clipboardWriter,
    this.onSendPrompt,
    this.autoLoad = true,
  });

  final PromptTemplateRepository? repository;
  final PromptTemplatesController? controller;
  final Future<void> Function(String text)? clipboardWriter;
  final Future<String> Function(String compiledPrompt)? onSendPrompt;
  final bool autoLoad;

  @override
  State<PromptTemplatesContainer> createState() =>
      _PromptTemplatesContainerState();
}

class _PromptTemplatesContainerState extends State<PromptTemplatesContainer> {
  late final PromptTemplatesController _controller;
  late final bool _ownsController;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  final TextEditingController _contextController = TextEditingController();
  final TextEditingController _deliverableController = TextEditingController();
  final TextEditingController _constraintsController = TextEditingController();
  final TextEditingController _thinkingController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        PromptTemplatesController(
          repository: widget.repository ?? SupabasePromptTemplateRepository(),
          clipboardWriter: widget.clipboardWriter,
          customSender: widget.onSendPrompt,
        );
    _controller.addListener(_syncControllersFromState);
    _syncControllersFromState();

    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((final Duration _) {
        if (mounted) {
          _controller.loadTemplates();
        }
      });
    }
  }

  void _syncFieldIfChanged(
    final TextEditingController controller,
    final String nextValue,
  ) {
    if (controller.text != nextValue) {
      controller.value = TextEditingValue(
        text: nextValue,
        selection: TextSelection.collapsed(offset: nextValue.length),
      );
    }
  }

  void _syncControllersFromState() {
    final state = _controller.state;
    _syncFieldIfChanged(_titleController, state.draftTitle);
    _syncFieldIfChanged(_roleController, state.draftElements.roleSetting);
    _syncFieldIfChanged(_contextController, state.draftElements.contextInfo);
    _syncFieldIfChanged(
      _deliverableController,
      state.draftElements.deliverableDefinition,
    );
    _syncFieldIfChanged(
      _constraintsController,
      state.draftElements.constraintsText,
    );
    _syncFieldIfChanged(
      _thinkingController,
      state.draftElements.thinkingProcess,
    );
    _syncFieldIfChanged(_searchController, state.searchQuery);
  }

  @override
  void dispose() {
    _controller.removeListener(_syncControllersFromState);
    _titleController.dispose();
    _roleController.dispose();
    _contextController.dispose();
    _deliverableController.dispose();
    _constraintsController.dispose();
    _thinkingController.dispose();
    _searchController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (final BuildContext context, final Widget? _) {
        return PromptTemplatesView(
          state: _controller.state,
          currentUserId: _controller.currentUserId,
          titleController: _titleController,
          roleController: _roleController,
          contextController: _contextController,
          deliverableController: _deliverableController,
          constraintsController: _constraintsController,
          thinkingController: _thinkingController,
          searchController: _searchController,
          onTitleChanged: _controller.updateDraftTitle,
          onRoleChanged: _controller.updateRoleSetting,
          onContextChanged: _controller.updateContextInfo,
          onDeliverableChanged: _controller.updateDeliverableDefinition,
          onConstraintsChanged: _controller.updateConstraintsText,
          onThinkingChanged: _controller.updateThinkingProcess,
          onSharedChanged: (final bool value) =>
              _controller.setDraftShared(isShared: value),
          onSavePressed: _controller.saveDraft,
          onResetPressed: _controller.resetDraft,
          onCopyPressed: _controller.copyCompiledPrompt,
          onSendPressed: _controller.sendCompiledPrompt,
          onSearchChanged: _controller.updateSearchQuery,
          onFilterChanged: _controller.updateFilter,
          onRefreshPressed: _controller.loadTemplates,
          onReuseTemplate: _controller.reuseTemplate,
          onEditTemplate: _controller.startEditingTemplate,
          onDeleteTemplate: (final PromptTemplate template) =>
              _controller.deleteTemplate(template.id),
        );
      },
    );
  }
}
