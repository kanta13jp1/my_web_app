import 'package:flutter/material.dart';

import '../services/admin_action_audit_service.dart';

class _AuditPalette {
  const _AuditPalette({
    required this.cardSurface,
    required this.subSurface,
    required this.textPrimary,
    required this.textMuted,
    required this.border,
    required this.primaryBtnBg,
    required this.primaryBtnFg,
    required this.infoBg,
    required this.infoFg,
    required this.lowBg,
    required this.lowFg,
    required this.mediumBg,
    required this.mediumFg,
    required this.highBg,
    required this.highFg,
    required this.criticalBg,
    required this.criticalFg,
  });

  factory _AuditPalette.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const _AuditPalette(
        cardSurface: Color(0xFF0F172A),
        subSurface: Color(0xFF1E293B),
        textPrimary: Color(0xFFF8FAFC),
        textMuted: Color(0xFFCBD5E1),
        border: Color(0xFF64748B),
        primaryBtnBg: Color(0xFF93C5FD),
        primaryBtnFg: Color(0xFF0F172A),
        infoBg: Color(0xFF172554),
        infoFg: Color(0xFFBFDBFE),
        lowBg: Color(0xFF052E16),
        lowFg: Color(0xFFBBF7D0),
        mediumBg: Color(0xFF422006),
        mediumFg: Color(0xFFFEF08A),
        highBg: Color(0xFF431407),
        highFg: Color(0xFFFED7AA),
        criticalBg: Color(0xFF450A0A),
        criticalFg: Color(0xFFFECACA),
      );
    }
    return const _AuditPalette(
      cardSurface: Color(0xFFFFFFFF),
      subSurface: Color(0xFFF8FAFC),
      textPrimary: Color(0xFF0F172A),
      textMuted: Color(0xFF334155),
      border: Color(0xFF94A3B8),
      primaryBtnBg: Color(0xFF1E40AF),
      primaryBtnFg: Color(0xFFFFFFFF),
      infoBg: Color(0xFFDBEAFE),
      infoFg: Color(0xFF1E3A8A),
      lowBg: Color(0xFFDCFCE7),
      lowFg: Color(0xFF14532D),
      mediumBg: Color(0xFFFEF9C3),
      mediumFg: Color(0xFF713F12),
      highBg: Color(0xFFFFEDD5),
      highFg: Color(0xFF7C2D12),
      criticalBg: Color(0xFFFEE2E2),
      criticalFg: Color(0xFF7F1D1D),
    );
  }

  final Color cardSurface;
  final Color subSurface;
  final Color textPrimary;
  final Color textMuted;
  final Color border;
  final Color primaryBtnBg;
  final Color primaryBtnFg;
  final Color infoBg;
  final Color infoFg;
  final Color lowBg;
  final Color lowFg;
  final Color mediumBg;
  final Color mediumFg;
  final Color highBg;
  final Color highFg;
  final Color criticalBg;
  final Color criticalFg;

  (Color bg, Color fg) riskPair(AdminActionRiskLevel level) {
    return switch (level) {
      AdminActionRiskLevel.low => (lowBg, lowFg),
      AdminActionRiskLevel.medium => (mediumBg, mediumFg),
      AdminActionRiskLevel.high => (highBg, highFg),
      AdminActionRiskLevel.critical => (criticalBg, criticalFg),
    };
  }
}

/// 管理者アクションの監査ログ閲覧・フィルタおよび変更前影響確認UI (#2617)。
class AdminActionAuditPanel extends StatefulWidget {
  const AdminActionAuditPanel({
    super.key,
    this.repository,
  });

  final AdminActionAuditRepository? repository;

  @override
  State<AdminActionAuditPanel> createState() => _AdminActionAuditPanelState();
}

class _AdminActionAuditPanelState extends State<AdminActionAuditPanel> {
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _impactController = TextEditingController();
  final TextEditingController _mitigationController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  late final AdminActionAuditRepository _repository;

  List<AdminActionAuditLogEntry> _logs = const <AdminActionAuditLogEntry>[];
  List<AdminImpactAssessment> _assessments = const <AdminImpactAssessment>[];
  final Map<String, bool> _confirmedChecklist = <String, bool>{};

