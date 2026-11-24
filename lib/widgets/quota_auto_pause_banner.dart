import 'package:flutter/material.dart';

import '../services/quota_pause_service.dart';

/// APIクォータ 80% 警告・100% 自動停止・管理者手動再開バナー (#2612)。
class QuotaAutoPauseBanner extends StatefulWidget {
  const QuotaAutoPauseBanner({
    super.key,
    this.repository,
    this.initialStates,
  });

  final QuotaPauseRepository? repository;
  final List<QuotaPauseStateItem>? initialStates;

  @override
  State<QuotaAutoPauseBanner> createState() => _QuotaAutoPauseBannerState();
}

class _QuotaAutoPauseBannerState extends State<QuotaAutoPauseBanner> {
  final TextEditingController _adminNoteController = TextEditingController();
  QuotaPauseRepository? _repo;
  List<QuotaPauseStateItem> _states = const <QuotaPauseStateItem>[];
  bool _loading = false;
  String? _errorMessage;
  String? _statusMessage;

  QuotaPauseRepository _resolveRepository() {
    return _repo ??= widget.repository ?? SupabaseQuotaPauseRepository();
  }

  @override
  void initState() {
    super.initState();
    _repo = widget.repository;
    final seeded = widget.initialStates;
    if (seeded != null) {
      _states = List<QuotaPauseStateItem>.unmodifiable(seeded);
    } else {
      _loadStates();
    }
  }

