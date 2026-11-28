import 'package:flutter/foundation.dart';

import '../domain/architectural_safety_checkpoint_models.dart';

/// Architectural Safety Checkpoints の状態管理と承認ゲート制御 (#2712)。
class ArchitecturalSafetyCheckpointController extends ChangeNotifier {
  ArchitecturalSafetyCheckpointController({
    required ArchitecturalSafetyCheckpointRepository repository,
    List<SafetyCheckpointRecord>? initialRecords,
  })  : _repository = repository,
        _records = List<SafetyCheckpointRecord>.from(
          initialRecords ?? const <SafetyCheckpointRecord>[],
        );

  final ArchitecturalSafetyCheckpointRepository _repository;
  final List<SafetyCheckpointRecord> _records;

  bool _isBusy = false;
  bool _canApproveAsAdmin = false;
  bool _disposed = false;
  String _errorMessage = '';
  String _statusMessage = '';
  SafetyCheckpointEvaluationResult? _lastEvaluation;

  List<SafetyCheckpointRecord> get records =>
      List<SafetyCheckpointRecord>.unmodifiable(_records);

  bool get isBusy => _isBusy;
  bool get canApproveAsAdmin => _canApproveAsAdmin;
  String get errorMessage => _errorMessage;
  String get statusMessage => _statusMessage;
  SafetyCheckpointEvaluationResult? get lastEvaluation => _lastEvaluation;

  int get awaitingApprovalCount =>
      _records.where((SafetyCheckpointRecord r) => r.isAwaitingApproval).length;

  int get resumedCount =>
      _records.where((SafetyCheckpointRecord r) => r.isResumed).length;

  int get rejectedCount =>
      _records.where((SafetyCheckpointRecord r) => r.isRejected).length;

  Future<void> loadCheckpoints() async {
    _isBusy = true;
    _errorMessage = '';
    _notifySafely();
    try {
      final SafetyCheckpointFeed feed =
          await _repository.fetchSafetyCheckpoints();
      _canApproveAsAdmin = feed.isAdmin;
      _records
        ..clear()
        ..addAll(feed.checkpoints);
      _statusMessage = _canApproveAsAdmin
          ? '安全チェックポイント ${_records.length} 件を取得しました（管理者承認可能）。'
          : '安全チェックポイント ${_records.length} 件を取得しました（閲覧専用）。';
    } catch (error) {
      _errorMessage = '安全チェックポイントの取得に失敗しました: $error';
    } finally {
      _isBusy = false;
      _notifySafely();
    }
  }

  Future<SafetyCheckpointEvaluationResult?> evaluateToolCall({
    required String toolName,
    required List<String> requestedScopes,
    String actorRole = 'admin',
    String runKey = 'mcp-safety-check',
    String agentName = 'autonomous-agent',
    String pendingStep = '',
    int? githubIssueNumber,
    String? checkpointId,
  }) async {
    final String cleanTool = toolName.trim();
    if (cleanTool.isEmpty) {
      _errorMessage = 'MCP ツール名を入力してください。';
      _notifySafely();
      return null;
    }
    _isBusy = true;
    _errorMessage = '';
    _notifySafely();
    try {
      final SafetyCheckpointEvaluationResult result =
          await _repository.evaluateToolCall(
        toolName: cleanTool,
        requestedScopes: requestedScopes,
        actorRole: actorRole,
        runKey: runKey.trim().isEmpty ? 'mcp-safety-check' : runKey.trim(),
        agentName:
            agentName.trim().isEmpty ? 'autonomous-agent' : agentName.trim(),
        pendingStep: pendingStep,
        githubIssueNumber: githubIssueNumber,
        checkpointId: checkpointId,
      );
      _lastEvaluation = result;
      final SafetyCheckpointRecord? chk = result.checkpoint;
      if (chk != null) {
        _records
          ..removeWhere((SafetyCheckpointRecord item) => item.id == chk.id)
          ..insert(0, chk);
      }
      if (result.executionAllowed) {
        _statusMessage = '$cleanTool の実行が許可されました (${result.decision})。';
      } else if (result.pauseRequired) {
        _statusMessage = '$cleanTool はシステム影響操作のため実行前に一時停止しました（管理者承認待ち）。';
      } else {
        _statusMessage = '$cleanTool は権限不足によりブロックされました。';
      }
      return result;
    } catch (error) {
      _errorMessage = '安全チェックポイント評価に失敗しました: $error';
      return null;
    } finally {
      _isBusy = false;
      _notifySafely();
    }
  }

  Future<bool> approveCheckpoint(
    SafetyCheckpointRecord record, {
    required SafetyApprovalChannel channel,
    int? githubIssueNumber,
    String? approvalNote,
  }) async {
    if (!_canApproveAsAdmin) {
      _errorMessage = '安全チェックポイントの承認・再開には管理者権限 (is_admin) が必要です。';
      _notifySafely();
      return false;
    }
    _isBusy = true;
    _errorMessage = '';
    _notifySafely();
    try {
      final SafetyCheckpointRecord updated =
          await _repository.approveCheckpoint(
        record: record,
        channel: channel,
        githubIssueNumber: githubIssueNumber ?? record.githubIssueNumber,
        approvalNote: approvalNote,
      );
      _replaceRecord(updated);
      _statusMessage =
          '${updated.toolName} を ${channel.labelJa} で承認し、後続処理を再開可能にしました。';
      return true;
    } catch (error) {
      _errorMessage = '承認処理に失敗しました: $error';
      return false;
    } finally {
      _isBusy = false;
      _notifySafely();
    }
  }

  Future<bool> rejectCheckpoint(
    SafetyCheckpointRecord record, {
    String reason = '',
  }) async {
    _isBusy = true;
    _errorMessage = '';
    _notifySafely();
    try {
      final SafetyCheckpointRecord updated = await _repository.rejectCheckpoint(
        record: record,
        reason: reason,
      );
      _replaceRecord(updated);
      _statusMessage = '${updated.toolName} の実行を拒否し、停止状態を確定しました。';
      return true;
    } catch (error) {
      _errorMessage = '拒否処理に失敗しました: $error';
      return false;
    } finally {
      _isBusy = false;
      _notifySafely();
    }
  }

  void _replaceRecord(SafetyCheckpointRecord updated) {
    final int idx = _records.indexWhere(
      (SafetyCheckpointRecord item) => item.id == updated.id,
    );
    if (idx >= 0) {
      _records[idx] = updated;
    } else {
      _records.insert(0, updated);
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
