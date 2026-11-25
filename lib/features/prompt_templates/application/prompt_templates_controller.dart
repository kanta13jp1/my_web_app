import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/prompt_template_models.dart';

/// 5要素構造化プロンプトテンプレート画面の UI 状態 (#2665).
@immutable
class PromptTemplatesState {
  const PromptTemplatesState({
    this.templates = const <PromptTemplate>[],
    this.filter = PromptTemplateFilter.all,
    this.searchQuery = '',
    this.isLoading = false,
    this.isSubmitting = false,
    this.isSending = false,
    this.draftTitle = '',
    this.draftElements = const PromptElements(),
    this.draftIsShared = false,
    this.editingTemplateId,
    this.activeTemplateId,
    this.errorMessage,
    this.statusMessage,
    this.lastApiResponse,
    this.lastSendProviderLabel,
  });

  final List<PromptTemplate> templates;
  final PromptTemplateFilter filter;
  final String searchQuery;
  final bool isLoading;
  final bool isSubmitting;
  final bool isSending;
  final String draftTitle;
  final PromptElements draftElements;
  final bool draftIsShared;
  final String? editingTemplateId;
  final String? activeTemplateId;
  final String? errorMessage;
  final String? statusMessage;
  final String? lastApiResponse;
  final String? lastSendProviderLabel;

  bool get isEditing =>
      editingTemplateId != null && editingTemplateId!.trim().isNotEmpty;

  String get liveCompiledPrompt =>
      draftElements.compilePlainText(title: draftTitle);

  List<PromptTemplate> filteredTemplates({final String? currentUserId}) {
    return templates.where((final PromptTemplate template) {
      switch (filter) {
        case PromptTemplateFilter.all:
          break;
        case PromptTemplateFilter.shared:
          if (!template.isShared) {
            return false;
          }
        case PromptTemplateFilter.mine:
          if (currentUserId == null || template.userId != currentUserId) {
            return false;
          }
      }
      return template.matchesSearch(searchQuery);
    }).toList(growable: false);
  }

  PromptTemplatesState copyWith({
    final List<PromptTemplate>? templates,
    final PromptTemplateFilter? filter,
    final String? searchQuery,
    final bool? isLoading,
    final bool? isSubmitting,
    final bool? isSending,
    final String? draftTitle,
    final PromptElements? draftElements,
    final bool? draftIsShared,
    final String? editingTemplateId,
    final bool clearEditingTemplateId = false,
    final String? activeTemplateId,
    final bool clearActiveTemplateId = false,
    final String? errorMessage,
    final bool clearError = false,
    final String? statusMessage,
    final bool clearStatus = false,
    final String? lastApiResponse,
    final bool clearApiResponse = false,
    final String? lastSendProviderLabel,
  }) {
    return PromptTemplatesState(
      templates: templates ?? this.templates,
      filter: filter ?? this.filter,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSending: isSending ?? this.isSending,
      draftTitle: draftTitle ?? this.draftTitle,
      draftElements: draftElements ?? this.draftElements,
      draftIsShared: draftIsShared ?? this.draftIsShared,
      editingTemplateId: clearEditingTemplateId
          ? null
          : (editingTemplateId ?? this.editingTemplateId),
      activeTemplateId: clearActiveTemplateId
          ? null
          : (activeTemplateId ?? this.activeTemplateId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      statusMessage: clearStatus ? null : (statusMessage ?? this.statusMessage),
      lastApiResponse:
          clearApiResponse ? null : (lastApiResponse ?? this.lastApiResponse),
      lastSendProviderLabel: clearApiResponse
          ? null
          : (lastSendProviderLabel ?? this.lastSendProviderLabel),
    );
  }
}

/// 5要素構造化プロンプトの作成・検索・再利用・送信を制御するコントローラ (#2665).
class PromptTemplatesController extends ChangeNotifier {
  PromptTemplatesController({
    required final PromptTemplateRepository repository,
    final Future<void> Function(String text)? clipboardWriter,
    final Future<String> Function(String compiledPrompt)? customSender,
  })  : _repository = repository,
        _clipboardWriter = clipboardWriter,
        _customSender = customSender;

  final PromptTemplateRepository _repository;
  final Future<void> Function(String text)? _clipboardWriter;
  final Future<String> Function(String compiledPrompt)? _customSender;

  PromptTemplatesState _state = const PromptTemplatesState();
  bool _isDisposed = false;

  PromptTemplatesState get state => _state;

  String? get currentUserId => _repository.currentUserId;

  void _notifyIfActive() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> loadTemplates() async {
    if (_isDisposed || _state.isLoading) {
      return;
    }
    _state = _state.copyWith(
      isLoading: true,
      clearError: true,
    );
    _notifyIfActive();
    try {
      final loaded = await _repository.listTemplates();
      if (_isDisposed) {
        return;
      }
      _state = _state.copyWith(
        templates: List<PromptTemplate>.unmodifiable(loaded),
        isLoading: false,
      );
    } catch (error) {
      if (_isDisposed) {
        return;
      }
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'テンプレートの読み込みに失敗しました: $error',
      );
    } finally {
      _notifyIfActive();
    }
  }

