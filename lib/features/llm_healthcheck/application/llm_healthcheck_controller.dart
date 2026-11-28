import 'package:flutter/foundation.dart';

import '../domain/llm_healthcheck_models.dart';

class LlmHealthcheckState {
  const LlmHealthcheckState({
    this.isLoading = false,
    this.isSaving = false,
    this.snapshot = LlmHealthDashboardSnapshot.empty,
    this.draftMethod = 'GET',
    this.errorMessage,
    this.noticeMessage,
  });

  final bool isLoading;
  final bool isSaving;
  final LlmHealthDashboardSnapshot snapshot;
  final String draftMethod;
  final String? errorMessage;
  final String? noticeMessage;

  LlmHealthcheckState copyWith({
    final bool? isLoading,
    final bool? isSaving,
    final LlmHealthDashboardSnapshot? snapshot,
    final String? draftMethod,
    final String? errorMessage,
    final bool clearError = false,
    final String? noticeMessage,
    final bool clearNotice = false,
  }) {
    return LlmHealthcheckState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      snapshot: snapshot ?? this.snapshot,
      draftMethod: draftMethod ?? this.draftMethod,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      noticeMessage: clearNotice ? null : (noticeMessage ?? this.noticeMessage),
    );
  }
}

class LlmHealthcheckController extends ChangeNotifier {
  LlmHealthcheckController({
    required final LlmHealthcheckRepository repository,
  }) : _repository = repository;

  final LlmHealthcheckRepository _repository;
  LlmHealthcheckState _state = const LlmHealthcheckState();
  bool _disposed = false;

  LlmHealthcheckState get state => _state;

  void _emit(final LlmHealthcheckState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  Future<void> loadDashboard() async {
    _emit(
      _state.copyWith(
        isLoading: true,
        clearError: true,
        clearNotice: true,
      ),
    );
    try {
      final summary = await _repository.fetchSummary();
      if (_disposed) return;
      _emit(_state.copyWith(isLoading: false, snapshot: summary));
    } on LlmHealthAuthException catch (err) {
      if (_disposed) return;
      _emit(_state.copyWith(isLoading: false, errorMessage: err.message));
    } catch (_) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isLoading: false,
          errorMessage: 'ヘルスチェック情報の取得に失敗しました。通信状況を確認してください。',
        ),
      );
    }
  }

  Future<void> seedDefaults() async {
    _emit(
      _state.copyWith(
        isSaving: true,
        clearError: true,
        clearNotice: true,
      ),
    );
    try {
      await _repository.seedDefaults();
      if (_disposed) return;
      final refreshed = await _repository.fetchSummary();
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSaving: false,
          snapshot: refreshed,
          noticeMessage: 'サンプル監視対象エンドポイントを登録しました。',
        ),
      );
    } on LlmHealthAuthException catch (err) {
      if (_disposed) return;
      _emit(_state.copyWith(isSaving: false, errorMessage: err.message));
    } catch (_) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSaving: false,
          errorMessage: '初期エンドポイント登録に失敗しました。',
        ),
      );
    }
  }

  void setDraftMethod(final String method) {
    _emit(_state.copyWith(draftMethod: method));
  }

  Future<void> saveEndpoint({
    required final String providerName,
    required final String endpointUrl,
    required final int timeoutMs,
    required final String alertChannel,
  }) async {
    final trimmedName = providerName.trim();
    final trimmedUrl = endpointUrl.trim();
    if (trimmedName.isEmpty) {
      _emit(_state.copyWith(errorMessage: 'プロバイダー名を入力してください。'));
      return;
    }
    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty) {
      _emit(
        _state.copyWith(
          errorMessage: '監視エンドポイントは安全な https:// URL を入力してください。',
        ),
      );
      return;
    }
    if (timeoutMs < 500 || timeoutMs > 15000) {
      _emit(
        _state.copyWith(
          errorMessage: 'タイムアウト値は 500〜15000 ms の範囲で指定してください。',
        ),
      );
      return;
    }

    _emit(
      _state.copyWith(
        isSaving: true,
        clearError: true,
        clearNotice: true,
      ),
    );
    try {
      await _repository.upsertEndpoint(
        providerName: trimmedName,
        endpointUrl: trimmedUrl,
        method: _state.draftMethod,
        timeoutMs: timeoutMs,
        alertChannel:
            alertChannel.trim().isEmpty ? 'ops-alerts' : alertChannel.trim(),
      );
      if (_disposed) return;
      final refreshed = await _repository.fetchSummary();
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSaving: false,
          snapshot: refreshed,
          noticeMessage: '$trimmedName を監視対象として保存しました。',
        ),
      );
    } on LlmHealthAuthException catch (err) {
      if (_disposed) return;
      _emit(_state.copyWith(isSaving: false, errorMessage: err.message));
    } catch (err) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSaving: false,
          errorMessage: err.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> deleteEndpoint(final String id) async {
    _emit(
      _state.copyWith(
        isSaving: true,
        clearError: true,
        clearNotice: true,
      ),
    );
    try {
      await _repository.deleteEndpoint(id);
      if (_disposed) return;
      final refreshed = await _repository.fetchSummary();
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSaving: false,
          snapshot: refreshed,
          noticeMessage: '監視対象エンドポイントを削除しました。',
        ),
      );
    } catch (_) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSaving: false,
          errorMessage: 'エンドポイントの削除に失敗しました。',
        ),
      );
    }
  }

  Future<void> runProbe({final String? endpointId}) async {
    _emit(
      _state.copyWith(
        isSaving: true,
        clearError: true,
        clearNotice: true,
      ),
    );
    try {
      await _repository.runProbe(endpointId: endpointId);
      if (_disposed) return;
      final refreshed = await _repository.fetchSummary();
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSaving: false,
          snapshot: refreshed,
          noticeMessage: 'ヘルスチェックを実行し応答時間と稼働状況を更新しました。',
        ),
      );
    } on LlmHealthAuthException catch (err) {
      if (_disposed) return;
      _emit(_state.copyWith(isSaving: false, errorMessage: err.message));
    } catch (_) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSaving: false,
          errorMessage: '死活監視プローブの実行に失敗しました。',
        ),
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
