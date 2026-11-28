import 'package:flutter/foundation.dart';

import '../domain/org_idp_rbac_models.dart';

/// Immutable UI state for Org/IdP Group RBAC & SSO management (#2691).
class OrgIdpRbacState {
  const OrgIdpRbacState({
    this.isLoading = false,
    this.isSaving = false,
    this.organizations = const <OrgTenantSummary>[],
    this.selectedOrgId,
    this.selectedProvider = IdpProviderKind.okta,
    this.selectedMappedRole = OrgRbacRole.member,
    this.callerRole = OrgRbacRole.viewer,
    this.capabilities = const OrgUiCapabilities(
      role: OrgRbacRole.viewer,
      canViewOrg: false,
      canExecuteMemberActions: false,
      canManageIdpMappings: false,
      canAssignOwnerRole: false,
    ),
    this.mappings = const <IdpGroupMapping>[],
    this.audits = const <SsoAuditEntry>[],
    this.lastEvaluation,
    this.errorMessage,
    this.statusNotice,
  });

  final bool isLoading;
  final bool isSaving;
  final List<OrgTenantSummary> organizations;
  final String? selectedOrgId;
  final IdpProviderKind selectedProvider;
  final OrgRbacRole selectedMappedRole;
  final OrgRbacRole callerRole;
  final OrgUiCapabilities capabilities;
  final List<IdpGroupMapping> mappings;
  final List<SsoAuditEntry> audits;
  final SsoEvaluationResult? lastEvaluation;
  final String? errorMessage;
  final String? statusNotice;

  OrgIdpRbacState copyWith({
    final bool? isLoading,
    final bool? isSaving,
    final List<OrgTenantSummary>? organizations,
    final String? selectedOrgId,
    final IdpProviderKind? selectedProvider,
    final OrgRbacRole? selectedMappedRole,
    final OrgRbacRole? callerRole,
    final OrgUiCapabilities? capabilities,
    final List<IdpGroupMapping>? mappings,
    final List<SsoAuditEntry>? audits,
    final SsoEvaluationResult? lastEvaluation,
    final bool clearEvaluation = false,
    final String? errorMessage,
    final bool clearError = false,
    final String? statusNotice,
    final bool clearNotice = false,
  }) {
    return OrgIdpRbacState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      organizations: organizations ?? this.organizations,
      selectedOrgId: selectedOrgId ?? this.selectedOrgId,
      selectedProvider: selectedProvider ?? this.selectedProvider,
      selectedMappedRole: selectedMappedRole ?? this.selectedMappedRole,
      callerRole: callerRole ?? this.callerRole,
      capabilities: capabilities ?? this.capabilities,
      mappings: mappings ?? this.mappings,
      audits: audits ?? this.audits,
      lastEvaluation:
          clearEvaluation ? null : (lastEvaluation ?? this.lastEvaluation),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      statusNotice: clearNotice ? null : (statusNotice ?? this.statusNotice),
    );
  }
}

/// Application controller managing IdP RBAC state & role-gated actions (#2691).
class OrgIdpRbacController extends ChangeNotifier {
  OrgIdpRbacController({required final OrgIdpRbacRepository repository})
      : _repository = repository;

  final OrgIdpRbacRepository _repository;
  OrgIdpRbacState _state = const OrgIdpRbacState();
  bool _disposed = false;

  OrgIdpRbacState get state => _state;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _emit(final OrgIdpRbacState nextState) {
    if (_disposed) {
      return;
    }
    _state = nextState;
    notifyListeners();
  }

