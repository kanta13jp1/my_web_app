import 'package:flutter/foundation.dart';

import '../models/ai_form_assistant.dart';
import '../services/ai_form_assistant_service.dart';

class AiFormAssistantViewModel extends ChangeNotifier {
  AiFormAssistantViewModel({
    required AiFormAssistantGateway gateway,
    required AiFormSettingsStore settingsStore,
    this.fields = aiWorkflowFormFields,
  })  : _gateway = gateway,
        _settingsStore = settingsStore,
        _values = <String, Object>{
          for (final field in fields) field.id: field.defaultValue,
        },
        _fieldRevisions = <String, int>{
          for (final field in fields) field.id: 0,
        };

  final AiFormAssistantGateway _gateway;
  final AiFormSettingsStore _settingsStore;
  final List<AiFormFieldDefinition> fields;
  final Map<String, Object> _values;
  final Map<String, int> _fieldRevisions;
  final List<AiFormChatMessage> _messages = <AiFormChatMessage>[
    const AiFormChatMessage(
      role: AiFormChatRole.assistant,
      text: '実現したい設定を教えてください。不足情報を確認し、フォームへの変更案を作ります。',
    ),
  ];

  bool _initialized = false;
  bool _initializing = false;
  bool _isSubmitting = false;
  bool _isSaving = false;
  bool _disposed = false;
  String? _errorMessage;
  AiFormProposal? _pendingProposal;

  bool get initialized => _initialized;
  bool get isSubmitting => _isSubmitting;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  AiFormProposal? get pendingProposal => _pendingProposal;
  Map<String, Object> get values => Map<String, Object>.unmodifiable(_values);
  List<AiFormChatMessage> get messages =>
      List<AiFormChatMessage>.unmodifiable(_messages);

  Object valueFor(String fieldId) => _values[fieldId] ?? '';

  Future<void> initialize() async {
    if (_initialized || _initializing) return;
    _initializing = true;
    try {
      final stored = await _settingsStore.load();
      for (final field in fields) {
        final value = field.normalizeAiValue(stored[field.id]);
        if (value != null) _values[field.id] = value;
      }
      _initialized = true;
      _errorMessage = null;
    } catch (_) {
      _initialized = true;
      _errorMessage = '保存済み設定を読み込めなかったため、初期値を表示しています。';
    } finally {
      _initializing = false;
      _notifyListeners();
    }
  }

  void updateField(String fieldId, Object value) {
    final field = _fieldFor(fieldId);
    if (field == null) return;
    final normalized = _normalizeManualValue(field, value);
    if (normalized == null || _values[fieldId] == normalized) return;
    _values[fieldId] = normalized;
    _fieldRevisions[fieldId] = (_fieldRevisions[fieldId] ?? 0) + 1;
    _errorMessage = null;
    _notifyListeners();
  }

  String? validationErrorFor(String fieldId) {
    final field = _fieldFor(fieldId);
    if (field == null) return null;
    final baseError = field.validate(_values[fieldId]);
    if (baseError != null) return baseError;
    if (fieldId == 'approver' &&
        valueFor('approval_required') == true &&
        valueFor('approver').toString().trim().isEmpty) {
      return '承認を必須にする場合は承認者を入力してください';
    }
    return null;
  }

  bool get hasValidationErrors =>
      fields.any((field) => validationErrorFor(field.id) != null);

  Future<bool> submit(String request) async {
    final normalized = request.trim();
    if (normalized.isEmpty || _isSubmitting) return false;

    final valueSnapshot = Map<String, Object>.from(_values);
    final revisionSnapshot = Map<String, int>.from(_fieldRevisions);
    _messages.add(
      AiFormChatMessage(role: AiFormChatRole.user, text: normalized),
    );
    _isSubmitting = true;
    _errorMessage = null;
    _notifyListeners();

    try {
      final reply = await _gateway.propose(
        request: normalized,
        currentValues: valueSnapshot,
        history: List<AiFormChatMessage>.unmodifiable(_messages),
      );
      _messages.add(
        AiFormChatMessage(role: AiFormChatRole.assistant, text: reply.message),
      );
      _pendingProposal = reply.changes.isEmpty
          ? null
          : AiFormProposal(
              changes: reply.changes,
              baseFieldRevisions: revisionSnapshot,
            );
      return true;
    } catch (error) {
      final message = error is AiFormAssistantException
          ? error.message
          : 'AIへの接続に失敗しました。手入力はそのまま利用できます。';
      _errorMessage = message;
      _messages.add(
        AiFormChatMessage(role: AiFormChatRole.assistant, text: message),
      );
      return false;
    } finally {
      _isSubmitting = false;
      _notifyListeners();
    }
  }

  bool isChangeStale(AiFormChange change) {
    final proposal = _pendingProposal;
    if (proposal == null) return false;
    return (_fieldRevisions[change.fieldId] ?? 0) !=
        (proposal.baseFieldRevisions[change.fieldId] ?? 0);
  }

  AiFormApplyResult applyPendingProposal() {
    final proposal = _pendingProposal;
    if (proposal == null) {
      return const AiFormApplyResult(
        applied: <AiFormChange>[],
        skipped: <AiFormChange>[],
      );
    }
    final applied = <AiFormChange>[];
    final skipped = <AiFormChange>[];
    for (final change in proposal.changes) {
      final baseRevision = proposal.baseFieldRevisions[change.fieldId] ?? 0;
      final currentRevision = _fieldRevisions[change.fieldId] ?? 0;
      if (currentRevision != baseRevision) {
        skipped.add(change);
        continue;
      }
      _values[change.fieldId] = change.value;
      _fieldRevisions[change.fieldId] = currentRevision + 1;
      applied.add(change);
    }
    _pendingProposal = null;
    _messages.add(
      AiFormChatMessage(
        role: AiFormChatRole.assistant,
        text: skipped.isEmpty
            ? '${applied.length}項目をフォームへ反映しました。'
            : '${applied.length}項目を反映し、手入力が新しい${skipped.length}項目は上書きせず保護しました。',
      ),
    );
    _notifyListeners();
    return AiFormApplyResult(
      applied: List<AiFormChange>.unmodifiable(applied),
      skipped: List<AiFormChange>.unmodifiable(skipped),
    );
  }

  void discardPendingProposal() {
    if (_pendingProposal == null) return;
    _pendingProposal = null;
    _messages.add(
      const AiFormChatMessage(
        role: AiFormChatRole.assistant,
        text: '変更案を破棄しました。フォームは変更していません。',
      ),
    );
    _notifyListeners();
  }

  Future<bool> save() async {
    if (_isSaving || hasValidationErrors) return false;
    _isSaving = true;
    _errorMessage = null;
    _notifyListeners();
    try {
      await _settingsStore.save(Map<String, Object>.from(_values));
      return true;
    } catch (_) {
      _errorMessage = '設定を保存できませんでした。';
      return false;
    } finally {
      _isSaving = false;
      _notifyListeners();
    }
  }

  AiFormFieldDefinition? _fieldFor(String fieldId) {
    for (final field in fields) {
      if (field.id == fieldId) return field;
    }
    return null;
  }

  Object? _normalizeManualValue(AiFormFieldDefinition field, Object rawValue) {
    switch (field.kind) {
      case AiFormFieldKind.text:
      case AiFormFieldKind.multiline:
        return rawValue.toString();
      case AiFormFieldKind.choice:
      case AiFormFieldKind.boolean:
        return field.normalizeAiValue(rawValue);
    }
  }

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
