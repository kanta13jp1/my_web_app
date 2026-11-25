import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/income_insurance_models.dart';

typedef IncomeInsuranceClipboardWriter = Future<void> Function(String csvText);

@immutable
class IncomeInsuranceSimState {
  const IncomeInsuranceSimState({
    required this.config,
    required this.result,
    required this.csvPreview,
    this.errorMessage,
    this.statusNotice,
  });

  final IncomeInsuranceSimulationConfig config;
  final IncomeInsuranceSimulationResult result;
  final String csvPreview;
  final String? errorMessage;
  final String? statusNotice;

  IncomeInsuranceSimState copyWith({
    final IncomeInsuranceSimulationConfig? config,
    final IncomeInsuranceSimulationResult? result,
    final String? csvPreview,
    final String? errorMessage,
    final bool clearError = false,
    final String? statusNotice,
    final bool clearStatusNotice = false,
  }) {
    return IncomeInsuranceSimState(
      config: config ?? this.config,
      result: result ?? this.result,
      csvPreview: csvPreview ?? this.csvPreview,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      statusNotice:
          clearStatusNotice ? null : (statusNotice ?? this.statusNotice),
    );
  }
}

/// Controls simulation parameters, moving-average math & CSV export (#2757).
class IncomeInsuranceController extends ChangeNotifier {
  IncomeInsuranceController({
    final IncomeInsuranceSimulationConfig initialConfig =
        const IncomeInsuranceSimulationConfig(),
    final IncomeInsuranceClipboardWriter? clipboardWriter,
  })  : _clipboardWriter = clipboardWriter,
        _state = _buildInitialState(initialConfig);

  static IncomeInsuranceSimState _buildInitialState(
    final IncomeInsuranceSimulationConfig initialConfig,
  ) {
    final result = IncomeInsuranceEngine.simulate(initialConfig);
    return IncomeInsuranceSimState(
      config: initialConfig,
      result: result,
      csvPreview: IncomeInsuranceCsvExporter.toCsv(result),
    );
  }

  final IncomeInsuranceClipboardWriter? _clipboardWriter;
  IncomeInsuranceSimState _state;
  bool _disposed = false;

  IncomeInsuranceSimState get state => _state;

  void _emit(final IncomeInsuranceSimState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  void applyConfig(final IncomeInsuranceSimulationConfig nextConfig) {
    final validationError = IncomeInsuranceEngine.validateConfig(nextConfig);
    if (validationError != null) {
      _emit(
        _state.copyWith(
          errorMessage: validationError,
          clearStatusNotice: true,
        ),
      );
      return;
    }

    final result = IncomeInsuranceEngine.simulate(nextConfig);
    _emit(
      _state.copyWith(
        config: nextConfig,
        result: result,
        csvPreview: IncomeInsuranceCsvExporter.toCsv(result),
        clearError: true,
        statusNotice: 'シミュレーション結果を更新しました（${result.points.length}年分）。',
      ),
    );
  }

  void runFromRawInputs({
    required final String scenarioLabel,
    required final String baseRevenueRaw,
    required final String annualDeclineRaw,
    required final String yearsRaw,
    required final String windowRaw,
    required final String coverageRateRaw,
    required final String payoutRateRaw,
    required final String fixedBenchmarkRaw,
    required final String directRateRaw,
  }) {
    final baseRevenue = double.tryParse(baseRevenueRaw.trim());
    final annualDecline = double.tryParse(annualDeclineRaw.trim());
    final years = int.tryParse(yearsRaw.trim());
    final window = int.tryParse(windowRaw.trim());
    final coveragePercent = double.tryParse(coverageRateRaw.trim());
    final payoutPercent = double.tryParse(payoutRateRaw.trim());
    final fixedBenchmark = double.tryParse(fixedBenchmarkRaw.trim());
    final directPercent = double.tryParse(directRateRaw.trim());

    if (baseRevenue == null ||
        annualDecline == null ||
        years == null ||
        window == null ||
        coveragePercent == null ||
        payoutPercent == null ||
        fixedBenchmark == null ||
        directPercent == null) {
      _emit(
        _state.copyWith(
          errorMessage: 'すべての数値項目を正しい半角数値で入力してください。',
          clearStatusNotice: true,
        ),
      );
      return;
    }

    final label =
        scenarioLabel.trim().isEmpty ? '継続価格下落シミュレーション' : scenarioLabel.trim();

    applyConfig(
      IncomeInsuranceSimulationConfig(
        scenarioLabel: label,
        baseRevenue: baseRevenue,
        annualDeclinePercent: annualDecline,
        years: years,
        movingAverageWindow: window,
        coverageLimitRate: coveragePercent / 100.0,
        payoutRate: payoutPercent / 100.0,
        fixedBenchmarkRevenue: fixedBenchmark,
        directPaymentSubsidyRate: directPercent / 100.0,
      ),
    );
  }

  Future<String> exportCsv() async {
    final csv = IncomeInsuranceCsvExporter.toCsv(_state.result);
    var copied = false;
    try {
      final writer = _clipboardWriter;
      if (writer != null) {
        await writer(csv);
      } else {
        await Clipboard.setData(ClipboardData(text: csv));
      }
      copied = true;
    } catch (_) {
      // Headless or browser clipboard restrictions still leave CSV preview readable.
    }
    if (_disposed) return csv;
    _emit(
      _state.copyWith(
        csvPreview: csv,
        clearError: true,
        statusNotice: copied
            ? 'CSV (${_state.result.points.length}行) を生成しクリップボードへコピーしました。'
            : 'CSV (${_state.result.points.length}行) を生成しました（下のプレビューから確認できます）。',
      ),
    );
    return csv;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