  Future<void> loadDashboard({final String? preferredOrgId}) async {
    _emit(_state.copyWith(isLoading: true, clearError: true));
    try {
      final orgs = List<OrgTenantSummary>.of(
        await _repository.fetchOrganizations(),
      );
      if (_disposed) return;

      final targetOrgId = preferredOrgId ??
          _state.selectedOrgId ??
          (orgs.isNotEmpty ? orgs.first.workosOrgId : null);

      if (targetOrgId == null || targetOrgId.isEmpty) {
        _emit(
          _state.copyWith(
            isLoading: false,
            organizations: orgs,
            mappings: const <IdpGroupMapping>[],
            audits: const <SsoAuditEntry>[],
          ),
        );
        return;
      }

      final bundle = await _repository.fetchOrgIdpState(targetOrgId);
      if (_disposed) return;

      _emit(
        _state.copyWith(
          isLoading: false,
          organizations: orgs,
          selectedOrgId: targetOrgId,
          callerRole: bundle.callerRole,
          capabilities: bundle.capabilities,
          mappings: List<IdpGroupMapping>.of(bundle.mappings),
          audits: List<SsoAuditEntry>.of(bundle.audits),
        ),
      );
    } catch (err) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isLoading: false,
          errorMessage: '組織 IdP RBAC 状態の読み込みに失敗しました: $err',
        ),
      );
    }
  }

  Future<void> selectOrganization(final String workosOrgId) async {
    await loadDashboard(preferredOrgId: workosOrgId);
  }

  void selectProvider(final IdpProviderKind provider) {
    _emit(_state.copyWith(selectedProvider: provider, clearError: true));
  }

  void selectMappedRole(final OrgRbacRole role) {
    _emit(_state.copyWith(selectedMappedRole: role, clearError: true));
  }

  Future<bool> saveMapping({
    required final String idpGroupId,
    required final String idpGroupLabel,
    final int priority = 100,
  }) async {
    final orgId = _state.selectedOrgId;
    if (orgId == null || orgId.isEmpty) {
      _emit(_state.copyWith(errorMessage: '対象組織を選択してください。'));
      return false;
    }
    if (!_state.capabilities.canManageIdpMappings) {
      _emit(
        _state.copyWith(
          errorMessage: '現在のロール (${_state.callerRole.label}) には管理者権限がありません。',
        ),
      );
      return false;
    }
    final trimmedGroup = idpGroupId.trim();
    if (trimmedGroup.isEmpty) {
      _emit(_state.copyWith(errorMessage: 'IdP グループ ID / グループ名を入力してください。'));
      return false;
    }

    _emit(
      _state.copyWith(
        isSaving: true,
        clearError: true,
        clearNotice: true,
      ),
    );
    try {
      final saved = await _repository.upsertMapping(
        workosOrgId: orgId,
        idpProvider: _state.selectedProvider,
        idpGroupId: trimmedGroup,
        idpGroupLabel: idpGroupLabel.trim(),
        mappedRole: _state.selectedMappedRole,
        priority: priority,
      );
      if (_disposed) return false;
      final bundle = await _repository.fetchOrgIdpState(orgId);
      if (_disposed) return false;
      _emit(
        _state.copyWith(
          isSaving: false,
          callerRole: bundle.callerRole,
          capabilities: bundle.capabilities,
          mappings: List<IdpGroupMapping>.of(bundle.mappings),
          audits: List<SsoAuditEntry>.of(bundle.audits),
          statusNotice:
              '${saved.idpProvider.label} グループ "${saved.idpGroupId}" → ${saved.mappedRole.label} を保存しました。',
        ),
      );
      return true;
    } catch (err) {
      if (_disposed) return false;
      _emit(
        _state.copyWith(
          isSaving: false,
          errorMessage: 'IdP グループマッピング保存に失敗しました: $err',
        ),
      );
      return false;
    }
  }

  Future<void> deleteMapping(final String mappingId) async {
    final orgId = _state.selectedOrgId;
    if (orgId == null || orgId.isEmpty) return;
    if (!_state.capabilities.canManageIdpMappings) {
      _emit(
        _state.copyWith(
          errorMessage: '現在のロール (${_state.callerRole.label}) ではマッピングを削除できません。',
        ),
      );
      return;
    }

    _emit(_state.copyWith(isSaving: true, clearError: true, clearNotice: true));
    try {
      await _repository.deleteMapping(
        workosOrgId: orgId,
        mappingId: mappingId,
      );
      if (_disposed) return;
      final bundle = await _repository.fetchOrgIdpState(orgId);
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSaving: false,
          callerRole: bundle.callerRole,
          capabilities: bundle.capabilities,
          mappings: List<IdpGroupMapping>.of(bundle.mappings),
          audits: List<SsoAuditEntry>.of(bundle.audits),
          statusNotice: 'IdP グループマッピングを削除しました。',
        ),
      );
    } catch (err) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSaving: false,
          errorMessage: 'IdP グループマッピング削除に失敗しました: $err',
        ),
      );
    }
  }

  Future<void> evaluateSso({
    required final String groupsCsv,
    final bool simulateAzureOverage = false,
    final OrgRbacRole requiredRole = OrgRbacRole.viewer,
  }) async {
    final orgId = _state.selectedOrgId;
    if (orgId == null || orgId.isEmpty) {
      _emit(_state.copyWith(errorMessage: '対象組織を選択してください。'));
      return;
    }

    final parsedGroups = groupsCsv
        .split(RegExp(r'[,;\n]+'))
        .map((final String item) => item.trim())
        .where((final String item) => item.isNotEmpty)
        .toList();

    _emit(
      _state.copyWith(
        isSaving: true,
        clearError: true,
        clearNotice: true,
      ),
    );
    try {
      final result = await _repository.evaluateSsoAssertion(
        workosOrgId: orgId,
        idpProvider: _state.selectedProvider,
        assertedGroups: parsedGroups,
        simulateAzureOverage: simulateAzureOverage,
        requiredRole: requiredRole,
      );
      if (_disposed) return;

      _emit(
        _state.copyWith(
          isSaving: false,
          callerRole: result.resolvedRole,
          capabilities: result.capabilities,
          lastEvaluation: result,
          statusNotice: result.allowed
              ? 'SSO ロール判定: ${result.resolvedRole.label} (${result.resolutionSource})'
              : 'SSO アクセス拒否 (${result.resolutionSource})',
        ),
      );
    } catch (err) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSaving: false,
          errorMessage: 'SSO クレーム評価に失敗しました: $err',
        ),
      );
    }
  }
}
