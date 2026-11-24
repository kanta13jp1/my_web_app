import 'package:flutter/material.dart';

import '../services/crisis_mitigation_service.dart';

/// 危機管理リスク評価・事前防災対策プランインテークおよびオフラインキャッシュ表示パネル (#2584)。
class CrisisMitigationIntakePanel extends StatefulWidget {
  const CrisisMitigationIntakePanel({
    super.key,
    this.service,
    this.repository,
    this.cacheStore,
    this.initialSnapshot,
    this.onRiskCreated,
    this.onPlanCreated,
  });

  final CrisisMitigationService? service;
  final CrisisIntakeRepository? repository;
  final CrisisOfflineCacheStore? cacheStore;
  final CrisisIntakeSnapshot? initialSnapshot;
  final ValueChanged<CrisisRiskItem>? onRiskCreated;
  final ValueChanged<MitigationPlanItem>? onPlanCreated;

  @override
  State<CrisisMitigationIntakePanel> createState() =>
      _CrisisMitigationIntakePanelState();
}

class _CrisisMitigationIntakePanelState
    extends State<CrisisMitigationIntakePanel> {
  final TextEditingController _riskTitleCtrl = TextEditingController();
  final TextEditingController _riskNotesCtrl = TextEditingController();
  final TextEditingController _planActionCtrl = TextEditingController();
  final TextEditingController _planOwnerCtrl = TextEditingController();
  final TextEditingController _planTriggerCtrl = TextEditingController();

  CrisisMitigationService? _lazyService;
  late CrisisIntakeSnapshot _snapshot;
  CrisisCategory _selectedCategory = CrisisCategory.naturalDisaster;
  CrisisSeverity _selectedSeverity = CrisisSeverity.high;
  int _likelihood = 3;
  int _impact = 4;
  int _offlinePriority = 1;
  bool _isOfflineEssential = true;
  String? _selectedRiskId;
  bool _loading = false;
  String? _errorMessage;
  String? _statusMessage;

  CrisisMitigationService _resolveService() {
    if (widget.service != null) {
      return widget.service!;
    }
    return _lazyService ??= CrisisMitigationService(
      repository: widget.repository ?? const SupabaseCrisisIntakeRepository(),
      cacheService: CrisisOfflineCacheService(store: widget.cacheStore),
    );
  }

  @override
  void initState() {
    super.initState();
    _snapshot = widget.initialSnapshot ??
        const CrisisIntakeSnapshot(
          risks: <CrisisRiskItem>[],
          plans: <MitigationPlanItem>[],
        );
    if (_snapshot.risks.isNotEmpty) {
      _selectedRiskId = _snapshot.risks.first.id;
    }
    if (widget.initialSnapshot == null) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _riskTitleCtrl.dispose();
    _riskNotesCtrl.dispose();
    _planActionCtrl.dispose();
    _planOwnerCtrl.dispose();
    _planTriggerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    final loaded = await _resolveService().loadWithOfflineFallback();
    if (!mounted) {
      return;
    }
    setState(() {
      _snapshot = loaded;
      _loading = false;
      if ((_selectedRiskId == null ||
              !loaded.risks.any((risk) => risk.id == _selectedRiskId)) &&
          loaded.risks.isNotEmpty) {
        _selectedRiskId = loaded.risks.first.id;
      }
    });
  }

  Future<void> _submitRisk() async {
    final title = _riskTitleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() {
        _errorMessage = 'リスク名を入力してください。';
      });
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
      _statusMessage = null;
    });
    try {
      final created = await _resolveService().createRiskAndSyncCache(
        currentRisks: _snapshot.risks,
        currentPlans: _snapshot.plans,
        title: title,
        category: _selectedCategory,
        severity: _selectedSeverity,
        likelihood: _likelihood,
        impact: _impact,
        notes: _riskNotesCtrl.text.trim(),
      );
      if (!mounted) {
        return;
      }
      _riskTitleCtrl.clear();
      _riskNotesCtrl.clear();
      setState(() {
        _snapshot = CrisisIntakeSnapshot(
          risks: List<CrisisRiskItem>.unmodifiable(
            <CrisisRiskItem>[created, ..._snapshot.risks],
          ),
          plans: _snapshot.plans,
          fromOfflineCache: false,
        );
        _selectedRiskId = created.id;
        _statusMessage = 'リスク「${created.title}」を登録しました。';
        _loading = false;
      });
      widget.onRiskCreated?.call(created);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = 'リスク登録に失敗しました: $e';
      });
    }
  }

  Future<void> _submitPlan() async {
    final actionTitle = _planActionCtrl.text.trim();
    final riskId = _selectedRiskId ??
        (_snapshot.risks.isNotEmpty ? _snapshot.risks.first.id : null);
    if (riskId == null || riskId.isEmpty) {
      setState(() {
        _errorMessage = '先に対象リスクを1件以上登録・選択してください。';
      });
      return;
    }
    if (actionTitle.isEmpty) {
      setState(() {
        _errorMessage = '対策プラン内容を入力してください。';
      });
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
      _statusMessage = null;
    });
    try {
      final created = await _resolveService().createPlanAndSyncCache(
        currentRisks: _snapshot.risks,
        currentPlans: _snapshot.plans,
        riskId: riskId,
        actionTitle: actionTitle,
        ownerRole: _planOwnerCtrl.text.trim(),
        triggerCondition: _planTriggerCtrl.text.trim(),
        offlinePriority: _offlinePriority,
        isOfflineEssential: _isOfflineEssential,
      );
      if (!mounted) {
        return;
      }
      _planActionCtrl.clear();
      _planOwnerCtrl.clear();
      _planTriggerCtrl.clear();
      setState(() {
        _snapshot = CrisisIntakeSnapshot(
          risks: _snapshot.risks,
          plans: List<MitigationPlanItem>.unmodifiable(
            <MitigationPlanItem>[created, ..._snapshot.plans],
          ),
          fromOfflineCache: false,
        );
        _statusMessage = '対策プラン「${created.actionTitle}」を保存しました。';
        _loading = false;
      });
      widget.onPlanCreated?.call(created);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = '対策プランの保存に失敗しました: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF141A22) : Colors.white;
    final cardBorder =
        isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final sectionBg =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final inputBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final primaryText =
        isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final secondaryText =
        isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final outlineColor =
        isDark ? const Color(0xFF64748B) : const Color(0xFF475569);

    final selectedBtnBg =
        isDark ? const Color(0xFFBFDBFE) : const Color(0xFF1E3A8A);
    final selectedBtnFg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final unselectedBtnBg = isDark ? const Color(0xFF0F172A) : Colors.white;

    final offlineBg =
        isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
    final offlineFg =
        isDark ? const Color(0xFFFEF3C7) : const Color(0xFF451A03);
    final offlineBorder =
        isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E);
    final offlineBadgeBg =
        isDark ? const Color(0xFFFDE68A) : const Color(0xFF78350F);
    final offlineBadgeFg = isDark ? const Color(0xFF451A03) : Colors.white;

    final onlineBg = isDark ? const Color(0xFF022C22) : const Color(0xFFD1FAE5);
    final onlineFg = isDark ? const Color(0xFFD1FAE5) : const Color(0xFF064E3B);
    final onlineBorder =
        isDark ? const Color(0xFF34D399) : const Color(0xFF065F46);

    final errorBg = isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
    final errorFg = isDark ? const Color(0xFFFEE2E2) : const Color(0xFF7F1D1D);
    final errorBorder =
        isDark ? const Color(0xFFF87171) : const Color(0xFF991B1B);

    final visiblePlans = _snapshot.fromOfflineCache
        ? _snapshot.offlineEssentialPlans
        : _snapshot.plans;

    return Card(
      key: const ValueKey<String>('crisis_mitigation_intake_panel'),
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.shield_outlined,
                  color: primaryText,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '危機管理・事前防災リスクインテーク',
                    key: const ValueKey<String>('crisis_panel_title'),
                    softWrap: true,
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: IconButton(
                    key: const ValueKey<String>('crisis_refresh_button'),
                    tooltip: '最新データを再読込',
                    onPressed: _loading ? null : _loadData,
                    icon: Icon(Icons.refresh, color: primaryText),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '平時のリスク評価と事前防災アクションを登録し、災害時の通信断でも必携プランをオフライン参照できます。',
              softWrap: true,
              style: TextStyle(
                color: secondaryText,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            if (_snapshot.fromOfflineCache)
              Semantics(
                liveRegion: true,
                container: true,
                label: 'オフライン防災キャッシュ表示中 ${_snapshot.warningMessage ?? ''}',
                child: Container(
                  key: const ValueKey<String>('crisis_offline_cache_banner'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: offlineBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: offlineBorder, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: offlineBadgeBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.cloud_off_outlined,
                              size: 16,
                              color: offlineBadgeFg,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'オフライン防災キャッシュ表示中',
                                softWrap: true,
                                style: TextStyle(
                                  color: offlineBadgeFg,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _snapshot.warningMessage ??
                            '通信障害のため端末保存済みの緊急対策プランを表示しています。',
                        softWrap: true,
                        style: TextStyle(
                          color: offlineFg,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                key: const ValueKey<String>('crisis_online_sync_badge'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: onlineBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: onlineBorder),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.verified_user_outlined,
                      size: 18,
                      color: onlineFg,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'オンライン同期済み（オフライン必携プラン ${_snapshot.offlineEssentialPlans.length}件をローカル保護）',
                        softWrap: true,
                        style: TextStyle(
                          color: onlineFg,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                key: const ValueKey<String>('crisis_form_error_text'),
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: errorBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: errorBorder),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.error_outline, size: 18, color: errorFg),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _errorMessage!,
                        softWrap: true,
                        style: TextStyle(
                          color: errorFg,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_statusMessage != null) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                key: const ValueKey<String>('crisis_form_status_text'),
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: onlineBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: onlineBorder),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: onlineFg,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _statusMessage!,
                        softWrap: true,
                        style: TextStyle(
                          color: onlineFg,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: sectionBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '1. リスク評価インテーク登録',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey<String>('crisis_risk_title_input'),
                    controller: _riskTitleCtrl,
                    style: TextStyle(color: primaryText, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'リスク項目名（例: 首都直下地震による電源・回線途絶）',
                      labelStyle: TextStyle(color: secondaryText),
                      filled: true,
                      fillColor: inputBg,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'カテゴリ',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final category in CrisisCategory.values)
                        _buildOptionButton(
                          buttonKey: ValueKey<String>(
                            'crisis_category_${category.wireValue}',
                          ),
                          label: category.label,
                          selected: _selectedCategory == category,
                          selectedBg: selectedBtnBg,
                          selectedFg: selectedBtnFg,
                          unselectedBg: unselectedBtnBg,
                          unselectedFg: primaryText,
                          borderColor: outlineColor,
                          onPressed: () {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '深刻度',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final severity in CrisisSeverity.values)
                        _buildOptionButton(
                          buttonKey: ValueKey<String>(
                            'crisis_severity_${severity.wireValue}',
                          ),
                          label: severity.label,
                          selected: _selectedSeverity == severity,
                          selectedBg: selectedBtnBg,
                          selectedFg: selectedBtnFg,
                          unselectedBg: unselectedBtnBg,
                          unselectedFg: primaryText,
                          borderColor: outlineColor,
                          onPressed: () {
                            setState(() {
                              _selectedSeverity = severity;
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: <Widget>[
                      _buildStepperRow(
                        label: '発生確率: $_likelihood/5',
                        decKey: const ValueKey<String>(
                          'crisis_likelihood_dec',
                        ),
                        incKey: const ValueKey<String>(
                          'crisis_likelihood_inc',
                        ),
                        decTooltip: '発生確率を下げる',
                        incTooltip: '発生確率を上げる',
                        textColor: primaryText,
                        onDecrement: _likelihood > 1
                            ? () => setState(() => _likelihood -= 1)
                            : null,
                        onIncrement: _likelihood < 5
                            ? () => setState(() => _likelihood += 1)
                            : null,
                      ),
                      _buildStepperRow(
                        label: '影響度: $_impact/5',
                        decKey: const ValueKey<String>('crisis_impact_dec'),
                        incKey: const ValueKey<String>('crisis_impact_inc'),
                        decTooltip: '影響度を下げる',
                        incTooltip: '影響度を上げる',
                        textColor: primaryText,
                        onDecrement: _impact > 1
                            ? () => setState(() => _impact -= 1)
                            : null,
                        onIncrement: _impact < 5
                            ? () => setState(() => _impact += 1)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey<String>('crisis_risk_notes_input'),
                    controller: _riskNotesCtrl,
                    minLines: 1,
                    maxLines: 2,
                    style: TextStyle(color: primaryText, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: '評価メモ・想定被害',
                      labelStyle: TextStyle(color: secondaryText),
                      filled: true,
                      fillColor: inputBg,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    child: FilledButton(
                      key: const ValueKey<String>('crisis_submit_risk_button'),
                      style: FilledButton.styleFrom(
                        backgroundColor: selectedBtnBg,
                        foregroundColor: selectedBtnFg,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _loading ? null : _submitRisk,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.add_alert_outlined,
                            size: 18,
                            color: selectedBtnFg,
                          ),
                          const SizedBox(width: 8),
                          const Flexible(
                            child: Text(
                              'リスク評価を登録',
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: sectionBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '2. 事前防災・初動対策プラン登録',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_snapshot.risks.isNotEmpty) ...<Widget>[
                    Text(
                      '対象リスク選択',
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final risk in _snapshot.risks)
                          _buildOptionButton(
                            buttonKey: ValueKey<String>(
                              'crisis_select_risk_${risk.id}',
                            ),
                            label: risk.title,
                            selected: _selectedRiskId == risk.id,
                            selectedBg: selectedBtnBg,
                            selectedFg: selectedBtnFg,
                            unselectedBg: unselectedBtnBg,
                            unselectedFg: primaryText,
                            borderColor: outlineColor,
                            onPressed: () {
                              setState(() {
                                _selectedRiskId = risk.id;
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    key: const ValueKey<String>('crisis_plan_action_input'),
                    controller: _planActionCtrl,
                    style: TextStyle(color: primaryText, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: '初動対策アクション（例: 衛星通信・非常用電源へ切替）',
                      labelStyle: TextStyle(color: secondaryText),
                      filled: true,
                      fillColor: inputBg,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey<String>('crisis_plan_owner_input'),
                    controller: _planOwnerCtrl,
                    style: TextStyle(color: primaryText, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: '担当役割（例: BCP責任者）',
                      labelStyle: TextStyle(color: secondaryText),
                      filled: true,
                      fillColor: inputBg,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey<String>('crisis_plan_trigger_input'),
                    controller: _planTriggerCtrl,
                    style: TextStyle(color: primaryText, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: '発動条件（例: 震度5強以上または停電10分超）',
                      labelStyle: TextStyle(color: secondaryText),
                      filled: true,
                      fillColor: inputBg,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      _buildStepperRow(
                        label: 'オフライン優先度: P$_offlinePriority',
                        decKey: const ValueKey<String>(
                          'crisis_priority_dec',
                        ),
                        incKey: const ValueKey<String>(
                          'crisis_priority_inc',
                        ),
                        decTooltip: '優先度を上げる（数値小）',
                        incTooltip: '優先度を下げる（数値大）',
                        textColor: primaryText,
                        onDecrement: _offlinePriority > 1
                            ? () => setState(() => _offlinePriority -= 1)
                            : null,
                        onIncrement: _offlinePriority < 5
                            ? () => setState(() => _offlinePriority += 1)
                            : null,
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        child: OutlinedButton(
                          key: const ValueKey<String>(
                            'crisis_plan_offline_toggle',
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _isOfflineEssential
                                ? selectedBtnBg
                                : unselectedBtnBg,
                            foregroundColor: _isOfflineEssential
                                ? selectedBtnFg
                                : primaryText,
                            side: BorderSide(color: outlineColor),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _isOfflineEssential = !_isOfflineEssential;
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                _isOfflineEssential
                                    ? Icons.offline_pin_outlined
                                    : Icons.cloud_queue_outlined,
                                size: 18,
                                color: _isOfflineEssential
                                    ? selectedBtnFg
                                    : primaryText,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _isOfflineEssential
                                      ? 'オフライン必携: ON'
                                      : 'オフライン必携: OFF',
                                  softWrap: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    child: FilledButton(
                      key: const ValueKey<String>('crisis_submit_plan_button'),
                      style: FilledButton.styleFrom(
                        backgroundColor: selectedBtnBg,
                        foregroundColor: selectedBtnFg,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _loading ? null : _submitPlan,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.playlist_add_check,
                            size: 18,
                            color: selectedBtnFg,
                          ),
                          const SizedBox(width: 8),
                          const Flexible(
                            child: Text(
                              '対策プランを保存',
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '登録済みリスク評価 (${_snapshot.risks.length}件)',
              style: TextStyle(
                color: primaryText,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            if (_snapshot.risks.isEmpty)
              Text(
                '登録済みのリスク評価はまだありません。',
                key: const ValueKey<String>('crisis_risks_empty'),
                style: TextStyle(color: secondaryText, fontSize: 13),
              )
            else
              for (final risk in _snapshot.risks)
                _buildRiskCard(
                  risk: risk,
                  isDark: isDark,
                  primaryText: primaryText,
                  secondaryText: secondaryText,
                  cardBorder: cardBorder,
                  sectionBg: sectionBg,
                ),
            const SizedBox(height: 14),
            Text(
              _snapshot.fromOfflineCache
                  ? '災害時オフライン必携対策プラン (${visiblePlans.length}件)'
                  : '事前防災・対策プラン一覧 (${visiblePlans.length}件)',
              style: TextStyle(
                color: primaryText,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            if (visiblePlans.isEmpty)
              Text(
                '表示できる対策プランはまだありません。',
                key: const ValueKey<String>('crisis_plans_empty'),
                style: TextStyle(color: secondaryText, fontSize: 13),
              )
            else
              for (final plan in visiblePlans)
                _buildPlanCard(
                  plan: plan,
                  isDark: isDark,
                  primaryText: primaryText,
                  secondaryText: secondaryText,
                  cardBorder: cardBorder,
                  sectionBg: sectionBg,
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required Key buttonKey,
    required String label,
    required bool selected,
    required Color selectedBg,
    required Color selectedFg,
    required Color unselectedBg,
    required Color unselectedFg,
    required Color borderColor,
    required VoidCallback onPressed,
  }) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(
          child: Text(
            label,
            softWrap: true,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ),
      ],
    );

    if (selected) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: FilledButton(
          key: buttonKey,
          style: FilledButton.styleFrom(
            backgroundColor: selectedBg,
            foregroundColor: selectedFg,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onPressed: onPressed,
          child: child,
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: OutlinedButton(
        key: buttonKey,
        style: OutlinedButton.styleFrom(
          backgroundColor: unselectedBg,
          foregroundColor: unselectedFg,
          side: BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        onPressed: onPressed,
        child: child,
      ),
    );
  }

  Widget _buildStepperRow({
    required String label,
    required Key decKey,
    required Key incKey,
    required String decTooltip,
    required String incTooltip,
    required Color textColor,
    required VoidCallback? onDecrement,
    required VoidCallback? onIncrement,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(
          child: Text(
            label,
            softWrap: true,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: IconButton(
            key: decKey,
            tooltip: decTooltip,
            onPressed: onDecrement,
            icon: Icon(Icons.remove_circle_outline, color: textColor),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: IconButton(
            key: incKey,
            tooltip: incTooltip,
            onPressed: onIncrement,
            icon: Icon(Icons.add_circle_outline, color: textColor),
          ),
        ),
      ],
    );
  }

  Widget _buildRiskCard({
    required CrisisRiskItem risk,
    required bool isDark,
    required Color primaryText,
    required Color secondaryText,
    required Color cardBorder,
    required Color sectionBg,
  }) {
    final (Color badgeFg, Color badgeBg) = switch (risk.severity) {
      CrisisSeverity.critical => isDark
          ? (const Color(0xFFFEE2E2), const Color(0xFF450A0A))
          : (const Color(0xFF7F1D1D), const Color(0xFFFEE2E2)),
      CrisisSeverity.high => isDark
          ? (const Color(0xFFFEF3C7), const Color(0xFF451A03))
          : (const Color(0xFF451A03), const Color(0xFFFEF3C7)),
      CrisisSeverity.medium => isDark
          ? (const Color(0xFF0F172A), const Color(0xFFBFDBFE))
          : (Colors.white, const Color(0xFF1E3A8A)),
      CrisisSeverity.low => isDark
          ? (const Color(0xFFF8FAFC), const Color(0xFF1E293B))
          : (const Color(0xFF0F172A), const Color(0xFFF1F5F9)),
    };

    return Container(
      key: ValueKey<String>('crisis_risk_card_${risk.id}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: sectionBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                risk.title,
                softWrap: true,
                style: TextStyle(
                  color: primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cardBorder),
                ),
                child: Text(
                  '深刻度: ${risk.severity.label}',
                  softWrap: true,
                  style: TextStyle(
                    color: badgeFg,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${risk.category.label} ・ リスクスコア ${risk.riskScore}/25 '
            '(確率${risk.likelihood} × 影響${risk.impact}) ・ ${risk.status.label}',
            softWrap: true,
            style: TextStyle(
              color: secondaryText,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (risk.notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              risk.notes,
              softWrap: true,
              style: TextStyle(
                color: primaryText,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required MitigationPlanItem plan,
    required bool isDark,
    required Color primaryText,
    required Color secondaryText,
    required Color cardBorder,
    required Color sectionBg,
  }) {
    final badgeFg = isDark ? const Color(0xFFD1FAE5) : const Color(0xFF064E3B);
    final badgeBg = isDark ? const Color(0xFF022C22) : const Color(0xFFD1FAE5);
    final stdFg = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final stdBg = isDark ? const Color(0xFF0F172A) : Colors.white;

    return Container(
      key: ValueKey<String>('crisis_plan_card_${plan.id}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: sectionBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Flexible(
                child: Text(
                  plan.actionTitle,
                  softWrap: true,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: stdBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cardBorder),
                ),
                child: Text(
                  '優先度 P${plan.offlinePriority}',
                  style: TextStyle(
                    color: stdFg,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (plan.isOfflineEssential)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'オフライン必携',
                    style: TextStyle(
                      color: badgeFg,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          if (plan.ownerRole.isNotEmpty ||
              plan.triggerCondition.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              '担当: ${plan.ownerRole.isEmpty ? '未設定' : plan.ownerRole} ・ '
              '発動条件: ${plan.triggerCondition.isEmpty ? '即時' : plan.triggerCondition}',
              softWrap: true,
              style: TextStyle(
                color: secondaryText,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
