import 'package:flutter/foundation.dart';

import '../data/supabase_organization_audit_quota_repository.dart';
import '../domain/organization_audit_quota_models.dart';

/// 組織監査ログ・クォータダッシュボードの不変状態 (#2692).
@immutable
class OrganizationAuditQuotaState {
  const OrganizationAuditQuotaState({
    required this.organizationId,
    required this.periodKey,
    required this.quotas,
    required this.alerts,
    required this.auditLogs,
    required this.selectedFilter,
    required this.isLoading,
    required this.isSubmitting,
    this.errorMessage,
    this.quotaBlockedMessage,
    this.statusMessage,
  });

  factory OrganizationAuditQuotaState.initial({
    required final String organizationId,
  }) {
    return OrganizationAuditQuotaState(
      organizationId: organizationId,
      periodKey: '',
      quotas: const <OrganizationQuotaUsage>[],
      alerts: const <OrganizationQuotaAlert>[],
      auditLogs: const <OrganizationAuditLogEntry>[],
      selectedFilter: OrgAuditEventType.all,
      isLoading: false,
      isSubmitting: false,
    );
  }

  final String organizationId;
  final String periodKey;
  final List<OrganizationQuotaUsage> quotas;
  final List<OrganizationQuotaAlert> alerts;
  final List<OrganizationAuditLogEntry> auditLogs;
  final OrgAuditEventType selectedFilter;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final String? quotaBlockedMessage;
  final String? statusMessage;

  List<OrganizationAuditLogEntry> get filteredLogs {
    if (selectedFilter == OrgAuditEventType.all) {
      return auditLogs;
    }
    return auditLogs
        .where(
          (final OrganizationAuditLogEntry log) =>
              log.eventType == selectedFilter,
        )
        .toList(growable: false);
  }

  List<OrganizationQuotaAlert> get activeWarningAlerts => alerts
      .where(
        (final OrganizationQuotaAlert a) =>
            a.alertLevel == OrgQuotaAlertLevel.warning80 && !a.isAcknowledged,
      )
      .toList(growable: false);

  bool get hasWarning80 =>
      activeWarningAlerts.isNotEmpty ||
      quotas.any((final OrganizationQuotaUsage q) => q.isWarning80);

  OrganizationAuditQuotaState copyWith({
    final String? periodKey,
    final List<OrganizationQuotaUsage>? quotas,
    final List<OrganizationQuotaAlert>? alerts,
    final List<OrganizationAuditLogEntry>? auditLogs,
    final OrgAuditEventType? selectedFilter,
    final bool? isLoading,
    final bool? isSubmitting,
    final String? errorMessage,
    final bool clearError = false,
    final String? quotaBlockedMessage,
    final bool clearQuotaBlocked = false,
    final String? statusMessage,
    final bool clearStatus = false,
  }) {
    return OrganizationAuditQuotaState(
      organizationId: organizationId,
      periodKey: periodKey ?? this.periodKey,
      quotas: quotas ?? this.quotas,
      alerts: alerts ?? this.alerts,
      auditLogs: auditLogs ?? this.auditLogs,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      quotaBlockedMessage: clearQuotaBlocked
          ? null
          : (quotaBlockedMessage ?? this.quotaBlockedMessage),
      statusMessage: clearStatus ? null : (statusMessage ?? this.statusMessage),
    );
  }
}

/// 組織監査ログ・クォータ制御のアプリケーション Controller (#2692).
class OrganizationAuditQuotaController extends ChangeNotifier {
  OrganizationAuditQuotaController({
    required final OrganizationAuditQuotaRepository repository,
    required final String organizationId,
  })  : _repository = repository,
        _state = OrganizationAuditQuotaState.initial(
          organizationId: organizationId,
        );

  final OrganizationAuditQuotaRepository _repository;
  OrganizationAuditQuotaState _state;
  bool _isDisposed = false;

  OrganizationAuditQuotaState get state => _state;
  bool get isDisposed => _isDisposed;

  void _setState(final OrganizationAuditQuotaState next) {
    if (_isDisposed) return;
    _state = next;
    notifyListeners();
  }

  Future<void> loadDashboard() async {
    if (_isDisposed) return;
    _setState(_state.copyWith(isLoading: true, clearError: true));
    try {
      final OrganizationAuditQuotaDashboard data =
          await _repository.fetchDashboard(
        organizationId: _state.organizationId,
        eventFilter: _state.selectedFilter,
      );
      if (_isDisposed) return;
      _setState(
        _state.copyWith(
          periodKey: data.periodKey,
          quotas: data.quotas,
          alerts: data.alerts,
          auditLogs: data.auditLogs,
          isLoading: false,
        ),
      );
    } catch (exc) {
      if (_isDisposed) return;
      _setState(
        _state.copyWith(
          isLoading: false,
          errorMessage: '組織監査ログ・クォータの取得に失敗しました: $exc',
        ),
      );
    }
  }

