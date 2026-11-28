import 'package:flutter/material.dart';

import 'application/income_insurance_controller.dart';
import 'domain/income_insurance_models.dart';
import 'presentation/income_insurance_sim_view.dart';

/// Stateful container for income insurance challenge & model comparison (#2757).
class IncomeInsuranceSimContainer extends StatefulWidget {
  const IncomeInsuranceSimContainer({
    super.key,
    this.controller,
    this.clipboardWriter,
    this.initialConfig = const IncomeInsuranceSimulationConfig(),
  });

  final IncomeInsuranceController? controller;
  final IncomeInsuranceClipboardWriter? clipboardWriter;
  final IncomeInsuranceSimulationConfig initialConfig;

  @override
  State<IncomeInsuranceSimContainer> createState() =>
      _IncomeInsuranceSimContainerState();
}

class _IncomeInsuranceSimContainerState
    extends State<IncomeInsuranceSimContainer> {
  late final IncomeInsuranceController _controller;
  late final bool _ownsController;
  late final TextEditingController _scenarioController;
  late final TextEditingController _baseRevenueController;
  late final TextEditingController _declineRateController;
  late final TextEditingController _yearsController;
  late final TextEditingController _windowController;
  late final TextEditingController _coveragePercentController;
  late final TextEditingController _payoutPercentController;
  late final TextEditingController _fixedBenchmarkController;
  late final TextEditingController _directPercentController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        IncomeInsuranceController(
          initialConfig: widget.initialConfig,
          clipboardWriter: widget.clipboardWriter,
        );
    final cfg = _controller.state.config;
    _scenarioController = TextEditingController(text: cfg.scenarioLabel);
    _baseRevenueController =
        TextEditingController(text: cfg.baseRevenue.toStringAsFixed(0));
    _declineRateController = TextEditingController(
      text: cfg.annualDeclinePercent.toStringAsFixed(1),
    );
    _yearsController = TextEditingController(text: cfg.years.toString());
    _windowController =
        TextEditingController(text: cfg.movingAverageWindow.toString());
    _coveragePercentController = TextEditingController(
      text: (cfg.coverageLimitRate * 100.0).toStringAsFixed(0),
    );
    _payoutPercentController = TextEditingController(
      text: (cfg.payoutRate * 100.0).toStringAsFixed(0),
    );
    _fixedBenchmarkController = TextEditingController(
      text: cfg.fixedBenchmarkRevenue.toStringAsFixed(0),
    );
    _directPercentController = TextEditingController(
      text: (cfg.directPaymentSubsidyRate * 100.0).toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    _scenarioController.dispose();
    _baseRevenueController.dispose();
    _declineRateController.dispose();
    _yearsController.dispose();
    _windowController.dispose();
    _coveragePercentController.dispose();
    _payoutPercentController.dispose();
    _fixedBenchmarkController.dispose();
    _directPercentController.dispose();
    super.dispose();
  }

  void _syncInputsFromConfig(final IncomeInsuranceSimulationConfig cfg) {
    _scenarioController.text = cfg.scenarioLabel;
    _baseRevenueController.text = cfg.baseRevenue.toStringAsFixed(0);
    _declineRateController.text = cfg.annualDeclinePercent.toStringAsFixed(1);
    _yearsController.text = cfg.years.toString();
    _windowController.text = cfg.movingAverageWindow.toString();
    _coveragePercentController.text =
        (cfg.coverageLimitRate * 100.0).toStringAsFixed(0);
    _payoutPercentController.text = (cfg.payoutRate * 100.0).toStringAsFixed(0);
    _fixedBenchmarkController.text =
        cfg.fixedBenchmarkRevenue.toStringAsFixed(0);
    _directPercentController.text =
        (cfg.directPaymentSubsidyRate * 100.0).toStringAsFixed(0);
  }

  void _applyPreset(final IncomeInsuranceScenarioPreset preset) {
    _syncInputsFromConfig(preset.config);
    _controller.applyConfig(preset.config);
  }

  void _runSimulation() {
    _controller.runFromRawInputs(
      scenarioLabel: _scenarioController.text,
      baseRevenueRaw: _baseRevenueController.text,
      annualDeclineRaw: _declineRateController.text,
      yearsRaw: _yearsController.text,
      windowRaw: _windowController.text,
      coverageRateRaw: _coveragePercentController.text,
      payoutRateRaw: _payoutPercentController.text,
      fixedBenchmarkRaw: _fixedBenchmarkController.text,
      directRateRaw: _directPercentController.text,
    );
  }

  void _exportCsv() {
    _controller.exportCsv();
  }

  @override
  Widget build(final BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (final BuildContext context, final Widget? child) {
        return IncomeInsuranceSimView(
          state: _controller.state,
          scenarioController: _scenarioController,
          baseRevenueController: _baseRevenueController,
          declineRateController: _declineRateController,
          yearsController: _yearsController,
          windowController: _windowController,
          coveragePercentController: _coveragePercentController,
          payoutPercentController: _payoutPercentController,
          fixedBenchmarkController: _fixedBenchmarkController,
          directPercentController: _directPercentController,
          onApplyPreset: _applyPreset,
          onRunSimulation: _runSimulation,
          onExportCsv: _exportCsv,
        );
      },
    );
  }
}
