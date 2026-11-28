import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/external_ai_webhook_models.dart';

/// 外部 AI Webhook 連携画面状態 (#2663).
@immutable
class ExternalAiWebhookState {
  const ExternalAiWebhookState({
    required this.events,
    required this.keys,
    required this.isLoading,
    required this.isSubmitting,
    required this.realtimeActive,
    this.selectedSourceFilter,
    this.latestCreatedPlaintextKey,
    this.errorMessage,
    this.statusNotice,
  });

  factory ExternalAiWebhookState.initial() => const ExternalAiWebhookState(
        events: <ExternalAiWebhookEvent>[],
        keys: <ExternalAiWebhookKey>[],
        isLoading: false,
        isSubmitting: false,
        realtimeActive: false,
      );

  final List<ExternalAiWebhookEvent> events;
  final List<ExternalAiWebhookKey> keys;
  final bool isLoading;
  final bool isSubmitting;
  final bool realtimeActive;
  final ExternalWebhookSourceTool? selectedSourceFilter;
  final String? latestCreatedPlaintextKey;
  final String? errorMessage;
  final String? statusNotice;

  int get activeKeyCount => keys.where((final item) => item.isActive).length;

  List<ExternalAiWebhookEvent> get filteredEvents {
    final filter = selectedSourceFilter;
    if (filter == null) {
      return events;
    }
    return events
        .where((final item) => item.sourceTool == filter)
        .toList(growable: false);
  }

  ExternalAiWebhookState copyWith({
    final List<ExternalAiWebhookEvent>? events,
    final List<ExternalAiWebhookKey>? keys,
    final bool? isLoading,
    final bool? isSubmitting,
    final bool? realtimeActive,
    final ExternalWebhookSourceTool? selectedSourceFilter,
    final bool clearSourceFilter = false,
    final String? latestCreatedPlaintextKey,
    final bool clearPlaintextKey = false,
    final String? errorMessage,
    final bool clearError = false,
    final String? statusNotice,
    final bool clearNotice = false,
  }) {
    return ExternalAiWebhookState(
      events: events ?? this.events,
      keys: keys ?? this.keys,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      realtimeActive: realtimeActive ?? this.realtimeActive,
      selectedSourceFilter: clearSourceFilter
          ? null
          : (selectedSourceFilter ?? this.selectedSourceFilter),
      latestCreatedPlaintextKey: clearPlaintextKey
          ? null
          : (latestCreatedPlaintextKey ?? this.latestCreatedPlaintextKey),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      statusNotice: clearNotice ? null : (statusNotice ?? this.statusNotice),
    );
  }
}

/// 外部 AI Webhook 受信監視・Realtime 更新・API キー管理 Controller (#2663).
class ExternalAiWebhookController extends ChangeNotifier {
  ExternalAiWebhookController({
    required final ExternalAiWebhookRepository repository,
  })  : _repository = repository,
        _state = ExternalAiWebhookState.initial();

  final ExternalAiWebhookRepository _repository;
  ExternalAiWebhookState _state;
  bool _isDisposed = false;

  ExternalAiWebhookState get state => _state;
  bool get isDisposed => _isDisposed;