  Future<void> selectFilter(final OrgAuditEventType filter) async {
    if (_isDisposed) return;
    _setState(_state.copyWith(selectedFilter: filter));
    await loadDashboard();
  }

  Future<void> recordEvent({
    required final OrgAuditEventType eventType,
    required final String resourceType,
    final String resourceId = '',
    final String summary = '',
  }) async {
    if (_isDisposed) return;
    _setState(
      _state.copyWith(
        isSubmitting: true,
        clearError: true,
        clearStatus: true,
      ),
    );
    try {
      await _repository.recordAuditEvent(
        organizationId: _state.organizationId,
        eventType: eventType,
        resourceType: resourceType,
        resourceId: resourceId,
        summary: summary,
      );
      if (_isDisposed) return;
      _setState(
        _state.copyWith(
          isSubmitting: false,
          statusMessage: '${eventType.labelJa} を監査ログへ記録しました。',
        ),
      );
      await loadDashboard();
    } catch (exc) {
      if (_isDisposed) return;
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: '監査イベント記録に失敗しました: $exc',
        ),
      );
    }
  }

  Future<OrgQuotaConsumeOutcome?> consumeResourceQuota({
    required final OrgQuotaResourceType resourceType,
    final int units = 1,
  }) async {
    if (_isDisposed) return null;
    _setState(
      _state.copyWith(
        isSubmitting: true,
        clearError: true,
        clearQuotaBlocked: true,
        clearStatus: true,
      ),
    );
    try {
      final OrgQuotaConsumeOutcome outcome = await _repository.consumeQuota(
        organizationId: _state.organizationId,
        resourceType: resourceType,
        units: units,
      );
      if (_isDisposed) return outcome;
      if (!outcome.allowed) {
        _setState(
          _state.copyWith(
            isSubmitting: false,
            quotaBlockedMessage:
                outcome.errorMessage ?? '組織のリソース利用上限に達したため処理をブロックしました。',
          ),
        );
      } else {
        final String msg = outcome.alertTriggered
            ? '${resourceType.labelJa} が80%警告閾値に到達したため管理者通知を送信しました (${outcome.usedAmount}/${outcome.limitAmount})。'
            : '${resourceType.labelJa} を利用記録しました (${outcome.usedAmount}/${outcome.limitAmount})。';
        _setState(
          _state.copyWith(
            isSubmitting: false,
            statusMessage: msg,
          ),
        );
      }
      await loadDashboard();
      return outcome;
    } on OrgQuotaExceededException catch (quotaExc) {
      if (_isDisposed) return null;
      _setState(
        _state.copyWith(
          isSubmitting: false,
          quotaBlockedMessage: quotaExc.message,
        ),
      );
      await loadDashboard();
      return null;
    } catch (exc) {
      if (_isDisposed) return null;
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: 'クォータ判定処理に失敗しました: $exc',
        ),
      );
      return null;
    }
  }

  Future<void> updateQuotaLimit({
    required final OrgQuotaResourceType resourceType,
    required final int limitAmount,
    final double warningThresholdPct = 80.0,
  }) async {
    if (_isDisposed) return;
    _setState(
      _state.copyWith(
        isSubmitting: true,
        clearError: true,
        clearQuotaBlocked: true,
        clearStatus: true,
      ),
    );
    try {
      await _repository.updateQuotaLimit(
        organizationId: _state.organizationId,
        resourceType: resourceType,
        limitAmount: limitAmount,
        warningThresholdPct: warningThresholdPct,
      );
      if (_isDisposed) return;
      _setState(
        _state.copyWith(
          isSubmitting: false,
          statusMessage:
              '${resourceType.labelJa} の上限を $limitAmount ${resourceType.unitLabel} へ更新しました。',
        ),
      );
      await loadDashboard();
    } catch (exc) {
      if (_isDisposed) return;
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: 'クォータ上限更新に失敗しました: $exc',
        ),
      );
    }
  }

  Future<void> acknowledgeAlert(final String alertId) async {
    if (_isDisposed) return;
    _setState(_state.copyWith(isSubmitting: true, clearError: true));
    try {
      await _repository.acknowledgeAlert(
        organizationId: _state.organizationId,
        alertId: alertId,
      );
      if (_isDisposed) return;
      _setState(
        _state.copyWith(
          isSubmitting: false,
          statusMessage: '管理者アラートを確認済みにしました。',
        ),
      );
      await loadDashboard();
    } catch (exc) {
      if (_isDisposed) return;
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: 'アラート確認更新に失敗しました: $exc',
        ),
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
