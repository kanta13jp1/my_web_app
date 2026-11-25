import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'application/alt_supply_controller.dart';
import 'data/supabase_alt_supply_repository.dart';
import 'domain/alt_supply_models.dart';
import 'presentation/alt_supply_risk_view.dart';

/// DI container for alternative supply & import risk monitoring (#2756).
class AltSupplyRiskContainer extends StatefulWidget {
  const AltSupplyRiskContainer({
    super.key,
    this.repository,
    this.controller,
    this.supabaseClient,
    this.autoLoad = true,
  });

  final AltSupplyRepository? repository;
  final AltSupplyController? controller;
  final SupabaseClient? supabaseClient;
  final bool autoLoad;

  @override
  State<AltSupplyRiskContainer> createState() => _AltSupplyRiskContainerState();
}

class _AltSupplyRiskContainerState extends State<AltSupplyRiskContainer> {
  late final AltSupplyController _controller;
  late final bool _ownsController;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _procurementController = TextEditingController();
  final TextEditingController _thresholdController = TextEditingController();
  final TextEditingController _totalTargetController = TextEditingController();
  final TextEditingController _currentProdController = TextEditingController();
  final TextEditingController _maQuotaController = TextEditingController();
  String? _lastSyncedSignature;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        AltSupplyController(
          repository: widget.repository ??
              SupabaseAltSupplyRepository(client: widget.supabaseClient),
        );
    _syncControllersFromState(_controller.state, force: true);
    _controller.addListener(_onControllerChanged);
    if (widget.autoLoad) {
      _controller.loadScenarios();
    }
  }

  void _onControllerChanged() {
    _syncControllersFromState(_controller.state);
  }

  void _syncControllersFromState(
    final AltSupplyState s, {
    final bool force = false,
  }) {
    final signature =
        '${s.selectedId}|${s.draftTitle}|${s.draftStockpileTarget}'
        '|${s.draftDomesticProcurement}|${s.draftThreshold}'
        '|${s.draftTotalTarget}|${s.draftCurrentProduction}|${s.draftMaQuota}';
    if (!force && signature == _lastSyncedSignature) {
      return;
    }
    _lastSyncedSignature = signature;
    _setIfDifferent(_titleController, s.draftTitle);
    _setIfDifferent(_targetController, s.draftStockpileTarget.toString());
    _setIfDifferent(
      _procurementController,
      s.draftDomesticProcurement.toString(),
    );
    _setIfDifferent(_thresholdController, s.draftThreshold.toString());
    _setIfDifferent(_totalTargetController, s.draftTotalTarget.toString());
    _setIfDifferent(
      _currentProdController,
      s.draftCurrentProduction.toString(),
    );
    _setIfDifferent(_maQuotaController, s.draftMaQuota.toString());
  }

  void _setIfDifferent(
    final TextEditingController ctrl,
    final String nextValue,
  ) {
    if (ctrl.text != nextValue) {
      ctrl.text = nextValue;
    }
  }

  void _handleInputChanged() {
    final s = _controller.state;
    final nextTitle = _titleController.text;
    final nextTarget = double.tryParse(_targetController.text.trim()) ??
        s.draftStockpileTarget;
    final nextProc = double.tryParse(_procurementController.text.trim()) ??
        s.draftDomesticProcurement;
    final nextThresh =
        double.tryParse(_thresholdController.text.trim()) ?? s.draftThreshold;
    final nextTotal = double.tryParse(_totalTargetController.text.trim()) ??
        s.draftTotalTarget;
    final nextCurrent = double.tryParse(_currentProdController.text.trim()) ??
        s.draftCurrentProduction;
    final nextMa =
        double.tryParse(_maQuotaController.text.trim()) ?? s.draftMaQuota;

    _lastSyncedSignature =
        '${s.selectedId}|$nextTitle|$nextTarget|$nextProc|$nextThresh'
        '|$nextTotal|$nextCurrent|$nextMa';
    _controller.updateDraftInputs(
      title: nextTitle,
      stockpileTarget10kT: nextTarget,
      domesticProcurement10kT: nextProc,
      stockpileThreshold10kT: nextThresh,
      totalProductionTarget10kT: nextTotal,
      currentProduction10kT: nextCurrent,
      maImportQuota10kT: nextMa,
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    _titleController.dispose();
    _targetController.dispose();
    _procurementController.dispose();
    _thresholdController.dispose();
    _totalTargetController.dispose();
    _currentProdController.dispose();
    _maQuotaController.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (final BuildContext context, final Widget? _) {
        return AltSupplyRiskView(
          state: _controller.state,
          titleController: _titleController,
          targetController: _targetController,
          procurementController: _procurementController,
          thresholdController: _thresholdController,
          totalTargetController: _totalTargetController,
          currentProductionController: _currentProdController,
          maQuotaController: _maQuotaController,
          onRefresh: _controller.loadScenarios,
          onSeedDefaults: _controller.seedDefaults,
          onSelectScenario: _controller.selectScenario,
          onInputChanged: _handleInputChanged,
          onSaveScenario: _controller.saveSelectedScenario,
          onCreateScenario: _controller.createScenarioFromDraft,
        );
      },
    );
  }
}
