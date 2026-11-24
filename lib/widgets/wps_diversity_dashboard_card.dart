import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/wps_diversity_knowledge_service.dart';

/// WPS・ダイバーシティ方針のタグ統計・アクセスリンク・管理者レビューUI (#2585)。
class WpsDiversityDashboardCard extends StatefulWidget {
  const WpsDiversityDashboardCard({
    super.key,
    this.repository,
    this.initialPolicies,
    this.onOpenReferenceUrl,
  });

  final WpsDiversityKnowledgeRepository? repository;
  final List<WpsDiversityPolicyItem>? initialPolicies;
  final Future<bool> Function(Uri uri)? onOpenReferenceUrl;

  @override
  State<WpsDiversityDashboardCard> createState() =>
      _WpsDiversityDashboardCardState();
}

class _WpsDiversityDashboardCardState extends State<WpsDiversityDashboardCard> {
  final TextEditingController _reviewNoteController = TextEditingController();
  WpsDiversityKnowledgeRepository? _repo;
  List<WpsDiversityPolicyItem> _items = const <WpsDiversityPolicyItem>[];
  String _selectedFilter = 'all';
  bool _loading = false;
  String? _errorMessage;
  String? _statusMessage;

  WpsDiversityKnowledgeRepository _resolveRepository() {
    return _repo ??=
        widget.repository ?? SupabaseWpsDiversityKnowledgeRepository();
  }

  @override
  void initState() {
    super.initState();
    _repo = widget.repository;
    final seeded = widget.initialPolicies;
    if (seeded != null) {
      _items = List<WpsDiversityPolicyItem>.unmodifiable(seeded);
    } else {
      _loadPolicies();
    }
  }

