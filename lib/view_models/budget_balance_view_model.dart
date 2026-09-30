import 'package:flutter/foundation.dart';
import '../services/budget_balance_calculator.dart';

class BudgetBalanceViewModel extends ChangeNotifier {
  BudgetBalanceViewModel(
      {BudgetBalanceCalculator calculator = const BudgetBalanceCalculator()})
      : _calculator = calculator;

  final BudgetBalanceCalculator _calculator;
  final _inputs = <BudgetBalanceField, String>{};
  Map<BudgetBalanceField, String> _errors = {};
  BudgetBalanceResult? result;
  bool needsRecalculation = false;

  String? errorFor(BudgetBalanceField field) => _errors[field];

  void update(BudgetBalanceField field, String value) {
    _inputs[field] = value;
    needsRecalculation = result != null || needsRecalculation;
    result = null;
    _errors = {..._errors}..remove(field);
    notifyListeners();
  }

  void calculate() {
    _errors = {
      for (final field in BudgetBalanceField.values)
        if (_calculator.validate(_inputs[field] ?? '') case final String error)
          field: error,
    };
    result = _calculator.calculate(_inputs);
    needsRecalculation = false;
    notifyListeners();
  }

  void reset() {
    _inputs.clear();
    _errors = {};
    result = null;
    needsRecalculation = false;
    notifyListeners();
  }
}
