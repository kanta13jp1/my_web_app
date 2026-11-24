import 'package:flutter/material.dart';

import '../services/intake_compliance_screening_service.dart';

/// インテークデータの法規制・コンプライアンス確認待ち一覧と審査アクションUI (#2595)。
class IntakeComplianceReviewPanel extends StatefulWidget {
  const IntakeComplianceReviewPanel({
    super.key,
    this.repository,
    this.initialScreenings,
  });

  final IntakeComplianceRepository? repository;
  final List<IntakeComplianceScreeningItem>? initialScreenings;

  @override
  State<IntakeComplianceReviewPanel> createState() =>
      _IntakeComplianceReviewPanelState();
}

class _IntakeComplianceReviewPanelState
    extends State<IntakeComplianceReviewPanel> {
  IntakeComplianceRepository? _repo;
  List<IntakeComplianceScreeningItem> _items =
      const <IntakeComplianceScreeningItem>[];
  bool _onlyVerificationPending = true;
  bool _loading = false;
  String? _errorMessage;
  String? _statusMessage;

  IntakeComplianceRepository _resolveRepository() {
    return _repo ??= widget.repository ?? SupabaseIntakeComplianceRepository();
  }

  @override
  void initState() {
    super.initState();
    _repo = widget.repository;
    final seeded = widget.initialScreenings;
    if (seeded != null) {
      _items = List<IntakeComplianceScreeningItem>.unmodifiable(seeded);
    } else {
      _loadScreenings();
    }
  }

  Future<void> _loadScreenings() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final fetched = await _resolveRepository().listScreenings(limit: 50);
      if (!mounted) return;
      setState(() {
        _items = List<IntakeComplianceScreeningItem>.unmodifiable(fetched);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'コンプライアンス審査一覧の取得に失敗しました: $e';
      });
    }
  }

  Future<void> _applyReviewStatus(
    IntakeComplianceScreeningItem item,
    ComplianceReviewStatus status,
  ) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _statusMessage = null;
    });
    try {
      final updated = await _resolveRepository().updateReviewStatus(
        id: item.id,
        status: status,
      );
      if (!mounted) return;
      setState(() {
        _items = _items
            .map((entry) => entry.id == updated.id ? updated : entry)
            .toList(growable: false);
        _loading = false;
        _statusMessage = '「${updated.title}」を${status.label}へ更新しました';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = '審査ステータスの更新に失敗しました: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = _CompliancePalette.fromBrightness(isDark);
    final pendingCount =
        _items.where((item) => item.requiresVerification).length;
    final visible = _items
        .where(
          (item) => !_onlyVerificationPending || item.requiresVerification,
        )
        .toList(growable: false);

    return Card(
      key: const ValueKey<String>('intake_compliance_review_panel'),
      color: palette.cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.policy_outlined, color: palette.accentFg),
                const SizedBox(width: 8),
                Flexible(
                  fit: FlexFit.tight,
                  child: Text(
                    '法規制・コンプライアンス審査キュー (要確認 $pendingCount件)',
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: IconButton(
                    key: const ValueKey<String>('compliance_refresh_btn'),
                    tooltip: '審査キューを再読込',
                    color: palette.textPrimary,
                    onPressed: _loading ? null : _loadScreenings,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '独占禁止法・企業結合規制・財務予測・業法規制などの自動スクリーニング結果を確認し、承認または保留できます。',
              softWrap: true,
              style: TextStyle(
                fontSize: 13,
                color: palette.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: FilterChip(
                    key: const ValueKey<String>(
                      'compliance_requires_verification_filter',
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    selected: _onlyVerificationPending,
                    backgroundColor: palette.chipUnselectedBg,
                    selectedColor: palette.chipSelectedBg,
                    checkmarkColor: palette.chipSelectedFg,
                    side: BorderSide(color: palette.border),
                    labelStyle: TextStyle(
                      color: _onlyVerificationPending
                          ? palette.chipSelectedFg
                          : palette.chipUnselectedFg,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _onlyVerificationPending = selected;
                      });
                    },
                    label: const Text('要法務確認のみ'),
                  ),
                ),
              ],
            ),
            if (_loading) ...<Widget>[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              _buildBanner(
                key: const ValueKey<String>('compliance_error_banner'),
                icon: Icons.error_outline,
                message: _errorMessage!,
                fg: palette.errorFg,
                bg: palette.errorBg,
                border: palette.errorFg,
              ),
            ],
            if (_statusMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              _buildBanner(
                key: const ValueKey<String>('compliance_status_banner'),
                icon: Icons.check_circle_outline,
                message: _statusMessage!,
                fg: palette.successFg,
                bg: palette.successBg,
                border: palette.successFg,
              ),
            ],
            const SizedBox(height: 12),
            if (visible.isEmpty)
              Container(
                key: const ValueKey<String>('compliance_empty_state'),
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: palette.surfaceAltBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  _onlyVerificationPending
                      ? '法務・コンプライアンス確認待ちのインテークデータはありません。'
                      : 'スクリーニング済みのインテークデータはまだありません。',
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 13,
                    color: palette.textSecondary,
                    height: 1.5,
                  ),
                ),
              )
            else
              Column(
                children: visible
                    .map((item) => _buildScreeningCard(context, item, palette))
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner({
    required Key key,
    required IconData icon,
    required String message,
    required Color fg,
    required Color bg,
    required Color border,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              softWrap: true,
              style: TextStyle(
                fontSize: 13,
                color: fg,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreeningCard(
    BuildContext context,
    IntakeComplianceScreeningItem item,
    _CompliancePalette palette,
  ) {
    final badgeFg =
        item.requiresVerification ? palette.warningFg : palette.successFg;
    final badgeBg =
        item.requiresVerification ? palette.warningBg : palette.successBg;
    final statusLabel = item.requiresVerification
        ? '要確認 (${item.riskCategory.label} / スコア ${item.riskScore})'
        : '${item.reviewStatus.label} (${item.riskCategory.label})';

    return Container(
      key: ValueKey<String>('compliance_item_${item.id}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceAltBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Flexible(
                fit: FlexFit.tight,
                child: Text(
                  item.title,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.infoBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.intakeSource.label,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: palette.infoFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  item.requiresVerification
                      ? Icons.warning_amber_rounded
                      : Icons.verified_outlined,
                  size: 16,
                  color: badgeFg,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    statusLabel,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: badgeFg,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (item.contentExcerpt.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              item.contentExcerpt,
              softWrap: true,
              style: TextStyle(
                fontSize: 12,
                color: palette.textSecondary,
                height: 1.5,
              ),
            ),
          ],
          if (item.matchedKeywords.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: item.matchedKeywords
                  .map(
                    (keyword) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: palette.errorBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        keyword,
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: palette.errorFg,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: ElevatedButton.icon(
                  key: ValueKey<String>('compliance_approve_${item.id}'),
                  onPressed: _loading
                      ? null
                      : () => _applyReviewStatus(
                            item,
                            ComplianceReviewStatus.verifiedSafe,
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primaryBtnBg,
                    foregroundColor: palette.primaryBtnFg,
                    disabledBackgroundColor: palette.disabledBg,
                    disabledForegroundColor: palette.disabledFg,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('安全確認済'),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: OutlinedButton.icon(
                  key: ValueKey<String>('compliance_hold_${item.id}'),
                  onPressed: _loading
                      ? null
                      : () => _applyReviewStatus(
                            item,
                            ComplianceReviewStatus.flaggedHold,
                          ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: palette.cardBg,
                    foregroundColor: palette.secondaryBtnFg,
                    disabledForegroundColor: palette.disabledFg,
                    side: BorderSide(color: palette.secondaryBtnFg),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.pause_circle_outline, size: 18),
                  label: const Text('保留'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompliancePalette {
  const _CompliancePalette({
    required this.cardBg,
    required this.surfaceAltBg,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.accentFg,
    required this.primaryBtnBg,
    required this.primaryBtnFg,
    required this.secondaryBtnFg,
    required this.disabledBg,
    required this.disabledFg,
    required this.infoFg,
    required this.infoBg,
    required this.successFg,
    required this.successBg,
    required this.warningFg,
    required this.warningBg,
    required this.errorFg,
    required this.errorBg,
    required this.chipSelectedBg,
    required this.chipSelectedFg,
    required this.chipUnselectedBg,
    required this.chipUnselectedFg,
  });

  final Color cardBg;
  final Color surfaceAltBg;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color accentFg;
  final Color primaryBtnBg;
  final Color primaryBtnFg;
  final Color secondaryBtnFg;
  final Color disabledBg;
  final Color disabledFg;
  final Color infoFg;
  final Color infoBg;
  final Color successFg;
  final Color successBg;
  final Color warningFg;
  final Color warningBg;
  final Color errorFg;
  final Color errorBg;
  final Color chipSelectedBg;
  final Color chipSelectedFg;
  final Color chipUnselectedBg;
  final Color chipUnselectedFg;

  factory _CompliancePalette.fromBrightness(bool isDark) {
    if (isDark) {
      return const _CompliancePalette(
        cardBg: Color(0xFF0F172A),
        surfaceAltBg: Color(0xFF1E293B),
        border: Color(0xFF475569),
        textPrimary: Color(0xFFF8FAFC),
        textSecondary: Color(0xFFE2E8F0),
        accentFg: Color(0xFF93C5FD),
        primaryBtnBg: Color(0xFFE0E7FF),
        primaryBtnFg: Color(0xFF1E1B4B),
        secondaryBtnFg: Color(0xFFE0E7FF),
        disabledBg: Color(0xFF334155),
        disabledFg: Color(0xFFE2E8F0),
        infoFg: Color(0xFFE0E7FF),
        infoBg: Color(0xFF1E1B4B),
        successFg: Color(0xFFD1FAE5),
        successBg: Color(0xFF022C22),
        warningFg: Color(0xFFFEF3C7),
        warningBg: Color(0xFF451A03),
        errorFg: Color(0xFFFEE2E2),
        errorBg: Color(0xFF450A0A),
        chipSelectedBg: Color(0xFFE0E7FF),
        chipSelectedFg: Color(0xFF1E1B4B),
        chipUnselectedBg: Color(0xFF1E293B),
        chipUnselectedFg: Color(0xFFF8FAFC),
      );
    }
    return const _CompliancePalette(
      cardBg: Color(0xFFFFFFFF),
      surfaceAltBg: Color(0xFFF8FAFC),
      border: Color(0xFFCBD5E1),
      textPrimary: Color(0xFF0F172A),
      textSecondary: Color(0xFF334155),
      accentFg: Color(0xFF1E3A8A),
      primaryBtnBg: Color(0xFF1E3A8A),
      primaryBtnFg: Color(0xFFFFFFFF),
      secondaryBtnFg: Color(0xFF1E3A8A),
      disabledBg: Color(0xFFE2E8F0),
      disabledFg: Color(0xFF334155),
      infoFg: Color(0xFF1E1B4B),
      infoBg: Color(0xFFEEF2FF),
      successFg: Color(0xFF064E3B),
      successBg: Color(0xFFECFDF5),
      warningFg: Color(0xFF78350F),
      warningBg: Color(0xFFFFFBEB),
      errorFg: Color(0xFF7F1D1D),
      errorBg: Color(0xFFFEF2F2),
      chipSelectedBg: Color(0xFF1E3A8A),
      chipSelectedFg: Color(0xFFFFFFFF),
      chipUnselectedBg: Color(0xFFF1F5F9),
      chipUnselectedFg: Color(0xFF0F172A),
    );
  }
}
