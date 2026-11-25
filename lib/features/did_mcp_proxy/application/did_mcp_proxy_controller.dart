import 'package:flutter/foundation.dart';

import '../data/supabase_did_mcp_proxy_repository.dart';
import '../domain/did_mcp_proxy_models.dart';

/// D-ID MCP プロキシ画面のオーケストレーション制御コントローラ (#2662).
class DidMcpProxyController extends ChangeNotifier {
  DidMcpProxyController({
    final DidMcpProxyRepository? repository,
    final DidMcpProxyState initialState = const DidMcpProxyState(),
  })  : _repository = repository ?? SupabaseDidMcpProxyRepository(),
        _state = initialState;

  final DidMcpProxyRepository _repository;
  DidMcpProxyState _state;
  bool _isDisposed = false;

  DidMcpProxyState get state => _state;

  void _notifySafely() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void selectTool(final DidMcpTool tool) {
    if (_isDisposed) {
      return;
    }
    _state = _state.copyWith(selectedTool: tool, clearError: true);
    _notifySafely();
  }

  void setDryRunOnly(final bool value) {
    if (_isDisposed) {
      return;
    }
    _state = _state.copyWith(dryRunOnly: value, clearError: true);
    _notifySafely();
  }

  Future<void> loadDashboard() async {
    if (_isDisposed) {
      return;
    }
    _state = _state.copyWith(isLoading: true, clearError: true);
    _notifySafely();

    try {
      final DidMcpDashboardSnapshot snapshot =
          await _repository.fetchDashboard();
      if (_isDisposed) {
        return;
      }
      _state = _state.copyWith(
        isLoading: false,
        events: snapshot.events,
        alerts: snapshot.alerts,
      );
    } catch (error) {
      if (_isDisposed) {
        return;
      }
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: '監査ログの読み込みに失敗しました: $error',
      );
    } finally {
      if (!_isDisposed && _state.isLoading) {
        _state = _state.copyWith(isLoading: false);
      }
      _notifySafely();
    }
  }

  Future<bool> runToolCall({
    required final String prompt,
    final String targetId = '',
  }) async {
    if (_isDisposed || _state.isSubmitting) {
      return false;
    }
    final DidMcpExecutionInput input = DidMcpExecutionInput(
      tool: _state.selectedTool,
      prompt: prompt,
      targetId: targetId,
      dryRun: _state.dryRunOnly,
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
      final String preview = await _repository.executeToolCall(input);
      if (_isDisposed) {
        return false;
      }
      final DidMcpDashboardSnapshot refreshed =
          await _repository.fetchDashboard();
      if (_isDisposed) {
        return false;
      }
      _state = _state.copyWith(
        isSubmitting: false,
        lastResponsePreview: preview,
        events: refreshed.events,
        alerts: refreshed.alerts,
      );
      return true;
    } catch (error) {
      if (_isDisposed) {
        return false;
      }
      _state = _state.copyWith(
        isSubmitting: false,
        errorMessage: 'D-ID MCP 呼出に失敗しました: $error',
      );
      return false;
    } finally {
      if (!_isDisposed && _state.isSubmitting) {
        _state = _state.copyWith(isSubmitting: false);
      }
      _notifySafely();
    }
  }

  Future<bool> acknowledgeAlert(final String alertId) async {
    if (_isDisposed) {
      return false;
    }
    try {
      final DidMcpAlert updated = await _repository.acknowledgeAlert(alertId);
      if (_isDisposed) {
        return false;
      }
      final List<DidMcpAlert> nextAlerts = _state.alerts
          .map(
            (final DidMcpAlert item) => item.id == updated.id ? updated : item,
          )
          .toList();
      _state = _state.copyWith(alerts: nextAlerts, clearError: true);
      return true;
    } catch (error) {
      if (_isDisposed) {
        return false;
      }
      _state = _state.copyWith(
        errorMessage: 'アラート確認の保存に失敗しました: $error',
      );
      return false;
    } finally {
      _notifySafely();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
