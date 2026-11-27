import 'package:flutter/foundation.dart';

import '../domain/agent_sandbox_models.dart';

/// エージェント隔離サンドボックス監視・実行ガード状態管理 (#2722)。
class AgentSandboxController extends ChangeNotifier {
  AgentSandboxController({
    required AgentSandboxRepository repository,
    List<AgentSandboxAuditEntry>? initialAudits,
  })  : _repository = repository,
        _audits = List<AgentSandboxAuditEntry>.from(
          initialAudits ?? const <AgentSandboxAuditEntry>[],
        );

  final AgentSandboxRepository _repository;
  final List<AgentSandboxAuditEntry> _audits;
  final List<AgentSandboxPolicy> _policies = <AgentSandboxPolicy>[];

  bool _isBusy = false;
  bool _disposed = false;
  String _decisionFilter = 'all';
  String _statusMessage = '';
  String _errorMessage = '';
  Map<String, Object?>? _lastExecutionOutput;

  List<AgentSandboxAuditEntry> get audits =>
      List<AgentSandboxAuditEntry>.unmodifiable(_audits);
  List<AgentSandboxPolicy> get policies =>
      List<AgentSandboxPolicy>.unmodifiable(_policies);
  bool get isBusy => _isBusy;
  String get decisionFilter => _decisionFilter;
  String get statusMessage => _statusMessage;
  String get errorMessage => _errorMessage;
  Map<String, Object?>? get lastExecutionOutput => _lastExecutionOutput;

  List<AgentSandboxAuditEntry> get filteredAudits {
    if (_decisionFilter == 'all') {
      return audits;
    }
    return _audits
        .where(
          (AgentSandboxAuditEntry entry) => entry.decision == _decisionFilter,
        )
        .toList(growable: false);
  }

  int get blockedCount =>
      _audits.where((AgentSandboxAuditEntry e) => e.isBlocked).length;

  int get injectionCount => _audits
      .where(
        (AgentSandboxAuditEntry e) =>
            e.blockedCategory == SandboxBlockedCategory.promptInjection,
      )
      .length;

  int get anomalyCount => _audits
      .where(
        (AgentSandboxAuditEntry e) =>
            e.blockedCategory == SandboxBlockedCategory.excessiveRetries ||
            e.blockedCategory == SandboxBlockedCategory.invalidToolArgs,
      )
      .length;

  void setDecisionFilter(String filter) {
    _decisionFilter = filter;
    _notifySafely();
  }

  Future<void> loadSnapshot() async {
    _isBusy = true;
    _errorMessage = '';
    _notifySafely();
    try {
      final AgentSandboxAuditSnapshot snap =
          await _repository.fetchAuditSnapshot();
      _audits
        ..clear()
        ..addAll(snap.audits);
      _policies
        ..clear()
        ..addAll(snap.policies);
      _statusMessage = 'サンドボックス監査ログ ${_audits.length} 件を読み込みました。';
    } catch (error) {
      _errorMessage = '監査ログの読み込みに失敗しました: $error';
    } finally {
      _isBusy = false;
      _notifySafely();
    }
  }

  Future<AgentSandboxExecutionResult?> runPreflightAndExecute({
    required String toolName,
    required String actorRole,
    required List<String> requestedScopes,
    required Map<String, Object?> toolArgs,
    required int retryAttempt,
    String promptText = '',
  }) async {
    _isBusy = true;
    _errorMessage = '';
    _statusMessage = '';
    _notifySafely();
    try {
      final AgentSandboxExecutionResult res =
          await _repository.evaluateOrExecuteIsolated(
        toolName: toolName,
        actorRole: actorRole,
        requestedScopes: requestedScopes,
        toolArgs: toolArgs,
        retryAttempt: retryAttempt,
        executeIsolated: true,
        promptText: promptText,
      );
      if (res.auditEntry != null) {
        _audits.insert(0, res.auditEntry!);
      }
      _lastExecutionOutput = res.executionOutput;
      if (res.allowed) {
        _statusMessage = '隔離サンドボックス実行を許可しました ($toolName)。';
      } else {
        _errorMessage =
            'サンドボックス事前監視により遮断 [${res.blockedCategory.labelJa}]: ${res.blockedReason}';
      }
      return res;
    } catch (error) {
      _errorMessage = 'サンドボックス検証の実行に失敗しました: $error';
      return null;
    } finally {
      _isBusy = false;
      _notifySafely();
    }
  }

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    super.dispose();
  }
}