  @override
  void dispose() {
    _reviewNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadPolicies() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final fetched = await _resolveRepository().listPolicies(limit: 50);
      if (!mounted) return;
      setState(() {
        _items = List<WpsDiversityPolicyItem>.unmodifiable(fetched);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'WPS・ダイバーシティ方針一覧の取得に失敗しました: $e';
      });
    }
  }

  Future<void> _applyReview(
    WpsDiversityPolicyItem item,
    WpsPolicyReviewStatus status,
  ) async {
    final noteText = _reviewNoteController.text.trim();
    setState(() {
      _loading = true;
      _errorMessage = null;
      _statusMessage = null;
    });
    try {
      final updated = await _resolveRepository().updateReview(
        id: item.id,
        status: status,
        reviewNote: noteText,
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
        _errorMessage = '管理者レビューの更新に失敗しました: $e';
      });
    }
  }

  Future<void> _openReferenceLink(String rawUrl) async {
    final safe = WpsDiversityKnowledgeTagger.sanitizeReferenceUrl(rawUrl);
    if (safe.isEmpty) {
      setState(() {
        _errorMessage = '許可されていない参照URLスキームです';
      });
      return;
    }
    final uri = Uri.parse(safe);
    try {
      final opener = widget.onOpenReferenceUrl;
      final ok = opener != null
          ? await opener(uri)
          : await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _errorMessage = '参照URLを開けませんでした: $safe';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '参照URLの起動に失敗しました: $e';
      });
    }
  }

  List<WpsDiversityPolicyItem> _filteredItems() {
    switch (_selectedFilter) {
      case 'pending_review':
        return _items
            .where(
              (item) =>
                  item.reviewStatus == WpsPolicyReviewStatus.pendingReview,
            )
            .toList(growable: false);
      case 'all':
        return _items;
      default:
        return _items
            .where((item) => item.policyTags.contains(_selectedFilter))
            .toList(growable: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = _WpsPalette.fromBrightness(isDark);
    final stats = WpsKnowledgeStats.fromItems(_items);
    final visible = _filteredItems();

    return Card(
      key: const ValueKey<String>('wps_diversity_dashboard_card'),
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
                Icon(Icons.diversity_3_outlined, color: palette.accentFg),
                const SizedBox(width: 8),
                Flexible(
                  fit: FlexFit.tight,
                  child: Text(
                    'WPS・ダイバーシティ方針 ナレッジ可視化 (${stats.totalCount}件)',
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
                    key: const ValueKey<String>('wps_refresh_btn'),
                    tooltip: 'WPS方針一覧を再読込',
                    color: palette.textPrimary,
                    onPressed: _loading ? null : _loadPolicies,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'UNSCR 1325・第3次WPS行動計画・ダイバーシティ/ジェンダー方針の自動タグ統計、公式参照リンク、管理者レビュー状態を管理します。',
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
              children: <Widget>[
                _buildKpiTile(
                  key: const ValueKey<String>('wps_kpi_total'),
                  label: '登録方針',
                  value: '${stats.totalCount} 件',
                  fg: palette.infoFg,
                  bg: palette.infoBg,
                ),
                _buildKpiTile(
                  key: const ValueKey<String>('wps_kpi_pending'),
                  label: 'レビュー待ち',
                  value: '${stats.pendingReviewCount} 件',
                  fg: palette.warningFg,
                  bg: palette.warningBg,
                ),
                _buildKpiTile(
                  key: const ValueKey<String>('wps_kpi_approved'),
                  label: '承認済み',
                  value: '${stats.approvedCount} 件',
                  fg: palette.successFg,
                  bg: palette.successBg,
                ),
                _buildKpiTile(
                  key: const ValueKey<String>('wps_kpi_wps_tag'),
                  label: 'WPSタグ',
                  value: '${stats.tagCounts['WPS'] ?? 0} 件',
                  fg: palette.infoFg,
                  bg: palette.surfaceAltBg,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <({String key, String label})>[
                (key: 'all', label: 'すべて (${stats.totalCount})'),
                (
                  key: 'pending_review',
                  label: 'レビュー待ち (${stats.pendingReviewCount})',
                ),
                (key: 'WPS', label: 'WPS (${stats.tagCounts['WPS'] ?? 0})'),
                (
                  key: 'ダイバーシティ',
                  label: 'ダイバーシティ (${stats.tagCounts['ダイバーシティ'] ?? 0})',
                ),
                (
                  key: 'ジェンダー',
                  label: 'ジェンダー (${stats.tagCounts['ジェンダー'] ?? 0})',
                ),
              ].map((entry) {
                final filterKey = entry.key;
                final label = entry.label;
                final selected = _selectedFilter == filterKey;
                return ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: ChoiceChip(
                    key: ValueKey<String>('wps_filter_chip_$filterKey'),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    selected: selected,
                    backgroundColor: palette.chipUnselectedBg,
                    selectedColor: palette.chipSelectedBg,
                    checkmarkColor: palette.chipSelectedFg,
                    side: BorderSide(color: palette.border),
                    labelStyle: TextStyle(
                      color: selected
                          ? palette.chipSelectedFg
                          : palette.chipUnselectedFg,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedFilter = filterKey;
                      });
                    },
                    label: Text(label),
                  ),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('wps_review_note_input'),
              controller: _reviewNoteController,
              style: TextStyle(color: palette.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                labelText: '管理者レビューメモ（承認・修正依頼時に保存）',
                labelStyle: TextStyle(color: palette.textSecondary),
                filled: true,
                fillColor: palette.surfaceAltBg,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: palette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: palette.accentFg, width: 2),
                ),
              ),
            ),
            if (_loading) ...<Widget>[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              _buildBanner(
                key: const ValueKey<String>('wps_error_banner'),
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
                key: const ValueKey<String>('wps_status_banner'),
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
                key: const ValueKey<String>('wps_empty_state'),
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: palette.surfaceAltBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  '表示対象のWPS・ダイバーシティ方針ドキュメントはまだありません。',
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
                    .map((item) => _buildPolicyCard(item, palette))
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiTile({
    required Key key,
    required String label,
    required String value,
    required Color fg,
    required Color bg,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            softWrap: true,
            style: TextStyle(
              fontSize: 12,
              color: fg,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            softWrap: true,
            style: TextStyle(
              fontSize: 16,
              color: fg,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
        ],
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

  Widget _buildPolicyCard(
    WpsDiversityPolicyItem item,
    _WpsPalette palette,
  ) {
    final ({Color fg, Color bg, IconData icon}) statusStyle =
        switch (item.reviewStatus) {
      WpsPolicyReviewStatus.approved => (
          fg: palette.successFg,
          bg: palette.successBg,
          icon: Icons.verified_outlined,
        ),
      WpsPolicyReviewStatus.needsRevision => (
          fg: palette.errorFg,
          bg: palette.errorBg,
          icon: Icons.edit_note_outlined,
        ),
      WpsPolicyReviewStatus.pendingReview => (
          fg: palette.warningFg,
          bg: palette.warningBg,
          icon: Icons.pending_actions_outlined,
        ),
    };

    return Container(
      key: ValueKey<String>('wps_policy_item_${item.id}'),
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
              color: statusStyle.bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(statusStyle.icon, size: 16, color: statusStyle.fg),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${item.reviewStatus.label} (${item.primaryTopic.label} / 信頼度 ${item.confidenceScore})',
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusStyle.fg,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (item.summary.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              item.summary,
              softWrap: true,
              style: TextStyle(
                fontSize: 12,
                color: palette.textSecondary,
                height: 1.5,
              ),
            ),
          ],
          if (item.policyTags.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: item.policyTags
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: palette.chipUnselectedBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: palette.border),
                      ),
                      child: Text(
                        tag,
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: palette.chipUnselectedFg,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (item.frameworkReferences.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              '参照枠組み: ${item.frameworkReferences.join(' / ')}',
              softWrap: true,
              style: TextStyle(
                fontSize: 11,
                color: palette.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          if (item.reviewNote.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'レビュー記録: ${item.reviewNote}',
              softWrap: true,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (item.hasSafeReferenceUrl)
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: OutlinedButton.icon(
                    key: ValueKey<String>('wps_open_link_${item.id}'),
                    onPressed: () => _openReferenceLink(item.referenceUrl),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: palette.cardBg,
                      foregroundColor: palette.secondaryBtnFg,
                      side: BorderSide(color: palette.secondaryBtnFg),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('公式情報リンク'),
                  ),
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: ElevatedButton.icon(
                  key: ValueKey<String>('wps_approve_${item.id}'),
                  onPressed: _loading
                      ? null
                      : () => _applyReview(
                            item,
                            WpsPolicyReviewStatus.approved,
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
                  label: const Text('承認'),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: OutlinedButton.icon(
                  key: ValueKey<String>('wps_revise_${item.id}'),
                  onPressed: _loading
                      ? null
                      : () => _applyReview(
                            item,
                            WpsPolicyReviewStatus.needsRevision,
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
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('修正依頼'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WpsPalette {
  const _WpsPalette({
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

  factory _WpsPalette.fromBrightness(bool isDark) {
    if (isDark) {
      return const _WpsPalette(
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
    return const _WpsPalette(
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
