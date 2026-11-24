import 'package:flutter/material.dart';
import 'package:my_web_app/services/external_regulation_tracker_service.dart';

/// 外部規制・政治的クレーム・サプライチェーン影響トラッカー画面。
@immutable
class ExternalRegulationTrackerPanel extends StatefulWidget {
  const ExternalRegulationTrackerPanel({
    required this.service,
    super.key,
  });

  final ExternalRegulationTrackerService service;

  @override
  State<ExternalRegulationTrackerPanel> createState() =>
      _ExternalRegulationTrackerPanelState();
}

class _ExternalRegulationTrackerPanelState
    extends State<ExternalRegulationTrackerPanel> {
  final TextEditingController _jurisdictionController = TextEditingController(
    text: 'JP',
  );
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _productAreaController = TextEditingController();
  final TextEditingController _sourceRefController = TextEditingController();
  final TextEditingController _effectiveDateController =
      TextEditingController();
  final TextEditingController _stakeholdersController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();

  RegulationFactorCategory _selectedCategory =
      RegulationFactorCategory.regulation;
  RegulationImpactLevel _selectedImpact = RegulationImpactLevel.medium;

  @override
  void dispose() {
    _jurisdictionController.dispose();
    _titleController.dispose();
    _productAreaController.dispose();
    _sourceRefController.dispose();
    _effectiveDateController.dispose();
    _stakeholdersController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final ExternalRegulationImpactDraft draft = ExternalRegulationImpactDraft(
      jurisdictionCode: _jurisdictionController.text,
      factorCategory: _selectedCategory,
      title: _titleController.text,
      affectedProductArea: _productAreaController.text,
      impactLevel: _selectedImpact,
      sourceReference: _sourceRefController.text,
      effectiveDate: _effectiveDateController.text,
      stakeholders: _stakeholdersController.text,
      summary: _summaryController.text,
    );
    final ExternalRegulationValidationResult result =
        await widget.service.submitImpact(draft);
    if (!mounted) {
      return;
    }
    if (result.isValid) {
      _titleController.clear();
      _productAreaController.clear();
      _sourceRefController.clear();
      _effectiveDateController.clear();
      _stakeholdersController.clear();
      _summaryController.clear();
    }
  }

  void _resetForm() {
    _jurisdictionController.text = 'JP';
    _titleController.clear();
    _productAreaController.clear();
    _sourceRefController.clear();
    _effectiveDateController.clear();
    _stakeholdersController.clear();
    _summaryController.clear();
    setState(() {
      _selectedCategory = RegulationFactorCategory.regulation;
      _selectedImpact = RegulationImpactLevel.medium;
    });
    widget.service.clearValidationErrors();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _TrackerPalette palette = _TrackerPalette.fromBrightness(
      isDark: isDark,
    );

    return ListenableBuilder(
      listenable: widget.service,
      builder: (BuildContext context, Widget? child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: palette.panelSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _HeaderBanner(
                  palette: palette,
                  pendingFactCheckCount: widget.service.pendingFactCheckCount,
                  highImpactCount: widget.service.highImpactCount,
                ),
                const SizedBox(height: 16),
                _buildFormSection(palette),
                if (widget.service.validationErrors.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  _MessageCard(
                    key: const ValueKey<String>('regulation-validation-errors'),
                    title: 'バリデーションエラー',
                    lines: widget.service.validationErrors,
                    background: palette.alertBg,
                    foreground: palette.alertFg,
                    border: palette.alertBorder,
                    icon: Icons.error_outline,
                  ),
                ],
                if (widget.service.statusBanner.isNotEmpty &&
                    widget.service.validationErrors.isEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  _MessageCard(
                    key: const ValueKey<String>('regulation-status-banner'),
                    title: '登録・エスカレーション状況',
                    lines: <String>[widget.service.statusBanner],
                    background: palette.pendingBg,
                    foreground: palette.pendingFg,
                    border: palette.pendingBorder,
                    icon: Icons.notifications_active_outlined,
                  ),
                ],
                const SizedBox(height: 16),
                _RecordsSection(
                  palette: palette,
                  items: widget.service.items,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormSection(_TrackerPalette palette) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '新規外部要因の記録・評価（登録時デフォルト: 事実確認待ち）',
              style: TextStyle(
                color: palette.primaryText,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey<String>('regulation-title-field'),
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '件名（規制変更・クレーム・禁輸措置など）*',
                hintText: '例: 対象国による食品・水産物輸入規制の強化',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey<String>('regulation-jurisdiction-field'),
              controller: _jurisdictionController,
              decoration: const InputDecoration(
                labelText: '対象国・地域コード（JP / CN / KR / EU / US / APAC）*',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '要因カテゴリ*',
              style: TextStyle(
                color: palette.secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: RegulationFactorCategory.values
                  .map((RegulationFactorCategory category) {
                final bool selected = _selectedCategory == category;
                return ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: ChoiceChip(
                    key: ValueKey<String>(
                      'regulation-category-${category.dbValue}',
                    ),
                    label: Text(
                      category.labelJa,
                      style: TextStyle(
                        color: selected
                            ? palette.chipSelectedFg
                            : palette.primaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: selected,
                    selectedColor: palette.chipSelectedBg,
                    backgroundColor: palette.cardSurface,
                    side: BorderSide(
                      color: selected
                          ? palette.chipSelectedBorder
                          : palette.borderColor,
                    ),
                    onSelected: (bool isSelected) {
                      if (!isSelected) {
                        return;
                      }
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                  ),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 12),
            Text(
              '影響度*（「高」「緊急」は GitHub Actions 自動Issue通知対象）',
              style: TextStyle(
                color: palette.secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: RegulationImpactLevel.values
                  .map((RegulationImpactLevel level) {
                final bool selected = _selectedImpact == level;
                return ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: ChoiceChip(
                    key: ValueKey<String>(
                      'regulation-impact-${level.dbValue}',
                    ),
                    label: Text(
                      level.labelJa,
                      style: TextStyle(
                        color: selected
                            ? palette.chipSelectedFg
                            : palette.primaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: selected,
                    selectedColor: level.requiresEscalation
                        ? palette.alertBg
                        : palette.chipSelectedBg,
                    backgroundColor: palette.cardSurface,
                    side: BorderSide(
                      color: selected && level.requiresEscalation
                          ? palette.alertBorder
                          : selected
                              ? palette.chipSelectedBorder
                              : palette.borderColor,
                    ),
                    onSelected: (bool isSelected) {
                      if (!isSelected) {
                        return;
                      }
                      setState(() {
                        _selectedImpact = level;
                      });
                    },
                  ),
                );
              }).toList(growable: false),
            ),
            if (_selectedImpact.requiresEscalation) ...<Widget>[
              const SizedBox(height: 10),
              _MessageCard(
                key: const ValueKey<String>('regulation-escalation-preview'),
                title: '高影響エスカレーション通知',
                lines: const <String>[
                  '影響度が「高」または「緊急」のため、保存時に external-regulation-impact-alert.yml を通じて自動Issue作成と関係者通知を実行します。',
                ],
                background: palette.alertBg,
                foreground: palette.alertFg,
                border: palette.alertBorder,
                icon: Icons.warning_amber_rounded,
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey<String>('regulation-product-area-field'),
              controller: _productAreaController,
              decoration: const InputDecoration(
                labelText: '影響プロダクト・ワークフロー領域*',
                hintText: '例: EC決済・輸出入管理ワークフロー',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey<String>('regulation-source-field'),
              controller: _sourceRefController,
              decoration: const InputDecoration(
                labelText: '一次情報・根拠参照（URLまたは公的通達ID）*',
                hintText: 'https://example.go.jp/official/notice',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey<String>('regulation-effective-date-field'),
              controller: _effectiveDateController,
              decoration: const InputDecoration(
                labelText: '発効日・基準日（任意・YYYY-MM-DD）',
                hintText: '2026-11-24',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey<String>('regulation-stakeholders-field'),
              controller: _stakeholdersController,
              decoration: const InputDecoration(
                labelText: '通知先担当者（任意・GitHub ID カンマ区切り）',
                hintText: 'supply-lead, qa-owner',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey<String>('regulation-summary-field'),
              controller: _summaryController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '評価メモ・影響サマリー（任意）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: <Widget>[
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  child: FilledButton.icon(
                    key: const ValueKey<String>('regulation-submit-button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.primaryButtonBg,
                      foregroundColor: palette.primaryButtonFg,
                    ),
                    onPressed:
                        widget.service.isSubmitting ? null : _handleSubmit,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: Text(
                      widget.service.isSubmitting ? '登録中...' : '検証して登録',
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  child: OutlinedButton.icon(
                    key: const ValueKey<String>('regulation-reset-button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.primaryText,
                      side: BorderSide(color: palette.borderColor),
                    ),
                    onPressed: _resetForm,
                    icon: const Icon(Icons.refresh),
                    label: const Text('入力をリセット'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

@immutable
class _HeaderBanner extends StatelessWidget {
  const _HeaderBanner({
    required this.palette,
    required this.pendingFactCheckCount,
    required this.highImpactCount,
  });

  final _TrackerPalette palette;
  final int pendingFactCheckCount;
  final int highImpactCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.public, color: palette.primaryText),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '外部規制・サプライチェーン影響トラッカー',
                softWrap: true,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '各国の法規制・外交声明・経済的影響を一次情報確認前でも安全に追跡するため、すべての新規登録は「事実確認待ち」フラグ付きで保持されます。',
          style: TextStyle(color: palette.secondaryText, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _StatusBadge(
              label: '事実確認待ち: $pendingFactCheckCount件',
              background: palette.pendingBg,
              foreground: palette.pendingFg,
              border: palette.pendingBorder,
            ),
            _StatusBadge(
              label: '高影響アラート対象: $highImpactCount件',
              background: palette.alertBg,
              foreground: palette.alertFg,
              border: palette.alertBorder,
            ),
          ],
        ),
      ],
    );
  }
}

@immutable
class _RecordsSection extends StatelessWidget {
  const _RecordsSection({
    required this.palette,
    required this.items,
  });

  final _TrackerPalette palette;
  final List<ExternalRegulationImpact> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '追跡中の外部要因 (${items.length}件)',
          style: TextStyle(
            color: palette.primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          DecoratedBox(
            decoration: BoxDecoration(
              color: palette.cardSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '記録済みの外部規制・サプライチェーン影響はありません。',
                style: TextStyle(color: palette.secondaryText),
              ),
            ),
          )
        else
          ...items.map((ExternalRegulationImpact item) {
            final bool isPending = item.awaitingFactCheck ||
                item.verificationStatus == FactCheckStatus.pendingFactCheck;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.cardSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              item.title,
                              softWrap: true,
                              style: TextStyle(
                                color: palette.primaryText,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: <Widget>[
                          _StatusBadge(
                            label: isPending
                                ? '事実確認待ち'
                                : item.verificationStatus.labelJa,
                            background:
                                isPending ? palette.pendingBg : palette.okBg,
                            foreground:
                                isPending ? palette.pendingFg : palette.okFg,
                            border: isPending
                                ? palette.pendingBorder
                                : palette.okBorder,
                          ),
                          _StatusBadge(
                            label: '影響度: ${item.impactLevel.labelJa}',
                            background: item.requiresAlertWorkflow
                                ? palette.alertBg
                                : palette.okBg,
                            foreground: item.requiresAlertWorkflow
                                ? palette.alertFg
                                : palette.okFg,
                            border: item.requiresAlertWorkflow
                                ? palette.alertBorder
                                : palette.okBorder,
                          ),
                          _StatusBadge(
                            label: item.jurisdictionCode,
                            background: palette.panelSurface,
                            foreground: palette.primaryText,
                            border: palette.borderColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'カテゴリ: ${item.factorCategory.labelJa} / 領域: ${item.affectedProductArea}',
                        style: TextStyle(
                          color: palette.secondaryText,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '根拠参照: ${item.sourceReference}',
                        style: TextStyle(
                          color: palette.secondaryText,
                          fontSize: 13,
                        ),
                      ),
                      if (item.escalationIssueUrl.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          '自動通知 Issue: ${item.escalationIssueUrl}',
                          style: TextStyle(
                            color: palette.alertFg,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

@immutable
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.background,
    required this.foreground,
    required this.border,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: foreground,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

@immutable
class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.title,
    required this.lines,
    required this.background,
    required this.foreground,
    required this.border,
    required this.icon,
    super.key,
  });

  final String title;
  final List<String> lines;
  final Color background;
  final Color foreground;
  final Color border;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: foreground, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    softWrap: true,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...lines.map(
              (String line) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '• $line',
                  style: TextStyle(color: foreground, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@immutable
class _TrackerPalette {
  const _TrackerPalette({
    required this.panelSurface,
    required this.cardSurface,
    required this.primaryText,
    required this.secondaryText,
    required this.borderColor,
    required this.pendingBg,
    required this.pendingFg,
    required this.pendingBorder,
    required this.alertBg,
    required this.alertFg,
    required this.alertBorder,
    required this.okBg,
    required this.okFg,
    required this.okBorder,
    required this.primaryButtonBg,
    required this.primaryButtonFg,
    required this.chipSelectedBg,
    required this.chipSelectedFg,
    required this.chipSelectedBorder,
  });

  final Color panelSurface;
  final Color cardSurface;
  final Color primaryText;
  final Color secondaryText;
  final Color borderColor;
  final Color pendingBg;
  final Color pendingFg;
  final Color pendingBorder;
  final Color alertBg;
  final Color alertFg;
  final Color alertBorder;
  final Color okBg;
  final Color okFg;
  final Color okBorder;
  final Color primaryButtonBg;
  final Color primaryButtonFg;
  final Color chipSelectedBg;
  final Color chipSelectedFg;
  final Color chipSelectedBorder;

  factory _TrackerPalette.fromBrightness({required bool isDark}) {
    if (isDark) {
      return const _TrackerPalette(
        panelSurface: Color(0xFF0F172A),
        cardSurface: Color(0xFF111827),
        primaryText: Color(0xFFF8FAFC),
        secondaryText: Color(0xFFE2E8F0),
        borderColor: Color(0xFF64748B),
        pendingBg: Color(0xFF451A03),
        pendingFg: Color(0xFFFEF3C7),
        pendingBorder: Color(0xFFF59E0B),
        alertBg: Color(0xFF450A0A),
        alertFg: Color(0xFFFEE2E2),
        alertBorder: Color(0xFFF87171),
        okBg: Color(0xFF052E16),
        okFg: Color(0xFFDCFCE7),
        okBorder: Color(0xFF4ADE80),
        primaryButtonBg: Color(0xFF93C5FD),
        primaryButtonFg: Color(0xFF0F172A),
        chipSelectedBg: Color(0xFF1E3A8A),
        chipSelectedFg: Color(0xFFF8FAFC),
        chipSelectedBorder: Color(0xFF93C5FD),
      );
    }
    return const _TrackerPalette(
      panelSurface: Color(0xFFF8FAFC),
      cardSurface: Color(0xFFFFFFFF),
      primaryText: Color(0xFF0F172A),
      secondaryText: Color(0xFF1E293B),
      borderColor: Color(0xFF475569),
      pendingBg: Color(0xFFFEF3C7),
      pendingFg: Color(0xFF78350F),
      pendingBorder: Color(0xFFB45309),
      alertBg: Color(0xFFFEE2E2),
      alertFg: Color(0xFF7F1D1D),
      alertBorder: Color(0xFFB91C1C),
      okBg: Color(0xFFDCFCE7),
      okFg: Color(0xFF14532D),
      okBorder: Color(0xFF15803D),
      primaryButtonBg: Color(0xFF1E40AF),
      primaryButtonFg: Color(0xFFFFFFFF),
      chipSelectedBg: Color(0xFFDBEAFE),
      chipSelectedFg: Color(0xFF1E3A8A),
      chipSelectedBorder: Color(0xFF1E40AF),
    );
  }
}
