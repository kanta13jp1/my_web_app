import 'package:flutter/foundation.dart';

import '../domain/workos_scim_models.dart';

class WorkosScimState {
  const WorkosScimState({
    required this.organizations,
    required this.members,
    required this.events,
    this.selectedOrgId,
    this.statusFilter,
    this.selectedIntent = WorkosPortalIntent.dsync,
    this.latestPortalResult,
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.statusNotice,
  });

  factory WorkosScimState.initial() => const WorkosScimState(
        organizations: <WorkosOrganization>[],
        members: <WorkosDirectoryMember>[],
        events: <WorkosScimEvent>[],
      );

  final List<WorkosOrganization> organizations;
  final List<WorkosDirectoryMember> members;
  final List<WorkosScimEvent> events;
  final String? selectedOrgId;
  final WorkosProvisioningStatus? statusFilter;
  final WorkosPortalIntent selectedIntent;
  final WorkosPortalLinkResult? latestPortalResult;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final String? statusNotice;

  WorkosOrganization? get selectedOrganization {
    if (organizations.isEmpty) {
      return null;
    }
    for (final org in organizations) {
      if (org.workosOrgId == selectedOrgId) {
        return org;
      }
    }
    return organizations.first;
  }

  List<WorkosDirectoryMember> get filteredMembers {
    if (statusFilter == null) {
      return members;
    }
    return members
        .where((final WorkosDirectoryMember m) => m.status == statusFilter)
        .toList();
  }

  WorkosScimState copyWith({
    final List<WorkosOrganization>? organizations,
    final List<WorkosDirectoryMember>? members,
    final List<WorkosScimEvent>? events,
    final String? selectedOrgId,
    final WorkosProvisioningStatus? statusFilter,
    final bool clearStatusFilter = false,
    final WorkosPortalIntent? selectedIntent,
    final WorkosPortalLinkResult? latestPortalResult,
    final bool clearPortalResult = false,
    final bool? isLoading,
    final bool? isSubmitting,
    final String? errorMessage,
    final bool clearError = false,
    final String? statusNotice,
    final bool clearNotice = false,
  }) {
    return WorkosScimState(
      organizations: organizations ?? this.organizations,
      members: members ?? this.members,
      events: events ?? this.events,
      selectedOrgId: selectedOrgId ?? this.selectedOrgId,
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      selectedIntent: selectedIntent ?? this.selectedIntent,
      latestPortalResult: clearPortalResult
          ? null
          : (latestPortalResult ?? this.latestPortalResult),
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      statusNotice: clearNotice ? null : (statusNotice ?? this.statusNotice),
    );
  }
}

class WorkosScimController extends ChangeNotifier {
  WorkosScimController({required final WorkosScimRepository repository})
      : _repository = repository,
        _state = WorkosScimState.initial();

  final WorkosScimRepository _repository;
  WorkosScimState _state;
  bool _disposed = false;

  WorkosScimState get state => _state;

