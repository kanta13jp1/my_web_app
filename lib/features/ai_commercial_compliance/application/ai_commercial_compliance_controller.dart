import 'package:flutter/foundation.dart';

import '../data/supabase_ai_commercial_compliance_repository.dart';
import '../domain/ai_commercial_compliance_models.dart';

/// AI 商用ライセンス・著作権コンプライアンス制御コントローラ (#2664).
class AiCommercialComplianceController extends ChangeNotifier {
  AiCommercialComplianceController({
    final AiCommercialComplianceRepository? repository,
    final AiCommercialComplianceState initialState =
        const AiCommercialComplianceState(),
  })  : _repository = repository ?? SupabaseAiCommercialComplianceRepository(),
        _state = initialState;

  final AiCommercialComplianceRepository _repository;
  AiCommercialComplianceState _state;
  bool _isDisposed = false;

  AiCommercialComplianceState get state => _state;

  void _notifySafely() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void setProvider(final ComplianceAiProvider provider) {
    if (_isDisposed) {
      return;
    }
    _state = _state.copyWith(selectedProvider: provider, clearError: true);
    _notifySafely();
  }

  void setPlanTier(final GenerationPlanTier tier) {
    if (_isDisposed) {
      return;
    }
    _state = _state.copyWith(selectedPlanTier: tier, clearError: true);
    _notifySafely();
  }

  void setCommercialLicenseVerified(final bool verified) {
    if (_isDisposed) {
      return;
    }
    _state = _state.copyWith(
      commercialLicenseVerified: verified,
      clearError: true,
    );
    _notifySafely();
  }

  void setCopyrightNonSimilarityConfirmed(final bool confirmed) {
    if (_isDisposed) {
      return;
    }
    _state = _state.copyWith(
      copyrightNonSimilarityConfirmed: confirmed,
      clearError: true,
    );
    _notifySafely();
  }

  void toggleRuleAcceptance(final String ruleId, final bool accepted) {
    if (_isDisposed) {
      return;
    }
    final Set<String> nextAccepted = Set<String>.from(_state.acceptedRuleIds);
    if (accepted) {
      nextAccepted.add(ruleId);
    } else {
      nextAccepted.remove(ruleId);
    }
    _state = _state.copyWith(acceptedRuleIds: nextAccepted, clearError: true);
    _notifySafely();
  }

  Future<void> loadDashboard() async {
    if (_isDisposed) {
      return;
    }
    _state = _state.copyWith(isLoading: true, clearError: true);
    _notifySafely();

    try {
      final AiComplianceDashboardData data =
          await _repository.fetchDashboardData();
      if (_isDisposed) {
        return;
      }
      _state = _state.copyWith(
        isLoading: false,
        isAdmin: data.isAdmin,
        rules: data.rules,
        submissions: data.submissions,
        auditLogs: data.auditLogs,
      );
    } catch (error) {
      if (_isDisposed) {
        return;
      }
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'コンプライアンス情報の読み込みに失敗しました: $error',
      );
    } finally {
      if (!_isDisposed && _state.isLoading) {
        _state = _state.copyWith(isLoading: false);
      }
      _notifySafely();
    }
  }

  Future<bool> submitConsent({required final String assetTitle}) async {
    if (_isDisposed || _state.isSubmitting) {
      return false;
    }
    final SubmitCommercialComplianceInput input =
        SubmitCommercialComplianceInput(
      assetTitle: assetTitle,
      aiProvider: _state.selectedProvider,
      planTier: _state.selectedPlanTier,
      commercialLicenseVerified: _state.commercialLicenseVerified,
      copyrightNonSimilarityConfirmed: _state.copyrightNonSimilarityConfirmed,
      acceptedRuleIds: _state.acceptedRuleIds,
    );
    final String? validationError = input.validateAgainstRules(_state.rules);
    if (validationError != null) {
      _state = _state.copyWith(errorMessage: validationError);
      _notifySafely();
      return false;
    }

    _state = _state.copyWith(isSubmitting: true, clearError: true);
    _notifySafely();

    try {
      final AiCommercialAssetSubmission created =
          await _repository.submitComplianceConsent(input);
      if (_isDisposed) {
        return false;
      }
      final AiComplianceDashboardData refreshed =
          await _repository.fetchDashboardData();
      if (_isDisposed) {
        return false;
      }
      _state = _state.copyWith(
        isSubmitting: false,
        lastClearedSubmissionId: created.id,
        isAdmin: refreshed.isAdmin,
        rules: refreshed.rules,
        submissions: refreshed.submissions,
        auditLogs: refreshed.auditLogs,
      );
      return true;
    } catch (error) {
      if (_isDisposed) {
        return false;
      }
      _state = _state.copyWith(
        isSubmitting: false,
        errorMessage: 'コンプライアンス同意の保存に失敗しました: $error',
      );
      return false;
    } finally {
      if (!_isDisposed && _state.isSubmitting) {
        _state = _state.copyWith(isSubmitting: false);
      }
      _notifySafely();
    }
  }

  Future<bool> upsertRule({
    required final String ruleKey,
    required final ComplianceAiProvider aiProvider,
    required final String title,
    required final String disclaimerBody,
  }) async {
    if (_isDisposed || _state.isSubmitting) {
      return false;
    }
    final UpsertComplianceRuleInput input = UpsertComplianceRuleInput(
      ruleKey: ruleKey,
      aiProvider: aiProvider,
      title: title,
      disclaimerBody: disclaimerBody,
    );
    final String? validationError = input.validate();
    if (validationError != null) {
      _state = _state.copyWith(errorMessage: validationError);
      _notifySafely();
      return false;
    }

    _state = _state.copyWith(isSubmitting: true, clearError: true);
    _notifySafely();

    try {
      await _repository.upsertChecklistRule(input);
      if (_isDisposed) {
        return false;
      }
      final AiComplianceDashboardData refreshed =
          await _repository.fetchDashboardData();
      if (_isDisposed) {
        return false;
      }
      _state = _state.copyWith(
        isSubmitting: false,
        rules: refreshed.rules,
        submissions: refreshed.submissions,
        auditLogs: refreshed.auditLogs,
      );
      return true;
    } catch (error) {
      if (_isDisposed) {
        return false;
      }
      _state = _state.copyWith(
        isSubmitting: false,
        errorMessage: 'チェック項目の更新に失敗しました: $error',
      );
      return false;
    } finally {
      if (!_isDisposed && _state.isSubmitting) {
        _state = _state.copyWith(isSubmitting: false);
      }
      _notifySafely();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