  void _setState(final ExternalAiWebhookState next) {
    if (_isDisposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  void selectSourceFilter(final ExternalWebhookSourceTool? source) {
    if (_isDisposed) {
      return;
    }
    _setState(
      _state.copyWith(
        selectedSourceFilter: source,
        clearSourceFilter: source == null,
        clearError: true,
      ),
    );
  }

  void dismissCreatedPlaintextKey() {
    if (_isDisposed) {
      return;
    }
    _setState(_state.copyWith(clearPlaintextKey: true, clearError: true));
  }

  Future<void> loadDashboard() async {
    if (_isDisposed) {
      return;
    }
    _setState(_state.copyWith(isLoading: true, clearError: true));
    try {
      final events = await _repository.fetchRecentEvents();
      if (_isDisposed) {
        return;
      }
      final keys = await _repository.fetchWebhookKeys();
      if (_isDisposed) {
        return;
      }
      final subscribed = _repository.subscribeToEvents(() {
        if (!_isDisposed) {
          unawaited(refreshEventsFromRealtime());
        }
      });
      _setState(
        _state.copyWith(
          events: events,
          keys: keys,
          isLoading: false,
          realtimeActive: subscribed,
          clearError: true,
        ),
      );
    } catch (error) {
      if (_isDisposed) {
        return;
      }
      _setState(
        _state.copyWith(
          isLoading: false,
          errorMessage: 'Webhook ダッシュボードの読み込みに失敗しました: $error',
        ),
      );
    }
  }

  Future<void> refreshEventsFromRealtime() async {
    if (_isDisposed) {
      return;
    }
    try {
      final events = await _repository.fetchRecentEvents();
      if (_isDisposed) {
        return;
      }
      _setState(
        _state.copyWith(
          events: events,
          clearError: true,
        ),
      );
    } catch (error) {
      if (_isDisposed) {
        return;
      }
      _setState(
        _state.copyWith(
          errorMessage: 'Realtime イベントの再取得に失敗しました: $error',
        ),
      );
    }
  }

  Future<void> createWebhookKey({required final String label}) async {
    if (_isDisposed || _state.isSubmitting) {
      return;
    }
    final cleanLabel = label.trim();
    if (cleanLabel.isEmpty) {
      _setState(
        _state.copyWith(
          errorMessage: 'APIキーの表示名を入力してください。',
          clearNotice: true,
        ),
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
      final material = GeneratedWebhookKeyMaterial.generate();
      final created = await _repository.createWebhookKey(
        label: cleanLabel,
        keyPrefix: material.keyPrefix,
        keyHash: material.keyHash,
      );
      if (_isDisposed) {
        return;
      }
      final nextKeys = List<ExternalAiWebhookKey>.unmodifiable(
        <ExternalAiWebhookKey>[created, ..._state.keys],
      );
      _setState(
        _state.copyWith(
          keys: nextKeys,
          isSubmitting: false,
          latestCreatedPlaintextKey: material.plaintextKey,
          clearError: true,
          statusNotice: 'APIキー「${created.label}」を発行しました。平文キーはこの一度のみ表示されます。',
        ),
      );
    } catch (error) {
      if (_isDisposed) {
        return;
      }
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: 'APIキーの発行に失敗しました: $error',
        ),
      );
    }
  }

  Future<void> revokeWebhookKey(final String keyId) async {
    if (_isDisposed || _state.isSubmitting) {
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
      await _repository.revokeWebhookKey(keyId);
      if (_isDisposed) {
        return;
      }
      final updatedKeys = _state.keys
          .map(
            (final item) =>
                item.id == keyId ? item.copyWith(isActive: false) : item,
          )
          .toList(growable: false);
      _setState(
        _state.copyWith(
          keys: updatedKeys,
          isSubmitting: false,
          clearError: true,
          statusNotice: 'APIキーを無効化しました。',
        ),
      );
    } catch (error) {
      if (_isDisposed) {
        return;
      }
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: 'APIキーの無効化に失敗しました: $error',
        ),
      );
    }
  }

  Future<void> sendWebhookTest({
    required final ExternalWebhookSourceTool sourceTool,
    required final String eventType,
    required final String sampleNote,
    required final bool dryRun,
  }) async {
    if (_isDisposed || _state.isSubmitting) {
      return;
    }
    final cleanEventType = eventType.trim();
    if (cleanEventType.isEmpty) {
      _setState(
        _state.copyWith(
          errorMessage: 'イベント種別を入力してください。',
          clearNotice: true,
        ),
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
      final result = await _repository.invokeWebhookEndpoint(
        sourceTool: sourceTool,
        eventType: cleanEventType,
        payload: <String, Object?>{
          'source': sourceTool.wireValue,
          'note':
              sampleNote.trim().isEmpty ? 'automation-ping' : sampleNote.trim(),
        },
        dryRun: dryRun,
      );
      if (_isDisposed) {
        return;
      }
      List<ExternalAiWebhookEvent> nextEvents = _state.events;
      if (!dryRun) {
        nextEvents = await _repository.fetchRecentEvents();
        if (_isDisposed) {
          return;
        }
      }
      _setState(
        _state.copyWith(
          events: nextEvents,
          isSubmitting: false,
          clearError: true,
          statusNotice: result.dryRun
              ? 'ドライラン検証完了 (${sourceTool.displayLabel} / ${result.authMethod.displayLabel})。DB 書き込みなし。'
              : 'Webhook 送信完了 (ID: ${result.eventId ?? '-'})。Realtime フィードを更新しました。',
        ),
      );
    } catch (error) {
      if (_isDisposed) {
        return;
      }
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: 'Webhook テスト送信に失敗しました: $error',
        ),
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_repository.disposeSubscription());
    super.dispose();
  }
}
