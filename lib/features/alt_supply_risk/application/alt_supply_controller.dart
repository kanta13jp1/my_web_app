import 'package:flutter/foundation.dart';

import '../domain/alt_supply_models.dart';

/// Immutable UI state for alternative supply & import risk monitoring (#2756).
class AltSupplyState {
  const AltSupplyState({
    this.isLoading = false,
    this.isSaving = false,
    this.scenarios = const <AltSupplyScenario>[],
    this.selectedId,
    this.draftTitle = '国内作況・備蓄米シナリオ検証',
    this.draftStockpileTarget = kDefaultStockpileTarget10kT,
    this.draftDomesticProcurement = 64.0,
    this.draftThreshold = kDefaultProcurementThreshold10kT,
    this.draftTotalTarget = kDefaultTotalProductionTarget10kT,
    this.draftCurrentProduction = 735.0,
    this.draftMaQuota = kDefaultMaImportQuota10kT,
    this.draftNotes = '',
    this.errorMessage,
    this.statusNotice,
  });

  final bool isLoading;
  final bool isSaving;
  final List<AltSupplyScenario> scenarios;
  final String? selectedId;
  final String draftTitle;
  final double draftStockpileTarget;
  final double draftDomesticProcurement;
  final double draftThreshold;
  final double draftTotalTarget;
  final double draftCurrentProduction;
  final double draftMaQuota;
  final String draftNotes;
  final String? errorMessage;
  final String? statusNotice;

  AltSupplyMetrics get liveMetrics => AltSupplyMetrics.evaluate(
        stockpileTarget10kT: draftStockpileTarget,
        domesticProcurement10kT: draftDomesticProcurement,
        stockpileThreshold10kT: draftThreshold,
        totalProductionTarget10kT: draftTotalTarget,
        currentProduction10kT: draftCurrentProduction,
        maImportQuota10kT: draftMaQuota,
      );

  AltSupplyScenario? get selectedScenario {
    if (selectedId == null) return null;
    for (final s in scenarios) {
      if (s.id == selectedId) return s;
    }
    return scenarios.isEmpty ? null : scenarios.first;
  }

  AltSupplyState copyWith({
    final bool? isLoading,
    final bool? isSaving,
    final List<AltSupplyScenario>? scenarios,
    final String? selectedId,
    final bool clearSelectedId = false,
    final String? draftTitle,
    final double? draftStockpileTarget,
    final double? draftDomesticProcurement,
    final double? draftThreshold,
    final double? draftTotalTarget,
    final double? draftCurrentProduction,
    final double? draftMaQuota,
    final String? draftNotes,
    final String? errorMessage,
    final bool clearError = false,
    final String? statusNotice,
    final bool clearNotice = false,
  }) {
    return AltSupplyState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      scenarios: scenarios ?? this.scenarios,
      selectedId: clearSelectedId ? null : (selectedId ?? this.selectedId),
      draftTitle: draftTitle ?? this.draftTitle,
      draftStockpileTarget: draftStockpileTarget ?? this.draftStockpileTarget,
      draftDomesticProcurement:
          draftDomesticProcurement ?? this.draftDomesticProcurement,
      draftThreshold: draftThreshold ?? this.draftThreshold,
      draftTotalTarget: draftTotalTarget ?? this.draftTotalTarget,
      draftCurrentProduction:
          draftCurrentProduction ?? this.draftCurrentProduction,
      draftMaQuota: draftMaQuota ?? this.draftMaQuota,
      draftNotes: draftNotes ?? this.draftNotes,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      statusNotice: clearNotice ? null : (statusNotice ?? this.statusNotice),
    );
  }
}

/// Application controller managing supply risk scenarios (#2756).
class AltSupplyController extends ChangeNotifier {
  AltSupplyController({required final AltSupplyRepository repository})
      : _repository = repository;

  final AltSupplyRepository _repository;
  AltSupplyState _state = const AltSupplyState();
  bool _disposed = false;

  AltSupplyState get state => _state;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _emit(final AltSupplyState nextState) {
    if (_disposed) {
      return;
    }
    _state = nextState;
    notifyListeners();
  }

  AltSupplyState _applyScenarioDraft(
    final AltSupplyState base,
    final AltSupplyScenario? scenario,
  ) {
    if (scenario == null) {
      return base.copyWith(clearSelectedId: true);
    }
    return base.copyWith(
      selectedId: scenario.id,
      draftTitle: scenario.title,
      draftStockpileTarget: scenario.stockpileTarget10kT,
      draftDomesticProcurement: scenario.domesticProcurement10kT,
      draftThreshold: scenario.stockpileThreshold10kT,
      draftTotalTarget: scenario.totalProductionTarget10kT,
      draftCurrentProduction: scenario.currentProduction10kT,
      draftMaQuota: scenario.maImportQuota10kT,
      draftNotes: scenario.notes,
    );
  }

