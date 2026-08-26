import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/proactive_form_validator.dart';
import '../domain/proactive_form_check_models.dart';

enum ProactiveValidationStatus { idle, waiting, validating, ready, failure }

class ProactiveFormCheckViewModel extends ChangeNotifier {
  ProactiveFormCheckViewModel({
    required ProactiveFormValidator validator,
    this.debounceDuration = const Duration(milliseconds: 550),
  }) : _validator = validator;

  final ProactiveFormValidator _validator;
  final Duration debounceDuration;

  ProactiveFormDraft _draft = const ProactiveFormDraft();
  ProactiveValidationResult _result = const ProactiveValidationResult(
    <ProactiveValidationFinding>[],
  );
  final Set<ProactiveFormField> _touchedFields = <ProactiveFormField>{};
  ProactiveValidationStatus _status = ProactiveValidationStatus.idle;
  Timer? _debounce;
  int _revision = 0;
  bool _isSubmitting = false;
  bool _wasSubmitted = false;
  bool _isDisposed = false;
  String? _errorMessage;

  ProactiveFormDraft get draft => _draft;
  ProactiveValidationStatus get status => _status;
  bool get isSubmitting => _isSubmitting;
  bool get wasSubmitted => _wasSubmitted;
  String? get errorMessage => _errorMessage;

  List<ProactiveValidationFinding> get visibleFindings => _result.findings
      .where((finding) => _touchedFields.contains(finding.field))
      .toList(growable: false);

  bool get hasBlockingFinding =>
      visibleFindings.any((finding) => finding.blocksSubmission);

  bool get canSubmit =>
      _draft.hasAllRequiredValues &&
      _status == ProactiveValidationStatus.ready &&
      !_result.hasBlockingFinding &&
      !_isSubmitting;

  void updateField(ProactiveFormField field, String value) {
    if (_isDisposed) return;
    _draft = _draft.withValue(field, value);
    _touchedFields.add(field);
    _wasSubmitted = false;
    _errorMessage = null;
    _debounce?.cancel();
    _revision += 1;

    if (_draft.isEmpty) {
      _result = const ProactiveValidationResult(<ProactiveValidationFinding>[]);
      _status = ProactiveValidationStatus.idle;
      notifyListeners();
      return;
    }

    _status = ProactiveValidationStatus.waiting;
    final scheduledRevision = _revision;
    _debounce = Timer(debounceDuration, () => _validate(scheduledRevision));
    notifyListeners();
  }

  Future<void> validateNow() async {
    if (_isDisposed) return;
    _debounce?.cancel();
    _revision += 1;
    await _validate(_revision);
  }

  Future<void> applySuggestion(ProactiveValidationFinding finding) async {
    if (_isDisposed) return;
    final suggestion = finding.suggestedValue;
    if (suggestion == null) return;
    _draft = _draft.withValue(finding.field, suggestion);
    _touchedFields.add(finding.field);
    _wasSubmitted = false;
    await validateNow();
  }

  Future<bool> submit() async {
    if (_isDisposed || _isSubmitting) return false;
    _isSubmitting = true;
    _wasSubmitted = false;
    _errorMessage = null;
    notifyListeners();
    try {
      for (final field in ProactiveFormField.values) {
        _touchedFields.add(field);
      }
      await validateNow();
      if (_isDisposed) return false;
      if (_status != ProactiveValidationStatus.ready ||
          !_draft.hasAllRequiredValues ||
          _result.hasBlockingFinding) {
        _errorMessage = _status == ProactiveValidationStatus.failure
            ? '入力内容を検証できないため送信を中止しました。再試行してください。'
            : _draft.hasAllRequiredValues
                ? '解決が必要な項目を修正してから送信してください。'
                : '未入力の項目を入力してから送信してください。';
        return false;
      }

      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (_isDisposed) return false;
      _wasSubmitted = true;
      return true;
    } finally {
      _isSubmitting = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<void> _validate(int requestedRevision) async {
    if (_isDisposed || _draft.isEmpty || requestedRevision != _revision) {
      return;
    }
    final snapshot = _draft;
    _status = ProactiveValidationStatus.validating;
    notifyListeners();
    try {
      final result = await _validator.validate(snapshot);
      if (_isDisposed || requestedRevision != _revision) return;
      _result = result;
      _status = ProactiveValidationStatus.ready;
      _errorMessage = null;
    } catch (_) {
      if (_isDisposed || requestedRevision != _revision) return;
      _status = ProactiveValidationStatus.failure;
      _errorMessage = '入力内容を検証できませんでした。通信状況を確認して再試行してください。';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _debounce?.cancel();
    _revision += 1;
    super.dispose();
  }
}
