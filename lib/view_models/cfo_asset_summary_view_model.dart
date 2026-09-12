import 'package:flutter/foundation.dart';

import '../models/department_finance_summary.dart';
import '../services/department_finance_summary_repository.dart';

class CfoAssetSummaryViewModel extends ChangeNotifier {
  CfoAssetSummaryViewModel({
    required DepartmentFinanceSummaryRepository repository,
  }) : _repository = repository;

  final DepartmentFinanceSummaryRepository _repository;
  DepartmentFinanceSummary? _summary;
  bool _isLoading = false;
  bool _disposed = false;
  int _requestVersion = 0;
  String? _errorMessage;

  DepartmentFinanceSummary? get summary => _summary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    final requestVersion = ++_requestVersion;
    _isLoading = true;
    _errorMessage = null;
    _notify();
    try {
      final summary = await _repository.loadCurrentMonth();
      if (_disposed || requestVersion != _requestVersion) return;
      _summary = summary;
    } catch (_) {
      if (_disposed || requestVersion != _requestVersion) return;
      _errorMessage = '資産サマリを読み込めませんでした。もう一度お試しください。';
    } finally {
      if (!_disposed && requestVersion == _requestVersion) {
        _isLoading = false;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