  void updateDraftTitle(final String value) {
    if (_isDisposed) {
      return;
    }
    _state = _state.copyWith(
      draftTitle: value,
      clearError: true,
    );
    _notifyIfActive();
  }

  void updateRoleSetting(final String value) {
    if (_isDisposed) {
      return;
    }
    _state = _state.copyWith(
      draftElements: _state.draftElements.copyWith(roleSetting: value),
      clearError: true,
    );
    _notifyIfActive();
  }

  void updateContextInfo(final String value) {
    if (_isDisposed) {
      return;
    }
    _state = _state.copyWith(
      draftElements: _state.draftElements.copyWith(contextInfo: value),
      clearError: true,
    );
    _notifyIfActive();
  }

  void updateDeliverableDefinition(final String value) {
    if (_isDisposed) {
      return;
    }
    _state = _state.copyWith(
      draftElements:
          _state.draftElements.copyWith(deliverableDefinition: value),
      clearError: true,
    );
    _notifyIfActive();
  }

  void updateConstraintsText(final String value) {
    if (_isDisposed) {
      return;
    }
    _state = _state.copyWith(
      draftElements: _state.draftElements.copyWith(constraintsText: value),
      clearError: true,
    );
    _notifyIfActive();
  }

  void updateThinkingProcess(final String value) {
    if (_isDisposed) {
      return;
    }
    _state = _state.copyWith(
      draftElements: _state.draftElements.copyWith(thinkingProcess: value),
      clearError: true,
    );
    _notifyIfActive();
  }

  void setDraftShared({required final bool isShared}) {
    if (_isDisposed) {
      return;
    }
    _state = _state.copyWith(
      draftIsShared: isShared,
      clearError: true,
    );
    _notifyIfActive();
  }

  void updateSearchQuery(final String query) {
    if (_isDisposed) {
      return;
    }
    _state = _state.copyWith(searchQuery: query);
    _notifyIfActive();
  }

  void updateFilter(final PromptTemplateFilter filter) {
    if (_isDisposed) {
      return;
    }
    _state = _state.copyWith(filter: filter);
    _notifyIfActive();
  }

  void resetDraft() {
    if (_isDisposed) {
      return;
    }
    _state = _state.copyWith(
      draftTitle: '',
      draftElements: const PromptElements(),
      draftIsShared: false,
      clearEditingTemplateId: true,
      clearActiveTemplateId: true,
      clearError: true,
      clearStatus: true,
    );
    _notifyIfActive();
  }

  void startEditingTemplate(final PromptTemplate template) {
    if (_isDisposed) {
      return;
    }
    final uid = currentUserId;
    if (uid == null || template.userId != uid) {
      reuseTemplate(template);
      return;
    }
    _state = _state.copyWith(
      draftTitle: template.title,
      draftElements: template.elements,
      draftIsShared: template.isShared,
      editingTemplateId: template.id,
      activeTemplateId: template.id,
      clearError: true,
      statusMessage: '「${template.title}」を編集中です。',
    );
    _notifyIfActive();
  }

  Future<PromptTemplate?> saveDraft() async {
    if (_isDisposed || _state.isSubmitting) {
      return null;
    }
    final draft = PromptTemplateDraft(
      title: _state.draftTitle,
      elements: _state.draftElements,
      isShared: _state.draftIsShared,
      editingTemplateId: _state.editingTemplateId,
    );
    final errors = draft.validate();
    if (errors.isNotEmpty) {
      _state = _state.copyWith(
        errorMessage: errors.join('\n'),
        clearStatus: true,
      );
      _notifyIfActive();
      return null;
    }

    _state = _state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearStatus: true,
    );
    _notifyIfActive();