  AdminActionType _selectedFormAction = AdminActionType.rlsPolicyUpdate;
  AdminAuditFilter _filter = const AdminAuditFilter();
  bool _loading = true;
  bool _submitting = false;
  bool _disposed = false;
  String? _errorMessage;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseAdminActionAuditRepository();
    _loadData();
  }

  @override
  void dispose() {
    _disposed = true;
    _targetController.dispose();
    _summaryController.dispose();
    _impactController.dispose();
    _mitigationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted || _disposed) {
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        _repository.listAuditLogs(),
        _repository.listAssessments(),
      ]);
      if (!mounted || _disposed) {
        return;
      }
      final loadedLogs = results[0] as List<AdminActionAuditLogEntry>;
      final loadedAssessments = results[1] as List<AdminImpactAssessment>;
      setState(() {
        _logs = loadedLogs;
        _assessments = loadedAssessments;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || _disposed) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = '監査ログ・影響評価の読込に失敗しました: $error';
      });
    }
  }

  Future<void> _createAssessment() async {
    final target = _targetController.text.trim();
    final summary = _summaryController.text.trim();
    if (target.isEmpty || summary.isEmpty) {
      setState(() {
        _statusMessage = '対象リソースと変更内容サマリーを入力してください。';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _statusMessage = null;
    });
    try {
      await _repository.createImpactAssessment(
        actionType: _selectedFormAction,
        targetResource: target,
        changeSummary: summary,
        expectedImpactScope: _impactController.text.trim(),
        mitigationPlan: _mitigationController.text.trim(),
      );
      if (!mounted || _disposed) {
        return;
      }
      _targetController.clear();
      _summaryController.clear();
      _impactController.clear();
      _mitigationController.clear();
      setState(() {
        _submitting = false;
        _statusMessage = '変更前の影響評価を起票しました。内容を確認・承認してください。';
      });
      await _loadData();
    } catch (error) {
      if (!mounted || _disposed) {
        return;
      }
      setState(() {
        _submitting = false;
        _statusMessage = '影響評価の起票に失敗しました: $error';
      });
    }
  }

  Future<void> _approveAssessment(AdminImpactAssessment assessment) async {
    final isConfirmed = _confirmedChecklist[assessment.id] ?? false;
    if (!isConfirmed) {
      setState(() {
        _statusMessage = '予想される影響範囲とリスクの確認チェックを完了してください。';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _statusMessage = null;
    });
    try {
      await _repository.confirmAndApproveAssessment(
        id: assessment.id,
        impactConfirmed: true,
        mitigationPlan: assessment.mitigationPlan,
      );
      if (!mounted || _disposed) {
        return;
      }
      setState(() {
        _submitting = false;
        _statusMessage = '事前影響確認を承認し、監査ログへ記録しました。';
      });
      await _loadData();
    } catch (error) {
      if (!mounted || _disposed) {
        return;
      }
      setState(() {
        _submitting = false;
        _statusMessage = '承認処理に失敗しました: $error';
      });
    }
  }

  Future<void> _executeAssessment(AdminImpactAssessment assessment) async {
    setState(() {
      _submitting = true;
      _statusMessage = null;
    });
    try {
      await _repository.executeApprovedAssessment(id: assessment.id);
      if (!mounted || _disposed) {
        return;
      }
      setState(() {
        _submitting = false;
        _statusMessage = '変更実行を監査ログへ記録しました。';
      });
      await _loadData();
    } catch (error) {
      if (!mounted || _disposed) {
        return;
      }
      setState(() {
        _submitting = false;
        _statusMessage = '実行記録に失敗しました: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _AuditPalette.of(context);
    final summary = AdminAuditSummary.compute(
      logs: _logs,
      assessments: _assessments,
    );
    final filteredLogs = _filter.apply(_logs);
    final previewEval = AdminActionImpactEvaluator.evaluate(
      actionType: _selectedFormAction,
      targetResource: _targetController.text,
      changeSummary: _summaryController.text,
      expectedImpactScope: _impactController.text,
      mitigationPlan: _mitigationController.text,
    );

    return Material(
      color: palette.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildHeader(palette),
            const SizedBox(height: 12),
            _buildSummaryRow(palette, summary),
            if (_statusMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              _buildNoticeBanner(
                palette: palette,
                bg: palette.infoBg,
                fg: palette.infoFg,
                message: _statusMessage!,
              ),
            ],
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              _buildErrorSection(palette, _errorMessage!),
            ],
            const SizedBox(height: 16),
            _buildImpactForm(palette, previewEval),
            const SizedBox(height: 16),
            _buildAssessmentsSection(palette),
            const SizedBox(height: 16),
            _buildFilterBar(palette),
            const SizedBox(height: 12),
            _buildAuditFeed(palette, filteredLogs),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(_AuditPalette palette) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(
            '管理者アクション監査ログ・変更前影響評価',
            softWrap: true,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: OutlinedButton.icon(
              key: const ValueKey<String>('audit_refresh_button'),
              onPressed: _loading ? null : _loadData,
              style: OutlinedButton.styleFrom(
                backgroundColor: palette.cardSurface,
                foregroundColor: palette.textPrimary,
                disabledBackgroundColor: palette.cardSurface,
                disabledForegroundColor: palette.textMuted,
                side: BorderSide(color: palette.border),
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('更新'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    _AuditPalette palette,
    AdminAuditSummary summary,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _SummaryMetricChip(
          label: '監査ログ総数: ${summary.totalLogs}',
          bg: palette.infoBg,
          fg: palette.infoFg,
        ),
        _SummaryMetricChip(
          label: 'High/Critical: ${summary.highOrCriticalCount}',
          bg: palette.highBg,
          fg: palette.highFg,
        ),
        _SummaryMetricChip(
          label: '確認待ち評価: ${summary.pendingAssessmentCount}',
          bg: palette.mediumBg,
          fg: palette.mediumFg,
        ),
        _SummaryMetricChip(
          label: '実行記録済み: ${summary.executedCount}',
          bg: palette.lowBg,
          fg: palette.lowFg,
        ),
      ],
    );
  }

  Widget _buildNoticeBanner({
    required _AuditPalette palette,
    required Color bg,
    required Color fg,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              message,
              softWrap: true,
              style: TextStyle(color: fg, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorSection(_AuditPalette palette, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.criticalBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  message,
                  softWrap: true,
                  style: TextStyle(
                    color: palette.criticalFg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: OutlinedButton(
              key: const ValueKey<String>('audit_retry_button'),
              onPressed: _loadData,
              style: OutlinedButton.styleFrom(
                backgroundColor: palette.cardSurface,
                foregroundColor: palette.textPrimary,
                side: BorderSide(color: palette.border),
              ),
              child: const Text('再試行'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactForm(
    _AuditPalette palette,
    AdminImpactEvaluationResult previewEval,
  ) {
    final riskColors = palette.riskPair(previewEval.riskLevel);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.subSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                '変更前リスク・影響範囲評価を起票',
                softWrap: true,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              _SummaryMetricChip(
                label:
                    '判定: ${previewEval.riskLevel.label} (${previewEval.riskScore})',
                bg: riskColors.$1,
                fg: riskColors.$2,
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<AdminActionType>(
            key: const ValueKey<String>('audit_action_type_dropdown'),
            initialValue: _selectedFormAction,
            dropdownColor: palette.cardSurface,
            style: TextStyle(color: palette.textPrimary),
            decoration: _inputDecoration(palette, '変更種別'),
            items: AdminActionType.values
                .map(
                  (type) => DropdownMenuItem<AdminActionType>(
                    value: type,
                    child: Text(
                      type.labelJa,
                      style: TextStyle(color: palette.textPrimary),
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedFormAction = value;
                });
              }
            },
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey<String>('audit_target_resource_input'),
            controller: _targetController,
            style: TextStyle(color: palette.textPrimary),
            decoration: _inputDecoration(
              palette,
              '対象リソース (例: public.user_profiles RLS)',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey<String>('audit_change_summary_input'),
            controller: _summaryController,
            style: TextStyle(color: palette.textPrimary),
            decoration: _inputDecoration(palette, '変更内容サマリー'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey<String>('audit_impact_scope_input'),
            controller: _impactController,
            style: TextStyle(color: palette.textPrimary),
            decoration: _inputDecoration(palette, '予想される影響範囲・副作用'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey<String>('audit_mitigation_input'),
            controller: _mitigationController,
            style: TextStyle(color: palette.textPrimary),
            decoration: _inputDecoration(palette, '緩和策・ロールバック手順'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  '推奨対策: ${previewEval.recommendedMitigation}',
                  softWrap: true,
                  style: TextStyle(fontSize: 12, color: palette.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: FilledButton(
              key: const ValueKey<String>('audit_create_assessment_button'),
              onPressed: _submitting ? null : _createAssessment,
              style: FilledButton.styleFrom(
                backgroundColor: palette.primaryBtnBg,
                foregroundColor: palette.primaryBtnFg,
                disabledBackgroundColor: palette.cardSurface,
                disabledForegroundColor: palette.textMuted,
              ),
              child: const Text('影響評価を起票'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentsSection(_AuditPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                '変更前確認・承認ステップ (${_assessments.length}件)',
                softWrap: true,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_assessments.isEmpty && !_loading)
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  '現在、レビュー対象の影響評価はありません。',
                  softWrap: true,
                  style: TextStyle(color: palette.textMuted),
                ),
              ),
            ],
          )
        else
          ..._assessments.map((item) => _buildAssessmentCard(palette, item)),
      ],
    );
  }

  Widget _buildAssessmentCard(
    _AuditPalette palette,
    AdminImpactAssessment item,
  ) {
    final riskColors = palette.riskPair(item.riskLevel);
    final isConfirmed = _confirmedChecklist[item.id] ?? item.impactConfirmed;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                '${item.actionType.labelJa}: ${item.targetResource}',
                softWrap: true,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              _SummaryMetricChip(
                label: '${item.riskLevel.label} / ${item.status.labelJa}',
                bg: riskColors.$1,
                fg: riskColors.$2,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  '変更内容: ${item.changeSummary}',
                  softWrap: true,
                  style: TextStyle(color: palette.textPrimary),
                ),
              ),
            ],
          ),
          if (item.expectedImpactScope.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    '想定影響: ${item.expectedImpactScope}',
                    softWrap: true,
                    style: TextStyle(color: palette.textMuted),
                  ),
                ),
              ],
            ),
          ],
          if (item.mitigationPlan.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    '緩和策: ${item.mitigationPlan}',
                    softWrap: true,
                    style: TextStyle(color: palette.textMuted),
                  ),
                ),
              ],
            ),
          ],
          if (item.status == AdminAssessmentStatus.pendingReview) ...<Widget>[
            CheckboxListTile(
              key: ValueKey<String>('audit_confirm_checkbox_${item.id}'),
              contentPadding: EdgeInsets.zero,
              value: isConfirmed,
              activeColor: palette.primaryBtnBg,
              checkColor: palette.primaryBtnFg,
              title: Text(
                '予想される影響範囲とリスクを確認し、この変更を承認します',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
              onChanged: (checked) {
                setState(() {
                  _confirmedChecklist[item.id] = checked ?? false;
                });
              },
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: FilledButton(
                key: ValueKey<String>('audit_approve_button_${item.id}'),
                onPressed: (_submitting || !isConfirmed)
                    ? null
                    : () => _approveAssessment(item),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.primaryBtnBg,
                  foregroundColor: palette.primaryBtnFg,
                  disabledBackgroundColor: palette.cardSurface,
                  disabledForegroundColor: palette.textMuted,
                ),
                child: const Text('影響確認して承認'),
              ),
            ),
          ] else if (item.status == AdminAssessmentStatus.approved) ...<Widget>[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: OutlinedButton(
                key: ValueKey<String>('audit_execute_button_${item.id}'),
                onPressed: _submitting ? null : () => _executeAssessment(item),
                style: OutlinedButton.styleFrom(
                  backgroundColor: palette.cardSurface,
                  foregroundColor: palette.textPrimary,
                  disabledBackgroundColor: palette.cardSurface,
                  disabledForegroundColor: palette.textMuted,
                  side: BorderSide(color: palette.border),
                ),
                child: const Text('実行完了を記録'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterBar(_AuditPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                '監査ログフィルタ',
                softWrap: true,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey<String>('audit_search_input'),
          controller: _searchController,
          style: TextStyle(color: palette.textPrimary),
          decoration: _inputDecoration(
            palette,
            'リソース・影響概要・アクション種別で検索',
          ),
          onChanged: (value) {
            setState(() {
              _filter = _filter.copyWith(searchQuery: value);
            });
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _buildRiskChip(palette, null, '全リスク'),
            for (final level in AdminActionRiskLevel.values)
              _buildRiskChip(palette, level, level.label),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _buildOpChip(palette, null, '全操作'),
            for (final op in AdminAuditOperation.values)
              _buildOpChip(palette, op, op.labelJa),
          ],
        ),
      ],
    );
  }

  Widget _buildRiskChip(
    _AuditPalette palette,
    AdminActionRiskLevel? level,
    String label,
  ) {
    final selected = _filter.riskLevel == level;
    return FilterChip(
      key: ValueKey<String>('audit_risk_chip_${level?.wireValue ?? 'all'}'),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      label: Text(
        label,
        style: TextStyle(
          color: selected ? palette.infoFg : palette.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: selected,
      backgroundColor: palette.cardSurface,
      selectedColor: palette.infoBg,
      checkmarkColor: palette.infoFg,
      side: BorderSide(color: palette.border),
      onSelected: (_) {
        setState(() {
          _filter = level == null
              ? _filter.copyWith(clearRiskLevel: true)
              : _filter.copyWith(riskLevel: level);
        });
      },
    );
  }

  Widget _buildOpChip(
    _AuditPalette palette,
    AdminAuditOperation? op,
    String label,
  ) {
    final selected = _filter.operation == op;
    return FilterChip(
      key: ValueKey<String>('audit_op_chip_${op?.wireValue ?? 'all'}'),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      label: Text(
        label,
        style: TextStyle(
          color: selected ? palette.infoFg : palette.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: selected,
      backgroundColor: palette.cardSurface,
      selectedColor: palette.infoBg,
      checkmarkColor: palette.infoFg,
      side: BorderSide(color: palette.border),
      onSelected: (_) {
        setState(() {
          _filter = op == null
              ? _filter.copyWith(clearOperation: true)
              : _filter.copyWith(operation: op);
        });
      },
    );
  }

  Widget _buildAuditFeed(
    _AuditPalette palette,
    List<AdminActionAuditLogEntry> entries,
  ) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (entries.isEmpty) {
      return Row(
        children: <Widget>[
          Flexible(
            child: Text(
              '条件に一致する監査ログはありません。',
              softWrap: true,
              style: TextStyle(color: palette.textMuted),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries
          .map((entry) => _buildAuditLogRow(palette, entry))
          .toList(growable: false),
    );
  }

  Widget _buildAuditLogRow(
    _AuditPalette palette,
    AdminActionAuditLogEntry entry,
  ) {
    final riskColors = palette.riskPair(entry.riskLevel);
    final timestampLabel = entry.createdAt?.toIso8601String() ?? '時刻未設定';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.subSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                '[${entry.operation.labelJa}] ${entry.actionType.labelJa} - ${entry.targetResource}',
                softWrap: true,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              _SummaryMetricChip(
                label: entry.riskLevel.label,
                bg: riskColors.$1,
                fg: riskColors.$2,
              ),
            ],
          ),
          if (entry.impactSummary.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    '影響範囲: ${entry.impactSummary}',
                    softWrap: true,
                    style: TextStyle(color: palette.textPrimary),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  '実行ロール: ${entry.actorRole} / 影響確認: ${entry.impactConfirmed ? '確認済み' : '未確認'} / $timestampLabel',
                  softWrap: true,
                  style: TextStyle(fontSize: 12, color: palette.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(_AuditPalette palette, String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: palette.textMuted),
      filled: true,
      fillColor: palette.cardSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: palette.border),
      ),
    );
  }
}

class _SummaryMetricChip extends StatelessWidget {
  const _SummaryMetricChip({
    required this.label,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        softWrap: true,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
