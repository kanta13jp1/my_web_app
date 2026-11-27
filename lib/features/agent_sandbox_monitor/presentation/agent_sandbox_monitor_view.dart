import 'package:flutter/material.dart';

import '../application/agent_sandbox_controller.dart';
import '../domain/agent_sandbox_models.dart';

/// エージェント隔離サンドボックス・事前監視・最小特権監査ビュー (#2722)。
class AgentSandboxMonitorView extends StatefulWidget {
  const AgentSandboxMonitorView({
    super.key,
    required this.controller,
  });

  final AgentSandboxController controller;

  @override
  State<AgentSandboxMonitorView> createState() =>
      _AgentSandboxMonitorViewState();
}

class _AgentSandboxMonitorViewState extends State<AgentSandboxMonitorView> {
  final TextEditingController _toolNameController =
      TextEditingController(text: 'sandbox.text_metrics');
  final TextEditingController _payloadTextController =
      TextEditingController(text: 'Isolated worker verification sample');
  final TextEditingController _retryCountController =
      TextEditingController(text: '0');

  String _selectedRole = 'generated_ui_sandbox';
  String _selectedScope = 'read';

  @override
  void dispose() {
    _toolNameController.dispose();
    _payloadTextController.dispose();
    _retryCountController.dispose();
    super.dispose();
  }

  Future<void> _handleExecuteIsolated() async {
    final int retries = int.tryParse(_retryCountController.text.trim()) ?? 0;
    final String text = _payloadTextController.text;
    await widget.controller.runPreflightAndExecute(
      toolName: _toolNameController.text,
      actorRole: _selectedRole,
      requestedScopes: <String>[_selectedScope],
      toolArgs: <String, Object?>{'text': text},
      retryAttempt: retries,
      promptText: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final _SandboxPalette palette = _SandboxPalette.fromBrightness(
      Theme.of(context).brightness,
    );

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final List<AgentSandboxAuditEntry> filtered =
            widget.controller.filteredAudits;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: palette.panelSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildHeader(palette),
                const SizedBox(height: 12),
                _buildBoundaryBadges(palette),
                const SizedBox(height: 12),
                _buildSummaryMetrics(palette),
                if (widget.controller.statusMessage.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  _buildBanner(
                    key: const ValueKey<String>('sandbox-status-banner'),
                    text: widget.controller.statusMessage,
                    bg: palette.okBg,
                    fg: palette.okFg,
                    border: palette.okBorder,
                  ),
                ],
                if (widget.controller.errorMessage.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  _buildBanner(
                    key: const ValueKey<String>('sandbox-error-banner'),
                    text: widget.controller.errorMessage,
                    bg: palette.dangerBg,
                    fg: palette.dangerFg,
                    border: palette.dangerBorder,
                  ),
                ],
                const SizedBox(height: 14),
                _buildPreflightForm(palette),
                const SizedBox(height: 14),
                _buildAuditFilters(palette),
                const SizedBox(height: 12),
                _buildAuditList(palette, filtered),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(_SandboxPalette palette) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Icon(Icons.security_outlined, color: palette.primaryText),
        Text(
          'エージェント隔離サンドボックス・セキュリティ監視',
          softWrap: true,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        _buildBadge(
          label: 'RLS + Fail-Closed',
          bg: palette.infoBg,
          fg: palette.infoFg,
          border: palette.infoBorder,
        ),
      ],
    );
  }

