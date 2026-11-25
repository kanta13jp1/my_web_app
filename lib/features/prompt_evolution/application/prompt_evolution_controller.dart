import 'package:flutter/foundation.dart';

import '../domain/prompt_evolution_models.dart';

class PromptEvolutionController extends ChangeNotifier {
  PromptEvolutionController({
    required PromptEvolutionRepository repository,
    PromptSafetyGuard safetyGuard = const PromptSafetyGuard(),
  })  : _repository = repository,
        _safetyGuard = safetyGuard;

  final PromptEvolutionRepository _repository;
  final PromptSafetyGuard _safetyGuard;

  bool _disposed = false;
  bool _isLoading = false;
  bool _isRunning = false;
  String? _errorMessage;
  GpaBatchEvaluationReport? _batchReport;
  PromptEvolutionRunResult? _runResult;
  List<Map<String, Object?>> _recentEvaluations =
      const <Map<String, Object?>>[];

  bool get isLoading => _isLoading;
  bool get isRunning => _isRunning;
  String? get errorMessage => _errorMessage;
  GpaBatchEvaluationReport? get batchReport => _batchReport;
  PromptEvolutionRunResult? get runResult => _runResult;
  List<Map<String, Object?>> get recentEvaluations => _recentEvaluations;

  Future<void> loadRecentEvaluations() async {
    if (_disposed || _isLoading) {
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final loaded = await _repository.listRecentEvaluations();
      if (_disposed) {
        return;
      }
      _recentEvaluations = loaded;
    } catch (error) {
      if (_disposed) {
        return;
      }
      _errorMessage = 'GPA 評価履歴の取得に失敗しました: $error';
    } finally {
      if (!_disposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> scoreBatch({
    required double varianceThreshold,
    required List<Map<String, Object?>> traces,
  }) async {
    if (_disposed || _isRunning) {
      return;
    }
    _isRunning = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final report = await _repository.evaluateTraceBatch(
        varianceThreshold: varianceThreshold,
        traces: traces,
      );
      if (_disposed) {
        return;
      }
      _batchReport = report;
    } catch (error) {
      if (_disposed) {
        return;
      }
      _errorMessage = 'GPA バッチ評価に失敗しました: $error';
    } finally {
      if (!_disposed) {
        _isRunning = false;
        notifyListeners();
      }
    }
  }

  Future<bool> runEvolution({
    required double varianceThreshold,
    required List<Map<String, Object?>> traces,
    required PromptEvolutionDraft basePrompt,
    bool persistCandidate = true,
  }) async {
    if (_disposed || _isRunning) {
      return false;
    }
    final List<String> guardIssues = _safetyGuard.validateDraft(basePrompt);
    if (guardIssues.isNotEmpty) {
      _errorMessage = '安全ガード検証エラー: ${guardIssues.join(' ')}';
      notifyListeners();
      return false;
    }

    _isRunning = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.evolveFromTraces(
        varianceThreshold: varianceThreshold,
        traces: traces,
        basePrompt: basePrompt,
        persistCandidate: persistCandidate,
      );
      if (_disposed) {
        return false;
      }
      _runResult = result;
      _batchReport = result.batch;
      if (result.evolutionTriggered &&
          result.candidates.isNotEmpty &&
          result.candidates.every((c) => !c.safetyValid)) {
        _errorMessage = '生成された改善候補が安全性検証を通過しなかったため保存をブロックしました。';
        return false;
      }
      return true;
    } catch (error) {
      if (_disposed) {
        return false;
      }
      _errorMessage = '進化的プロンプト最適化の実行に失敗しました: $error';
      return false;
    } finally {
      if (!_disposed) {
        _isRunning = false;
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
