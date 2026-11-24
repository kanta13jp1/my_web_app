import 'package:flutter/foundation.dart';

import '../domain/agent_pause_checkpoint_models.dart';

/// エージェント一時停止チェックポイントと無欠損再開フローを管理するコントローラー。
class AgentPauseCheckpointController extends ChangeNotifier {
  AgentPauseCheckpointController({
    required AgentPauseCheckpointRepository repository,
    List<AgentPauseCheckpointRecord>? initialRecords,
    bool initialIsAdmin = false,
  })  : _repository = repository,
        _records = List<AgentPauseCheckpointRecord>.from(
          initialRecords ?? const <AgentPauseCheckpointRecord>[],
        ),
        _canResumeAsAdmin = initialIsAdmin;

  final AgentPauseCheckpointRepository _repository;
  final List<AgentPauseCheckpointRecord> _records;

  bool _isBusy = false;
  bool _disposed = false;
  bool _canResumeAsAdmin;
  String _statusMessage = '';
  String _errorMessage = '';

  List<AgentPauseCheckpointRecord> get records =>
      List<AgentPauseCheckpointRecord>.unmodifiable(_records);

  bool get isBusy => _isBusy;
  bool get canResumeAsAdmin => _canResumeAsAdmin;
  String get statusMessage => _statusMessage;
  String get errorMessage => _errorMessage;

  int get pausedCount => _records
      .where(
        (AgentPauseCheckpointRecord r) =>
            r.pauseStatus == AgentPauseStatus.pausedLossless,
      )
      .length;

  int get warning90Count => _records
      .where(
        (AgentPauseCheckpointRecord r) =>
            r.pauseStatus == AgentPauseStatus.warning90 || r.isWarning90OrAbove,
      )
      .length;

  int get silentAlertedCount => _records
      .where((AgentPauseCheckpointRecord r) => r.silentPauseAlerted)
      .length;

  Future<void> loadCheckpoints() async {
    _isBusy = true;
    _errorMessage = '';
    _notifySafely();
    try {
      final bool isAdmin = await _repository.fetchIsAdmin();
      final List<AgentPauseCheckpointRecord> loaded =
          await _repository.fetchCheckpoints();
      _canResumeAsAdmin = isAdmin;
      _records
        ..clear()
        ..addAll(loaded);
      _statusMessage =
          'チェックポイントを ${_records.length} 件読み込みました（無欠損停止 $pausedCount 件）。';
    } catch (error) {
      _errorMessage = 'チェックポイント読み込みに失敗しました: $error';
      _statusMessage = '';
    } finally {
      _isBusy = false;
      _notifySafely();
    }
  }

  Future<bool> captureCheckpoint({
    required String runKey,
    required String agentName,
    required double usageRatioPct,
    required String pendingStep,
  }) async {
    final String cleanRunKey = runKey.trim();
    final String cleanAgent = agentName.trim();
    final String cleanStep = pendingStep.trim();
    if (cleanRunKey.isEmpty || cleanAgent.isEmpty || cleanStep.isEmpty) {
      _errorMessage = 'Runキー・エージェント名・未完了ステップを入力してください。';
      _notifySafely();
      return false;
    }

    _isBusy = true;
    _errorMessage = '';
    _notifySafely();
    try {
      final AgentPauseCheckpointRecord saved =
          await _repository.saveLosslessPauseCheckpoint(
        runKey: cleanRunKey,
        agentName: cleanAgent,
        usageRatioPct: usageRatioPct,
        pendingStep: cleanStep,
      );
      _records
        ..removeWhere((AgentPauseCheckpointRecord r) => r.id == saved.id)
        ..insert(0, saved);
      _statusMessage = saved.isLosslessPaused
          ? '${saved.runKey} の状態を無欠損保存し、安全に一時停止しました。'
          : '${saved.runKey} のチェックポイントを保存しました (${saved.pauseStatus.labelJa})。';
      return true;
    } catch (error) {
      _errorMessage = 'チェックポイント保存に失敗しました: $error';
      return false;
    } finally {
      _isBusy = false;
      _notifySafely();
    }
  }

  Future<bool> resumeCheckpoint(
    AgentPauseCheckpointRecord record, {
    double replenishedUsagePct = 15.0,
  }) async {
    if (!_canResumeAsAdmin) {
      _errorMessage = '無欠損再開には管理者権限 (is_admin) が必要です。';
      _notifySafely();
      return false;
    }
    _isBusy = true;
    _errorMessage = '';
    _notifySafely();
    try {
      final AgentPauseCheckpointRecord updated =
          await _repository.resumeCheckpoint(
        record: record,
        replenishedUsagePct: replenishedUsagePct,
      );
      final int idx = _records.indexWhere(
        (AgentPauseCheckpointRecord r) => r.id == record.id,
      );
      if (idx >= 0) {
        _records[idx] = updated;
      } else {
        _records.insert(0, updated);
      }
      _statusMessage =
          '${updated.runKey} を無欠損スナップショットから安全に再開しました (seq ${updated.checkpointSeq})。';
      return true;
    } catch (error) {
      _errorMessage = '再開処理に失敗しました: $error';
      return false;
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