  @override
  void dispose() {
    _adminNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadStates() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final fetched = await _resolveRepository().listPauseStates();
      if (!mounted) return;
      setState(() {
        _states = List<QuotaPauseStateItem>.unmodifiable(fetched);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'クォータ停止状態の取得に失敗しました: $e';
      });
    }
  }

  Future<void> _resumeTool(QuotaPauseStateItem item) async {
    final note = _adminNoteController.text.trim();
    setState(() {
      _loading = true;
      _errorMessage = null;
      _statusMessage = null;
    });
    try {
      final updated = await _resolveRepository().resumeTool(
        tool: item.tool,
        adminNote: note,
      );
      if (!mounted) return;
      setState(() {
        _states = _states
            .map((entry) => entry.tool == updated.tool ? updated : entry)
            .toList(growable: false);
        _loading = false;
        _statusMessage = '${updated.tool} の自動停止を管理者確認の上で解除しました';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = '手動再開の反映に失敗しました: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = _QuotaPalette.fromBrightness(isDark);
    final summary = QuotaThresholdSummary.fromItems(_states);

    return Card(
      key: const ValueKey<String>('quota_auto_pause_banner'),
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
                Icon(Icons.shield_outlined, color: palette.accentFg),
                const SizedBox(width: 8),
                Flexible(
                  fit: FlexFit.tight,
                  child: Text(
                    'APIクォータ段階通知・自動停止ガード',
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
                    key: const ValueKey<String>('quota_pause_refresh_btn'),
                    tooltip: 'クォータ停止状態を再読込',
                    color: palette.textPrimary,
                    onPressed: _loading ? null : _loadStates,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '80%到達で事前警告通知を送信し、100%到達で新規AIリクエスト実行を自動停止・管理者Issue起票を行います。',
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
                  key: const ValueKey<String>('quota_kpi_normal'),
                  label: '正常',
                  value: '${summary.normalCount} 件',
                  fg: palette.successFg,
                  bg: palette.successBg,
                ),
                _buildKpiTile(
                  key: const ValueKey<String>('quota_kpi_warning80'),
                  label: '80% 警告',
                  value: '${summary.warning80Count} 件',
                  fg: palette.warningFg,
                  bg: palette.warningBg,
                ),
                _buildKpiTile(
                  key: const ValueKey<String>('quota_kpi_paused100'),
                  label: '100% 自動停止',
                  value: '${summary.paused100Count} 件',
                  fg: palette.errorFg,
                  bg: palette.errorBg,
                ),
                if (summary.silentPauseCount > 0)
                  _buildKpiTile(
                    key: const ValueKey<String>('quota_kpi_silent_pause'),
                    label: 'サイレント停止検知',
                    value: '${summary.silentPauseCount} 件',
                    fg: palette.errorFg,
                    bg: palette.errorBg,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('quota_admin_note_input'),
              controller: _adminNoteController,
              style: TextStyle(color: palette.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                labelText: '管理者再開メモ（上限引き上げ・課金リセット確認内容）',
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
                key: const ValueKey<String>('quota_pause_error_banner'),
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
                key: const ValueKey<String>('quota_pause_status_banner'),
                icon: Icons.check_circle_outline,
                message: _statusMessage!,
                fg: palette.successFg,
                bg: palette.successBg,
                border: palette.successFg,
              ),
            ],
            const SizedBox(height: 12),
            if (_states.isEmpty)
              Container(
                key: const ValueKey<String>('quota_pause_empty_state'),
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: palette.surfaceAltBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  'クォータ停止状態データはまだありません。',
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
                children: _states
                    .map((item) => _buildToolCard(item, palette))
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

  Widget _buildToolCard(
    QuotaPauseStateItem item,
    _QuotaPalette palette,
  ) {
    final ({Color fg, Color bg, IconData icon}) style = switch (item.tier) {
      QuotaThresholdTier.paused100 => (
          fg: palette.errorFg,
          bg: palette.errorBg,
          icon: Icons.pause_circle_filled,
        ),
      QuotaThresholdTier.warning80 => (
          fg: palette.warningFg,
          bg: palette.warningBg,
          icon: Icons.warning_amber_rounded,
        ),
      QuotaThresholdTier.normal => (
          fg: palette.successFg,
          bg: palette.successBg,
          icon: Icons.check_circle_outline,
        ),
    };

    return Container(
      key: ValueKey<String>('quota_tool_item_${item.tool}'),
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
            children: <Widget>[
              Icon(style.icon, size: 18, color: style.fg),
              const SizedBox(width: 8),
              Flexible(
                fit: FlexFit.tight,
                child: Text(
                  '${item.tool} (${item.usagePct.toStringAsFixed(1)}%)',
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: style.bg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.tier.label,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: style.fg,
                  ),
                ),
              ),
            ],
          ),
          if (item.silentPauseDetected) ...<Widget>[
            const SizedBox(height: 8),
            _buildBanner(
              key: ValueKey<String>('quota_silent_pause_${item.tool}'),
              icon: Icons.sync_problem_outlined,
              message: 'サイレント停止不整合を検知: 利用率100%超にも関わらず上流停止状態が未反映でした。',
              fg: palette.errorFg,
              bg: palette.errorBg,
              border: palette.errorFg,
            ),
          ],
          if (item.adminIssueNumber != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              '起票済み管理者Issue: #${item.adminIssueNumber}',
              softWrap: true,
              style: TextStyle(
                fontSize: 12,
                color: palette.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          if (item.adminNote.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              '管理者メモ: ${item.adminNote}',
              softWrap: true,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
                height: 1.4,
              ),
            ),
          ],
          if (item.isEffectivePaused) ...<Widget>[
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: ElevatedButton.icon(
                key: ValueKey<String>('quota_resume_btn_${item.tool}'),
                onPressed: _loading ? null : () => _resumeTool(item),
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
                icon: const Icon(Icons.play_arrow_outlined, size: 18),
                label: const Text('管理者確認の上で再開'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuotaPalette {
  const _QuotaPalette({
    required this.cardBg,
    required this.surfaceAltBg,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.accentFg,
    required this.primaryBtnBg,
    required this.primaryBtnFg,
    required this.disabledBg,
    required this.disabledFg,
    required this.successFg,
    required this.successBg,
    required this.warningFg,
    required this.warningBg,
    required this.errorFg,
    required this.errorBg,
  });

  final Color cardBg;
  final Color surfaceAltBg;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color accentFg;
  final Color primaryBtnBg;
  final Color primaryBtnFg;
  final Color disabledBg;
  final Color disabledFg;
  final Color successFg;
  final Color successBg;
  final Color warningFg;
  final Color warningBg;
  final Color errorFg;
  final Color errorBg;

  factory _QuotaPalette.fromBrightness(bool isDark) {
    if (isDark) {
      return const _QuotaPalette(
        cardBg: Color(0xFF0F172A),
        surfaceAltBg: Color(0xFF1E293B),
        border: Color(0xFF475569),
        textPrimary: Color(0xFFF8FAFC),
        textSecondary: Color(0xFFE2E8F0),
        accentFg: Color(0xFF93C5FD),
        primaryBtnBg: Color(0xFFE0E7FF),
        primaryBtnFg: Color(0xFF1E1B4B),
        disabledBg: Color(0xFF334155),
        disabledFg: Color(0xFFE2E8F0),
        successFg: Color(0xFFD1FAE5),
        successBg: Color(0xFF022C22),
        warningFg: Color(0xFFFEF3C7),
        warningBg: Color(0xFF451A03),
        errorFg: Color(0xFFFEE2E2),
        errorBg: Color(0xFF450A0A),
      );
    }
    return const _QuotaPalette(
      cardBg: Color(0xFFFFFFFF),
      surfaceAltBg: Color(0xFFF8FAFC),
      border: Color(0xFFCBD5E1),
      textPrimary: Color(0xFF0F172A),
      textSecondary: Color(0xFF334155),
      accentFg: Color(0xFF1E3A8A),
      primaryBtnBg: Color(0xFF1E3A8A),
      primaryBtnFg: Color(0xFFFFFFFF),
      disabledBg: Color(0xFFE2E8F0),
      disabledFg: Color(0xFF334155),
      successFg: Color(0xFF064E3B),
      successBg: Color(0xFFECFDF5),
      warningFg: Color(0xFF78350F),
      warningBg: Color(0xFFFFFBEB),
      errorFg: Color(0xFF7F1D1D),
      errorBg: Color(0xFFFEF2F2),
    );
  }
}