  Widget _buildBoundaryBadges(_SandboxPalette palette) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _buildBadge(
          label: 'ホストFS: 遮断固定',
          bg: palette.okBg,
          fg: palette.okFg,
          border: palette.okBorder,
        ),
        _buildBadge(
          label: '本番DB直接接続: 遮断固定',
          bg: palette.okBg,
          fg: palette.okFg,
          border: palette.okBorder,
        ),
        _buildBadge(
          label: '外部ネットワーク: deny-all',
          bg: palette.warnBg,
          fg: palette.warnFg,
          border: palette.warnBorder,
        ),
      ],
    );
  }

  Widget _buildSummaryMetrics(_SandboxPalette palette) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        _buildMetricCard(
          key: const ValueKey<String>('sandbox-metric-total'),
          label: '監査総数',
          value: '${widget.controller.audits.length} 件',
          palette: palette,
        ),
        _buildMetricCard(
          key: const ValueKey<String>('sandbox-metric-blocked'),
          label: '事前ブロック',
          value: '${widget.controller.blockedCount} 件',
          palette: palette,
        ),
        _buildMetricCard(
          key: const ValueKey<String>('sandbox-metric-injection'),
          label: 'インジェクション',
          value: '${widget.controller.injectionCount} 件',
          palette: palette,
        ),
        _buildMetricCard(
          key: const ValueKey<String>('sandbox-metric-anomaly'),
          label: '異常リトライ/引数',
          value: '${widget.controller.anomalyCount} 件',
          palette: palette,
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required Key key,
    required String label,
    required String value,
    required _SandboxPalette palette,
  }) {
    return DecoratedBox(
      key: key,
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              softWrap: true,
              style: TextStyle(
                color: palette.secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              softWrap: true,
              style: TextStyle(
                color: palette.primaryText,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner({
    required Key key,
    required String text,
    required Color bg,
    required Color fg,
    required Color border,
  }) {
    return DecoratedBox(
      key: key,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(
          text,
          softWrap: true,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required _SandboxPalette palette,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: palette.secondaryText),
      hintStyle: TextStyle(color: palette.secondaryText),
      filled: true,
      fillColor: palette.panelSurface,
      border: OutlineInputBorder(
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: palette.primaryBtnBg, width: 2),
      ),
    );
  }

  Widget _buildSelectableBtn({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onPressed,
    required _SandboxPalette palette,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: OutlinedButton(
        key: key,
        style: OutlinedButton.styleFrom(
          foregroundColor:
              selected ? palette.primaryBtnFg : palette.primaryText,
          backgroundColor:
              selected ? palette.primaryBtnBg : palette.panelSurface,
          side: BorderSide(
            color: selected ? palette.primaryBtnBg : palette.border,
          ),
        ),
        onPressed: onPressed,
        child: Text(label, softWrap: true),
      ),
    );
  }

  Widget _buildPreflightForm(_SandboxPalette palette) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '隔離サンドボックス 事前検証・実行ガード',
              softWrap: true,
              style: TextStyle(
                color: palette.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final String role in const <String>[
                  'generated_ui_sandbox',
                  'cfo',
                  'ceo',
                ])
                  _buildSelectableBtn(
                    key: ValueKey<String>('sandbox-role-$role'),
                    label: role,
                    selected: _selectedRole == role,
                    onPressed: () {
                      setState(() {
                        _selectedRole = role;
                      });
                    },
                    palette: palette,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final String scope in const <String>[
                  'read',
                  'create',
                  'delete',
                ])
                  _buildSelectableBtn(
                    key: ValueKey<String>('sandbox-scope-$scope'),
                    label: 'scope:$scope',
                    selected: _selectedScope == scope,
                    onPressed: () {
                      setState(() {
                        _selectedScope = scope;
                      });
                    },
                    palette: palette,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('sandbox-tool-field'),
              controller: _toolNameController,
              style: TextStyle(color: palette.primaryText),
              decoration: _inputDecoration(
                label: 'ツール名',
                hint: 'sandbox.text_metrics / sandbox.json_validate',
                palette: palette,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('sandbox-payload-field'),
              controller: _payloadTextController,
              style: TextStyle(color: palette.primaryText),
              decoration: _inputDecoration(
                label: '実行引数・プロンプトペイロード',
                hint: '/etc/passwd や DROP TABLE 等の禁止入力を事前遮断',
                palette: palette,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('sandbox-retry-field'),
              controller: _retryCountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: palette.primaryText),
              decoration: _inputDecoration(
                label: 'リトライ回数 (上限 3)',
                hint: '0..3 許可 / 4 以上は異常リトライで遮断',
                palette: palette,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: ElevatedButton(
                key: const ValueKey<String>('sandbox-execute-button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primaryBtnBg,
                  foregroundColor: palette.primaryBtnFg,
                ),
                onPressed:
                    widget.controller.isBusy ? null : _handleExecuteIsolated,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.shield_outlined),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '事前監視＆隔離実行',
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
    );
  }

  Widget _buildAuditFilters(_SandboxPalette palette) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final MapEntry<String, String> item
            in const <MapEntry<String, String>>[
          MapEntry<String, String>('all', 'すべて'),
          MapEntry<String, String>('blocked', 'ブロックのみ'),
          MapEntry<String, String>('allowed', '許可のみ'),
        ])
          _buildSelectableBtn(
            key: ValueKey<String>('sandbox-filter-${item.key}'),
            label: item.value,
            selected: widget.controller.decisionFilter == item.key,
            onPressed: () => widget.controller.setDecisionFilter(item.key),
            palette: palette,
          ),
      ],
    );
  }

  Widget _buildAuditList(
    _SandboxPalette palette,
    List<AgentSandboxAuditEntry> audits,
  ) {
    if (audits.isEmpty) {
      return DecoratedBox(
        key: const ValueKey<String>('sandbox-empty-state'),
        decoration: BoxDecoration(
          color: palette.cardSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            '監査レコードはまだありません。',
            softWrap: true,
            style: TextStyle(color: palette.secondaryText),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final AgentSandboxAuditEntry entry in audits) ...<Widget>[
          _buildAuditCard(palette, entry),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildAuditCard(
    _SandboxPalette palette,
    AgentSandboxAuditEntry entry,
  ) {
    final bool blocked = entry.isBlocked;
    return DecoratedBox(
      key: ValueKey<String>('sandbox-audit-card-${entry.id}'),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  entry.toolName,
                  softWrap: true,
                  style: TextStyle(
                    color: palette.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _buildBadge(
                  label: entry.blockedCategory.labelJa,
                  bg: blocked ? palette.dangerBg : palette.okBg,
                  fg: blocked ? palette.dangerFg : palette.okFg,
                  border: blocked ? palette.dangerBorder : palette.okBorder,
                ),
                _buildBadge(
                  label: 'role:${entry.actorRole}',
                  bg: palette.infoBg,
                  fg: palette.infoFg,
                  border: palette.infoBorder,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'sandbox=${entry.sandboxId} | retries=${entry.retryAttempt} '
              '| latency=${entry.latencyMs}ms',
              softWrap: true,
              style: TextStyle(
                color: palette.secondaryText,
                fontSize: 12,
              ),
            ),
            if (entry.blockedReason.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                '遮断理由: ${entry.blockedReason}',
                softWrap: true,
                style: TextStyle(color: palette.dangerFg, fontSize: 12),
              ),
            ],
            if (entry.errorTrace.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                entry.errorTrace,
                softWrap: true,
                style: TextStyle(color: palette.secondaryText, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required Color bg,
    required Color fg,
    required Color border,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          softWrap: true,
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SandboxPalette {
  const _SandboxPalette({
    required this.panelSurface,
    required this.cardSurface,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
    required this.infoBg,
    required this.infoFg,
    required this.infoBorder,
    required this.okBg,
    required this.okFg,
    required this.okBorder,
    required this.warnBg,
    required this.warnFg,
    required this.warnBorder,
    required this.dangerBg,
    required this.dangerFg,
    required this.dangerBorder,
    required this.primaryBtnBg,
    required this.primaryBtnFg,
  });

  final Color panelSurface;
  final Color cardSurface;
  final Color border;
  final Color primaryText;
  final Color secondaryText;
  final Color infoBg;
  final Color infoFg;
  final Color infoBorder;
  final Color okBg;
  final Color okFg;
  final Color okBorder;
  final Color warnBg;
  final Color warnFg;
  final Color warnBorder;
  final Color dangerBg;
  final Color dangerFg;
  final Color dangerBorder;
  final Color primaryBtnBg;
  final Color primaryBtnFg;

  static _SandboxPalette fromBrightness(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const _SandboxPalette(
        panelSurface: Color(0xFF090D16),
        cardSurface: Color(0xFF111827),
        border: Color(0xFFCBD5E1),
        primaryText: Color(0xFFF8FAFC),
        secondaryText: Color(0xFFE2E8F0),
        infoBg: Color(0xFF1E3A8A),
        infoFg: Color(0xFFDBEAFE),
        infoBorder: Color(0xFF93C5FD),
        okBg: Color(0xFF064E3B),
        okFg: Color(0xFFECFDF5),
        okBorder: Color(0xFF6EE7B7),
        warnBg: Color(0xFF78350F),
        warnFg: Color(0xFFFEF3C7),
        warnBorder: Color(0xFFFCD34D),
        dangerBg: Color(0xFF7F1D1D),
        dangerFg: Color(0xFFFEE2E2),
        dangerBorder: Color(0xFFFCA5A5),
        primaryBtnBg: Color(0xFF93C5FD),
        primaryBtnFg: Color(0xFF090D16),
      );
    }
    return const _SandboxPalette(
      panelSurface: Color(0xFFFFFFFF),
      cardSurface: Color(0xFFF8FAFC),
      border: Color(0xFF475569),
      primaryText: Color(0xFF0F172A),
      secondaryText: Color(0xFF1E293B),
      infoBg: Color(0xFFDBEAFE),
      infoFg: Color(0xFF1E3A8A),
      infoBorder: Color(0xFF1E40AF),
      okBg: Color(0xFFDCFCE7),
      okFg: Color(0xFF14532D),
      okBorder: Color(0xFF15803D),
      warnBg: Color(0xFFFEF3C7),
      warnFg: Color(0xFF78350F),
      warnBorder: Color(0xFFB45309),
      dangerBg: Color(0xFFFEE2E2),
      dangerFg: Color(0xFF7F1D1D),
      dangerBorder: Color(0xFFB91C1C),
      primaryBtnBg: Color(0xFF1E3A8A),
      primaryBtnFg: Color(0xFFFFFFFF),
    );
  }
}