  void _setState(final WorkosScimState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> loadDashboard({final String? orgIdOverride}) async {
    _setState(
      _state.copyWith(
        isLoading: true,
        clearError: true,
      ),
    );
    try {
      final orgs = await _repository.fetchOrganizations();
      if (_disposed) {
        return;
      }
      final activeOrgId = orgIdOverride ??
          _state.selectedOrgId ??
          (orgs.isNotEmpty ? orgs.first.workosOrgId : null);
      if (activeOrgId == null) {
        _setState(
          _state.copyWith(
            organizations: orgs,
            members: const <WorkosDirectoryMember>[],
            events: const <WorkosScimEvent>[],
            isLoading: false,
          ),
        );
        return;
      }
      final members = await _repository.fetchMembers(activeOrgId);
      final events = await _repository.fetchRecentEvents(activeOrgId);
      if (_disposed) {
        return;
      }
      _setState(
        _state.copyWith(
          organizations: orgs,
          selectedOrgId: activeOrgId,
          members: members,
          events: events,
          isLoading: false,
        ),
      );
    } on Object catch (err) {
      _setState(
        _state.copyWith(
          isLoading: false,
          errorMessage: '読み込みに失敗しました: $err',
        ),
      );
    }
  }

  Future<void> selectOrganization(final String workosOrgId) async {
    _setState(
      _state.copyWith(
        selectedOrgId: workosOrgId,
        clearPortalResult: true,
        clearNotice: true,
      ),
    );
    await loadDashboard(orgIdOverride: workosOrgId);
  }

  void selectIntent(final WorkosPortalIntent intent) {
    _setState(_state.copyWith(selectedIntent: intent));
  }

  void selectStatusFilter(final WorkosProvisioningStatus? status) {
    if (status == null) {
      _setState(_state.copyWith(clearStatusFilter: true));
    } else {
      _setState(_state.copyWith(statusFilter: status));
    }
  }

  Future<bool> registerOrganization({
    required final String workosOrgId,
    required final String organizationName,
  }) async {
    final cleanId = workosOrgId.trim();
    final cleanName = organizationName.trim();
    if (cleanId.isEmpty || cleanName.isEmpty) {
      _setState(
        _state.copyWith(errorMessage: 'WorkOS Organization ID と組織名を入力してください。'),
      );
      return false;
    }
    _setState(
      _state.copyWith(isSubmitting: true, clearError: true, clearNotice: true),
    );
    try {
      final created = await _repository.registerOrganization(
        workosOrgId: cleanId,
        organizationName: cleanName,
      );
      if (_disposed) {
        return false;
      }
      final nextOrgs = List<WorkosOrganization>.unmodifiable(
        <WorkosOrganization>[
          created,
          ..._state.organizations.where(
            (final WorkosOrganization o) =>
                o.workosOrgId != created.workosOrgId,
          ),
        ],
      );
      _setState(
        _state.copyWith(
          organizations: nextOrgs,
          selectedOrgId: created.workosOrgId,
          isSubmitting: false,
          statusNotice: '組織「${created.organizationName}」を登録しました。',
        ),
      );
      return true;
    } on Object catch (err) {
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: '組織登録に失敗しました: $err',
        ),
      );
      return false;
    }
  }

  Future<void> generateAdminPortalLink({final String? returnUrl}) async {
    final org = _state.selectedOrganization;
    if (org == null) {
      _setState(
        _state.copyWith(errorMessage: '先に WorkOS 組織を登録または選択してください。'),
      );
      return;
    }
    _setState(
      _state.copyWith(
        isSubmitting: true,
        clearError: true,
        clearNotice: true,
      ),
    );
    try {
      final res = await _repository.generateAdminPortalLink(
        workosOrgId: org.workosOrgId,
        intent: _state.selectedIntent,
        returnUrl: returnUrl,
      );
      if (_disposed) {
        return;
      }
      _setState(
        _state.copyWith(
          latestPortalResult: res,
          isSubmitting: false,
          statusNotice: res.isOfflineFallback
              ? res.message
              : 'Admin Portal (${res.intent.label}) リンクを生成しました。',
        ),
      );
    } on Object catch (err) {
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: 'ポータルリンク生成に失敗しました: $err',
        ),
      );
    }
  }

  Future<void> updateMemberRole({
    required final String directoryUserId,
    required final WorkosOrgRole role,
  }) async {
    final org = _state.selectedOrganization;
    if (org == null) {
      return;
    }
    _setState(_state.copyWith(isSubmitting: true, clearError: true));
    try {
      final updated = await _repository.updateMemberRole(
        workosOrgId: org.workosOrgId,
        directoryUserId: directoryUserId,
        role: role,
      );
      if (_disposed) {
        return;
      }
      final nextMembers = List<WorkosDirectoryMember>.unmodifiable(
        _state.members.map(
          (final WorkosDirectoryMember m) =>
              m.directoryUserId == updated.directoryUserId ? updated : m,
        ),
      );
      _setState(
        _state.copyWith(
          members: nextMembers,
          isSubmitting: false,
          statusNotice: '${updated.email} のロールを ${updated.role.label} に更新しました。',
        ),
      );
    } on Object catch (err) {
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: 'ロール更新に失敗しました: $err',
        ),
      );
    }
  }
}