    try {
      final saved = await _repository.saveTemplate(draft);
      if (_isDisposed) {
        return null;
      }
      final updatedList = <PromptTemplate>[
        saved,
        ..._state.templates.where(
          (final PromptTemplate item) => item.id != saved.id,
        ),
      ];
      _state = _state.copyWith(
        templates: List<PromptTemplate>.unmodifiable(updatedList),
        isSubmitting: false,
        editingTemplateId: saved.id,
        activeTemplateId: saved.id,
        statusMessage: draft.editingTemplateId == null
            ? 'テンプレート「${saved.title}」を保存しました。'
            : 'テンプレート「${saved.title}」を更新しました。',
      );
      return saved;
    } catch (error) {
      if (_isDisposed) {
        return null;
      }
      _state = _state.copyWith(
        isSubmitting: false,
        errorMessage: 'テンプレートの保存に失敗しました: $error',
      );
      return null;
    } finally {
      _notifyIfActive();
    }
  }

  Future<void> deleteTemplate(final String templateId) async {
    if (_isDisposed || _state.isSubmitting) {
      return;
    }
    _state = _state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearStatus: true,
    );
    _notifyIfActive();
    try {
      await _repository.deleteTemplate(templateId);
      if (_isDisposed) {
        return;
      }
      final updatedList = _state.templates
          .where((final PromptTemplate item) => item.id != templateId)
          .toList(growable: false);
      final clearedEditing = _state.editingTemplateId == templateId;
      final clearedActive = _state.activeTemplateId == templateId;
      _state = _state.copyWith(
        templates: List<PromptTemplate>.unmodifiable(updatedList),
        isSubmitting: false,
        clearEditingTemplateId: clearedEditing,
        clearActiveTemplateId: clearedActive,
        statusMessage: 'テンプレートを削除しました。',
      );
    } catch (error) {
      if (_isDisposed) {
        return;
      }
      _state = _state.copyWith(
        isSubmitting: false,
        errorMessage: 'テンプレートの削除に失敗しました: $error',
      );
    } finally {
      _notifyIfActive();
    }
  }

  Future<void> reuseTemplate(
    final PromptTemplate template, {
    final bool recordUsage = true,
  }) async {
    if (_isDisposed) {
      return;
    }
    final isOwn = currentUserId != null && template.userId == currentUserId;
    final prefilledTitle = isOwn ? template.title : '${template.title} (再利用)';
    _state = _state.copyWith(
      draftTitle: prefilledTitle,
      draftElements: template.elements,
      draftIsShared: false,
      clearEditingTemplateId: true,
      activeTemplateId: template.id,
      clearError: true,
      statusMessage: '「${template.title}」の5要素を読み込みました。',
    );
    _notifyIfActive();

    if (!recordUsage) {
      return;
    }
    try {
      final updated = await _repository.recordTemplateUsage(template.id);
      if (_isDisposed) {
        return;
      }
      final refreshed = _state.templates
          .map(
            (final PromptTemplate item) =>
                item.id == updated.id ? updated : item,
          )
          .toList(growable: false);
      _state = _state.copyWith(
        templates: List<PromptTemplate>.unmodifiable(refreshed),
      );
    } catch (_) {
      // Fail-open: prefill remains intact even if telemetry usage increment fails.
    } finally {
      _notifyIfActive();
    }
  }

  Future<String?> copyCompiledPrompt() async {
    if (_isDisposed) {
      return null;
    }
    final errors = _state.draftElements.validateErrors();
    if (errors.isNotEmpty) {
      _state = _state.copyWith(
        errorMessage: errors.join('\n'),
        clearStatus: true,
      );
      _notifyIfActive();
      return null;
    }

    final compiled = _state.liveCompiledPrompt;
    try {
      final writer = _clipboardWriter;
      if (writer != null) {
        await writer(compiled);
      } else {
        await Clipboard.setData(ClipboardData(text: compiled));
      }
      if (_isDisposed) {
        return null;
      }
      _state = _state.copyWith(
        clearError: true,
        statusMessage: '結合プロンプトをクリップボードにコピーしました。',
      );
      _notifyIfActive();
      return compiled;
    } catch (error) {
      if (_isDisposed) {
        return null;
      }
      _state = _state.copyWith(
        errorMessage: 'クリップボードへのコピーに失敗しました: $error',
      );
      _notifyIfActive();
      return null;
    }
  }

  Future<PromptTemplateSendResult?> sendCompiledPrompt() async {
    if (_isDisposed || _state.isSending || _state.isSubmitting) {
      return null;
    }
    final errors = _state.draftElements.validateErrors();
    if (errors.isNotEmpty) {
      _state = _state.copyWith(
        errorMessage: errors.join('\n'),
        clearStatus: true,
      );
      _notifyIfActive();
      return null;
    }

    final compiled = _state.liveCompiledPrompt;
    _state = _state.copyWith(
      isSending: true,
      clearError: true,
      clearStatus: true,
    );
    _notifyIfActive();

    try {
      final PromptTemplateSendResult result;
      final customSender = _customSender;
      if (customSender != null) {
        final responseText = await customSender(compiled);
        result = PromptTemplateSendResult(
          responseText: responseText,
          providerLabel: 'external-api',
        );
      } else {
        result = await _repository.sendCompiledPrompt(compiled);
      }

      if (_isDisposed) {
        return null;
      }
      _state = _state.copyWith(
        isSending: false,
        lastApiResponse: result.responseText,
        lastSendProviderLabel: result.providerLabel,
        statusMessage: '外部API (${result.providerLabel}) へプロンプトを送信しました。',
      );
      return result;
    } catch (error) {
      if (_isDisposed) {
        return null;
      }
      _state = _state.copyWith(
        isSending: false,
        errorMessage: '外部API送信に失敗しました（入力内容は保持されています）: $error',
      );
      return null;
    } finally {
      _notifyIfActive();
    }
  }
}
