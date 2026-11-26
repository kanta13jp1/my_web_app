import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/external_diff_alert_models.dart';

@immutable
class ExternalDiffAlertState {
  const ExternalDiffAlertState({
    required this.alerts,
    required this.rules,
    required this.snapshots,
    required this.isLoading,
    required this.isSubmitting,
    required this.realtimeActive,
    this.errorMessage,
    this.statusNotice,
    this.lastOutcome,
  });

  factory ExternalDiffAlertState.initial() => const ExternalDiffAlertState(
        alerts: <ExternalDiffAlertEvent>[],
        rules: <ExternalDiffRule>[],
        snapshots: <ExternalSnapshotSummary>[],
        isLoading: false,
        isSubmitting: false,
        realtimeActive: false,
      );

  final List<ExternalDiffAlertEvent> alerts;
  final List<ExternalDiffRule> rules;
  final List<ExternalSnapshotSummary> snapshots;
  final bool isLoading;
  final bool isSubmitting;
  final bool realtimeActive;
  final String? errorMessage;
  final String? statusNotice;
  final SnapshotDetectOutcome? lastOutcome;

  int get unacknowledgedCount =>
      alerts.where((item) => !item.isAcknowledged).length;

  ExternalDiffAlertState copyWith({
    List<ExternalDiffAlertEvent>? alerts,
    List<ExternalDiffRule>? rules,
    List<ExternalSnapshotSummary>? snapshots,
    bool? isLoading,
    bool? isSubmitting,
    bool? realtimeActive,
    String? errorMessage,
    bool clearError = false,
    String? statusNotice,
    bool clearNotice = false,
    SnapshotDetectOutcome? lastOutcome,
  }) {
    return ExternalDiffAlertState(
      alerts: alerts ?? this.alerts,
      rules: rules ?? this.rules,
      snapshots: snapshots ?? this.snapshots,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      realtimeActive: realtimeActive ?? this.realtimeActive,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      statusNotice: clearNotice ? null : (statusNotice ?? this.statusNotice),
      lastOutcome: lastOutcome ?? this.lastOutcome,
    );
  }
}

class ExternalDiffAlertController extends ChangeNotifier {
  ExternalDiffAlertController({
    required ExternalDiffAlertRepository repository,
  }) : _repository = repository;

  final ExternalDiffAlertRepository _repository;
  ExternalDiffAlertState _state = ExternalDiffAlertState.initial();
  bool _disposed = false;

  ExternalDiffAlertState get state => _state;

  void _setState(ExternalDiffAlertState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  Future<void> loadDashboard() async {
    if (_disposed || _state.isLoading) {
      return;
    }
    final subscribed = _repository.subscribeToAlerts(() {
      if (!_disposed) {
        unawaited(loadDashboard());
      }
    });
    _setState(
      _state.copyWith(
        isLoading: true,
        clearError: true,
        realtimeActive: subscribed,
      ),
    );
    try {
      final dashboard = await _repository.fetchDashboard();
      if (_disposed) {
        return;
      }
      _setState(
        _state.copyWith(
          alerts: dashboard.alerts,
          rules: dashboard.rules,
          snapshots: dashboard.snapshots,
          isLoading: false,
        ),
      );
    } catch (error) {
      if (_disposed) {
        return;
      }
      _setState(
        _state.copyWith(
          isLoading: false,
          errorMessage: '差分監視アラートの取得に失敗しました: $error',
        ),
      );
    }
  }

  Future<bool> saveRule({
    required String ruleName,
    required String sourceKey,
    required String fieldPath,
    required DiffRuleOperator operatorType,
    required String thresholdValue,
    required DiffAlertSeverity severity,
    required bool notifyEmail,
    required String recipientEmail,
  }) async {
    if (_disposed || _state.isSubmitting) {
      return false;
    }
    if (ruleName.trim().isEmpty || sourceKey.trim().isEmpty) {
      _setState(
        _state.copyWith(errorMessage: 'ルール名とソースキーは必須です。'),
      );
      return false;
    }
    _setState(_state.copyWith(isSubmitting: true, clearError: true));
    try {
      final saved = await _repository.upsertRule(
        ruleName: ruleName,
        sourceKey: sourceKey,
        fieldPath: fieldPath,
        operatorType: operatorType,
        thresholdValue: thresholdValue,
        severity: severity,
        notifyEmail: notifyEmail,
        recipientEmail: recipientEmail,
      );
      if (_disposed) {
        return false;
      }
      final refreshed = await _repository.fetchDashboard();
      if (_disposed) {
        return false;
      }
      _setState(
        _state.copyWith(
          alerts: refreshed.alerts,
          rules: refreshed.rules,
          snapshots: refreshed.snapshots,
          isSubmitting: false,
          statusNotice: 'ルール「${saved.ruleName}」を保存しました。',
        ),
      );
      return true;
    } catch (error) {
      if (_disposed) {
        return false;
      }
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: 'ルールの保存に失敗しました: $error',
        ),
      );
      return false;
    }
  }

  Future<bool> runSnapshotDetectFromJson({
    required String sourceKey,
    required String rawPayloadJson,
    bool dryRun = false,
  }) async {
    if (_disposed || _state.isSubmitting) {
      return false;
    }
    if (sourceKey.trim().isEmpty) {
      _setState(_state.copyWith(errorMessage: 'ソースキーを入力してください。'));
      return false;
    }
    Map<String, Object?> parsedPayload;
    try {
      final Object? decoded = jsonDecode(rawPayloadJson);
      parsedPayload = normalizeJsonObject(decoded, 'payload');
    } catch (error) {
      _setState(
        _state.copyWith(errorMessage: 'JSON ペイロードの形式が不正です: $error'),
      );
      return false;
    }

    _setState(_state.copyWith(isSubmitting: true, clearError: true));
    try {
      final outcome = await _repository.runSnapshotDetect(
        sourceKey: sourceKey,
        payload: parsedPayload,
        dryRun: dryRun,
      );
      if (_disposed) {
        return false;
      }
      final refreshed = await _repository.fetchDashboard();
      if (_disposed) {
        return false;
      }
      _setState(
        _state.copyWith(
          alerts: refreshed.alerts,
          rules: refreshed.rules,
          snapshots: refreshed.snapshots,
          isSubmitting: false,
          lastOutcome: outcome,
          statusNotice: outcome.baselineInitialized
              ? '${outcome.sourceKey} の初回ベースラインを登録しました。'
              : '差分 ${outcome.diffCount} 件 / 発火アラート ${outcome.alertsTriggered} 件',
        ),
      );
      return true;
    } catch (error) {
      if (_disposed) {
        return false;
      }
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: '差分検知の実行に失敗しました: $error',
        ),
      );
      return false;
    }
  }

  Future<void> acknowledgeAlert(String alertId) async {
    if (_disposed || alertId.trim().isEmpty) {
      return;
    }
    try {
      await _repository.acknowledgeAlert(alertId);
      if (_disposed) {
        return;
      }
      final refreshed = await _repository.fetchDashboard();
      if (_disposed) {
        return;
      }
      _setState(
        _state.copyWith(
          alerts: refreshed.alerts,
          rules: refreshed.rules,
          snapshots: refreshed.snapshots,
          statusNotice: 'アラートを確認済みに更新しました。',
        ),
      );
    } catch (error) {
      if (_disposed) {
        return;
      }
      _setState(
        _state.copyWith(errorMessage: 'アラート確認更新に失敗しました: $error'),
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_repository.disposeSubscription());
    super.dispose();
  }
}