  Future<void> loadScenarios() async {
    _emit(
      _state.copyWith(
        isLoading: true,
        clearError: true,
        clearNotice: true,
      ),
    );
    try {
      final list = await _repository.listScenarios();
      if (_disposed) return;
      final selected = list.isEmpty ? null : list.first;
      _emit(
        _applyScenarioDraft(
          _state.copyWith(isLoading: false, scenarios: list, clearError: true),
          selected,
        ),
      );
    } catch (error) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isLoading: false,
          errorMessage: error.toString().replaceFirst('Bad state: ', ''),
        ),
      );
    }
  }

  Future<void> seedDefaults() async {
    if (_state.isSaving) return;
    _emit(_state.copyWith(isSaving: true, clearError: true));
    try {
      final list = await _repository.seedDefaults();
      if (_disposed) return;
      final selected = list.isEmpty ? null : list.first;
      _emit(
        _applyScenarioDraft(
          _state.copyWith(
            isSaving: false,
            scenarios: list,
            statusNotice: '標準シナリオ (${list.length}件) を読み込みました',
            clearError: true,
          ),
          selected,
        ),
      );
    } catch (error) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSaving: false,
          errorMessage: error.toString().replaceFirst('Bad state: ', ''),
        ),
      );
    }
  }

  void selectScenario(final AltSupplyScenario scenario) {
    _emit(
      _applyScenarioDraft(
        _state.copyWith(clearError: true, clearNotice: true),
        scenario,
      ),
    );
  }

  void updateDraftInputs({
    final String? title,
    final double? stockpileTarget10kT,
    final double? domesticProcurement10kT,
    final double? stockpileThreshold10kT,
    final double? totalProductionTarget10kT,
    final double? currentProduction10kT,
    final double? maImportQuota10kT,
    final String? notes,
  }) {
    _emit(
      _state.copyWith(
        draftTitle: title,
        draftStockpileTarget: stockpileTarget10kT?.clamp(0.0, 500.0),
        draftDomesticProcurement: domesticProcurement10kT?.clamp(0.0, 500.0),
        draftThreshold: stockpileThreshold10kT?.clamp(0.0, 500.0),
        draftTotalTarget: totalProductionTarget10kT?.clamp(1.0, 2000.0),
        draftCurrentProduction: currentProduction10kT?.clamp(0.0, 2000.0),
        draftMaQuota: maImportQuota10kT?.clamp(0.0, 500.0),
        draftNotes: notes,
        clearError: true,
      ),
    );
  }

  Future<void> saveSelectedScenario() async {
    final targetId = _state.selectedId;
    if (targetId == null || _state.isSaving) {
      await createScenarioFromDraft();
      return;
    }
    _emit(_state.copyWith(isSaving: true, clearError: true));
    try {
      final updated = await _repository.updateScenario(
        id: targetId,
        title: _state.draftTitle.trim().isEmpty
            ? '需給・輸入リスクシナリオ'
            : _state.draftTitle.trim(),
        stockpileTarget10kT: _state.draftStockpileTarget,
        domesticProcurement10kT: _state.draftDomesticProcurement,
        stockpileThreshold10kT: _state.draftThreshold,
        totalProductionTarget10kT: _state.draftTotalTarget,
        currentProduction10kT: _state.draftCurrentProduction,
        maImportQuota10kT: _state.draftMaQuota,
        notes: _state.draftNotes,
      );
      if (_disposed) return;
      final nextList = _state.scenarios
          .map(
            (final AltSupplyScenario item) =>
                item.id == updated.id ? updated : item,
          )
          .toList(growable: false);
      _emit(
        _applyScenarioDraft(
          _state.copyWith(
            isSaving: false,
            scenarios: nextList,
            statusNotice: 'シナリオ「${updated.title}」を更新しました',
            clearError: true,
          ),
          updated,
        ),
      );
    } catch (error) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSaving: false,
          errorMessage: error.toString().replaceFirst('Bad state: ', ''),
        ),
      );
    }
  }

  Future<void> createScenarioFromDraft() async {
    if (_state.isSaving) return;
    _emit(_state.copyWith(isSaving: true, clearError: true));
    try {
      final created = await _repository.createScenario(
        title: _state.draftTitle.trim().isEmpty
            ? '新規需給・輸入リスクシナリオ'
            : _state.draftTitle.trim(),
        stockpileTarget10kT: _state.draftStockpileTarget,
        domesticProcurement10kT: _state.draftDomesticProcurement,
        stockpileThreshold10kT: _state.draftThreshold,
        totalProductionTarget10kT: _state.draftTotalTarget,
        currentProduction10kT: _state.draftCurrentProduction,
        maImportQuota10kT: _state.draftMaQuota,
        notes: _state.draftNotes,
      );
      if (_disposed) return;
      final nextList = <AltSupplyScenario>[created, ..._state.scenarios];
      _emit(
        _applyScenarioDraft(
          _state.copyWith(
            isSaving: false,
            scenarios: nextList,
            statusNotice: '新規シナリオ「${created.title}」を保存しました',
            clearError: true,
          ),
          created,
        ),
      );
    } catch (error) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSaving: false,
          errorMessage: error.toString().replaceFirst('Bad state: ', ''),
        ),
      );
    }
  }
}
