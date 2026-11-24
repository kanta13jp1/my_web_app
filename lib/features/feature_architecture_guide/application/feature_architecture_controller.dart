import 'package:flutter/foundation.dart';

enum ArchitectureLayerFilter {
  all('all', 'すべて'),
  presentation('presentation', 'Presentation'),
  application('application', 'Application'),
  shared('shared', 'Shared / Common');

  const ArchitectureLayerFilter(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

@immutable
class ArchitectureStandardRule {
  const ArchitectureStandardRule({
    required this.id,
    required this.title,
    required this.layer,
    required this.directoryPattern,
    required this.responsibility,
    required this.prohibitedDependencies,
  });

  final String id;
  final String title;
  final ArchitectureLayerFilter layer;
  final String directoryPattern;
  final String responsibility;
  final List<String> prohibitedDependencies;
}

@immutable
class ArchitectureChecklistItem {
  const ArchitectureChecklistItem({
    required this.id,
    required this.label,
    required this.checked,
  });

  final String id;
  final String label;
  final bool checked;

  ArchitectureChecklistItem copyWith({bool? checked}) {
    return ArchitectureChecklistItem(
      id: id,
      label: label,
      checked: checked ?? this.checked,
    );
  }
}

@immutable
class ArchitectureGuideState {
  const ArchitectureGuideState({
    required this.filter,
    required this.rules,
    required this.selectedRuleId,
    required this.checklist,
    required this.searchQuery,
  });

  final ArchitectureLayerFilter filter;
  final List<ArchitectureStandardRule> rules;
  final String selectedRuleId;
  final List<ArchitectureChecklistItem> checklist;
  final String searchQuery;

  List<ArchitectureStandardRule> get filteredRules {
    final normalizedQuery = searchQuery.trim().toLowerCase();
    return rules.where((rule) {
      final matchesLayer =
          filter == ArchitectureLayerFilter.all || rule.layer == filter;
      if (!matchesLayer) return false;
      if (normalizedQuery.isEmpty) return true;
      return rule.title.toLowerCase().contains(normalizedQuery) ||
          rule.directoryPattern.toLowerCase().contains(normalizedQuery) ||
          rule.responsibility.toLowerCase().contains(normalizedQuery);
    }).toList(growable: false);
  }

  int get completedChecklistCount =>
      checklist.where((item) => item.checked).length;

  ArchitectureStandardRule? get selectedRule {
    for (final rule in filteredRules) {
      if (rule.id == selectedRuleId) return rule;
    }
    return filteredRules.isNotEmpty ? filteredRules.first : null;
  }

  ArchitectureGuideState copyWith({
    ArchitectureLayerFilter? filter,
    List<ArchitectureStandardRule>? rules,
    String? selectedRuleId,
    List<ArchitectureChecklistItem>? checklist,
    String? searchQuery,
  }) {
    return ArchitectureGuideState(
      filter: filter ?? this.filter,
      rules: rules ?? this.rules,
      selectedRuleId: selectedRuleId ?? this.selectedRuleId,
      checklist: checklist ?? this.checklist,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// 機能単位構成と Container/Presentation 分離の制御ロジック (#2603)。
class FeatureArchitectureController extends ChangeNotifier {
  FeatureArchitectureController({
    ArchitectureGuideState? initialState,
  }) : _state = initialState ?? buildDefaultState();

  static ArchitectureGuideState buildDefaultState() {
    return const ArchitectureGuideState(
      filter: ArchitectureLayerFilter.all,
      rules: <ArchitectureStandardRule>[
        ArchitectureStandardRule(
          id: 'rule-presentation',
          title: 'Presentation 層は純粋 UI に限定する',
          layer: ArchitectureLayerFilter.presentation,
          directoryPattern: 'lib/features/<name>/presentation/',
          responsibility: 'Immutable な State とイベントコールバックを受け取り描画のみを行う',
          prohibitedDependencies: <String>[
            'package:supabase_flutter',
            'package:http',
            'dart:io',
            'dart:html',
          ],
        ),
        ArchitectureStandardRule(
          id: 'rule-application',
          title: 'Application 層は状態管理と業務ルールを担う',
          layer: ArchitectureLayerFilter.application,
          directoryPattern: 'lib/features/<name>/application/',
          responsibility:
              'ChangeNotifier / ValueNotifier による状態遷移・入力検証・破棄安全性を担保する',
          prohibitedDependencies: <String>[
            'BuildContext の直接保持',
            'Widget ビルド処理',
          ],
        ),
        ArchitectureStandardRule(
          id: 'rule-shared',
          title: 'Shared ディレクトリは複数機能共通 UI のみ配置',
          layer: ArchitectureLayerFilter.shared,
          directoryPattern: 'lib/widgets/ & lib/services/',
          responsibility: '2 機能以上で横断再利用されるコンポーネントとインフラのみを格納する',
          prohibitedDependencies: <String>[
            '単一機能固有の業務ロジック',
          ],
        ),
      ],
      selectedRuleId: 'rule-presentation',
      checklist: <ArchitectureChecklistItem>[
        ArchitectureChecklistItem(
          id: 'chk-feature-dir',
          label: '新設機能は lib/features/<name>/ 配下に配置済み',
          checked: true,
        ),
        ArchitectureChecklistItem(
          id: 'chk-pure-presentation',
          label: 'presentation/ から supabase_flutter / http を直接参照しない',
          checked: true,
        ),
        ArchitectureChecklistItem(
          id: 'chk-shared-boundary',
          label: '機能固有ウィジェットを lib/widgets/ へ混入しない',
          checked: false,
        ),
      ],
      searchQuery: '',
    );
  }

  ArchitectureGuideState _state;
  bool _disposed = false;

  ArchitectureGuideState get state => _state;
  bool get isDisposed => _disposed;

  void _commit(ArchitectureGuideState nextState) {
    if (_disposed) return;
    _state = nextState;
    notifyListeners();
  }

  void selectFilter(ArchitectureLayerFilter filter) {
    final next = _state.copyWith(filter: filter);
    final candidates = next.filteredRules;
    final nextSelected = candidates.isEmpty
        ? ''
        : (candidates.any((r) => r.id == _state.selectedRuleId)
            ? _state.selectedRuleId
            : candidates.first.id);
    _commit(next.copyWith(selectedRuleId: nextSelected));
  }

  void selectRule(String ruleId) {
    _commit(_state.copyWith(selectedRuleId: ruleId));
  }

  void setSearchQuery(String query) {
    _commit(_state.copyWith(searchQuery: query));
  }

  void toggleChecklistItem(String itemId) {
    final updated = _state.checklist
        .map(
          (item) =>
              item.id == itemId ? item.copyWith(checked: !item.checked) : item,
        )
        .toList(growable: false);
    _commit(_state.copyWith(checklist: updated));
  }

  void resetDefaults() {
    _commit(buildDefaultState());
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
