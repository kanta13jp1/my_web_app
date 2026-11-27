import 'package:flutter/foundation.dart';

import '../domain/ai_token_cache_monitor_models.dart';

class AiTokenCacheMonitorController extends ChangeNotifier {
  AiTokenCacheMonitorController({
    required AiTokenCacheMonitorRepository repository,
    LocalPrefixStabilityAnalyzer analyzer =
        const LocalPrefixStabilityAnalyzer(),
  })  : _repository = repository,
        _analyzer = analyzer;

  final AiTokenCacheMonitorRepository _repository;
  final LocalPrefixStabilityAnalyzer _analyzer;

  bool _disposed = false;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  TokenCacheSummarySnapshot? _summary;
  PrefixStabilityDiagnostic? _diagnostics;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  TokenCacheSummarySnapshot? get summary => _summary;
  PrefixStabilityDiagnostic? get diagnostics => _diagnostics;

  PrefixStabilityDiagnostic previewDiagnostics({
    required String systemPrompt,
    required int toolCount,
    required bool useToolSearch,
    required int breakpointCount,
  }) {
    final result = _analyzer.analyze(
      systemPrompt: systemPrompt,
      toolCount: toolCount,
      useToolSearch: useToolSearch,
      breakpointCount: breakpointCount,
    );
    if (!_disposed) {
      _diagnostics = result;
      notifyListeners();
    }
    return result;
  }

  Future<void> loadSummary() async {
    if (_disposed || _isLoading) {
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final loaded = await _repository.fetchSummary();
      if (_disposed) {
        return;
      }
      _summary = loaded;
    } catch (error) {
      if (_disposed) {
        return;
      }
      _errorMessage = 'トークン・キャッシュ集計の取得に失敗しました: $error';
    } finally {
      if (!_disposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> recordAndDiagnose({
    required String toolName,
    required String modelId,
    required int inputUnits,
    required int outputUnits,
    required int cachedReadUnits,
    required String systemPrompt,
    required int toolCount,
    required bool useToolSearch,
    required int breakpointCount,
  }) async {
    if (_disposed || _isSubmitting) {
      return false;
    }
    if (toolName.trim().isEmpty) {
      _errorMessage = 'ツール名を入力してください。';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final diag = await _repository.recordToolUsage(
        toolName: toolName.trim(),
        modelId: modelId.trim(),
        inputUnits: inputUnits,
        outputUnits: outputUnits,
        cachedReadUnits: cachedReadUnits,
        systemPrompt: systemPrompt,
        toolCount: toolCount,
        useToolSearch: useToolSearch,
        breakpointCount: breakpointCount,
      );
      if (_disposed) {
        return false;
      }
      _diagnostics = diag;
      final refreshed = await _repository.fetchSummary();
      if (_disposed) {
        return false;
      }
      _summary = refreshed;
      return true;
    } catch (error) {
      if (_disposed) {
        return false;
      }
      _errorMessage = 'ツール消費ログの記録に失敗しました: $error';
      return false;
    } finally {
      if (!_disposed) {
        _isSubmitting = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
