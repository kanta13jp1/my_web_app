import 'package:flutter/material.dart';

import '../application/architectural_safety_checkpoint_controller.dart';
import '../domain/architectural_safety_checkpoint_models.dart';

/// Architectural Safety Checkpoints の管理・承認 UI (#2712)。
class ArchitecturalSafetyCheckpointView extends StatefulWidget {
  const ArchitecturalSafetyCheckpointView({
    super.key,
    required this.controller,
  });

  final ArchitecturalSafetyCheckpointController controller;

  @override
  State<ArchitecturalSafetyCheckpointView> createState() =>
      _ArchitecturalSafetyCheckpointViewState();
}

class _ArchitecturalSafetyCheckpointViewState
    extends State<ArchitecturalSafetyCheckpointView> {
  final TextEditingController _toolNameController = TextEditingController();
  final TextEditingController _scopesController = TextEditingController(
    text: 'delete',
  );
  final TextEditingController _runKeyController = TextEditingController();
  final TextEditingController _issueController = TextEditingController();

  @override
  void dispose() {
    _toolNameController.dispose();
    _scopesController.dispose();
    _runKeyController.dispose();
    _issueController.dispose();
    super.dispose();
  }

  Future<void> _handleEvaluate() async {
    final List<String> scopes = _scopesController.text
        .split(RegExp(r'[,\s]+'))
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
    final int? issueNum = int.tryParse(_issueController.text.trim());
    await widget.controller.evaluateToolCall(
      toolName: _toolNameController.text,
      requestedScopes: scopes.isEmpty ? const <String>['read'] : scopes,
      runKey: _runKeyController.text,
      githubIssueNumber: issueNum,
    );
  }

  int? _resolveIssueNumber(SafetyCheckpointRecord record) {
    final int? parsed = int.tryParse(_issueController.text.trim());
    return parsed ?? record.githubIssueNumber;
  }

  @override
  Widget build(BuildContext context) {
    final _SafetyPalette palette = _SafetyPalette.fromBrightness(
      Theme.of(context).brightness,
    );
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final List<SafetyCheckpointRecord> records = widget.controller.records;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: palette.panelSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildHeader(palette),
                const SizedBox(height: 12),
                if (widget.controller.errorMessage.isNotEmpty) ...<Widget>[
                  _buildBanner(
                    key: const ValueKey<String>('safety-error-banner'),
                    text: widget.controller.errorMessage,
                    bg: palette.dangerBg,
                    fg: palette.dangerFg,
                    border: palette.dangerBorder,
                  ),
                  const SizedBox(height: 10),
                ],
                if (widget.controller.statusMessage.isNotEmpty) ...<Widget>[
                  _buildBanner(
                    key: const ValueKey<String>('safety-status-banner'),
                    text: widget.controller.statusMessage,
                    bg: palette.infoBg,
                    fg: palette.infoFg,
                    border: palette.infoBorder,
                  ),
                  const SizedBox(height: 10),
                ],
                _buildEvaluateForm(palette),
                const SizedBox(height: 14),
                _buildRecordsSection(palette, records),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(_SafetyPalette palette) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Architectural Safety Checkpoints (事前承認ゲート)',
              style: TextStyle(
                color: palette.primaryText,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'システム影響のある MCP ツール実行を事前に無欠損停止し、管理者の指定UIまたは GitHub Issue 承認でのみ後続処理を再開します。',
              softWrap: true,
              style: TextStyle(color: palette.secondaryText),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                _buildBadge(
                  label: '承認待ち: ${widget.controller.awaitingApprovalCount} 件',
                  bg: widget.controller.awaitingApprovalCount > 0
                      ? palette.warnBg
                      : palette.okBg,
                  fg: widget.controller.awaitingApprovalCount > 0
                      ? palette.warnFg
                      : palette.okFg,
                  border: widget.controller.awaitingApprovalCount > 0
                      ? palette.warnBorder
                      : palette.okBorder,
                ),
                _buildBadge(
                  label: '再開済み: ${widget.controller.resumedCount} 件',
                  bg: palette.okBg,
                  fg: palette.okFg,
                  border: palette.okBorder,
                ),
                _buildBadge(
                  label: '拒否・停止: ${widget.controller.rejectedCount} 件',
                  bg: palette.dangerBg,
                  fg: palette.dangerFg,
                  border: palette.dangerBorder,
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: OutlinedButton(
                    key: const ValueKey<String>('safety-refresh-button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.primaryText,
                      backgroundColor: palette.panelSurface,
                      side: BorderSide(color: palette.border),
                    ),
                    onPressed: widget.controller.isBusy
                        ? null
                        : widget.controller.loadCheckpoints,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.refresh),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '再読込',
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner({
    Key? key,
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

  Widget _buildEvaluateForm(_SafetyPalette palette) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'MCP ツール実行前チェック',
              style: TextStyle(
                color: palette.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const ValueKey<String>('safety-tool-name-field'),
              controller: _toolNameController,
              style: TextStyle(color: palette.primaryText),
              decoration: _inputDecoration(
                palette,
                label: 'MCP ツール名',
                hint: '例: db.prune_stale_records / deploy.edge_function',
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const ValueKey<String>('safety-scopes-field'),
              controller: _scopesController,
              style: TextStyle(color: palette.primaryText),
              decoration: _inputDecoration(
                palette,
                label: '要求スコープ',
                hint: 'read, update, delete, send など',
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const ValueKey<String>('safety-run-key-field'),
              controller: _runKeyController,
              style: TextStyle(color: palette.primaryText),
              decoration: _inputDecoration(
                palette,
                label: 'Runキー',
                hint: '例: mcp-db-cleanup-01',
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const ValueKey<String>('safety-issue-number-field'),
              controller: _issueController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: palette.primaryText),
              decoration: _inputDecoration(
                palette,
                label: '連携 GitHub Issue 番号 (任意)',
                hint: '例: 2712',
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
                child: ElevatedButton(
                  key: const ValueKey<String>('safety-evaluate-button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primaryBtnBg,
                    foregroundColor: palette.primaryBtnFg,
                  ),
                  onPressed: widget.controller.isBusy ? null : _handleEvaluate,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.shield_outlined),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '実行前リスク判定・停止',
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    _SafetyPalette palette, {
    required String label,
    required String hint,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: palette.panelSurface,
      labelText: label,
      labelStyle: TextStyle(color: palette.secondaryText),
      hintText: hint,
      hintMaxLines: 2,
      hintStyle: TextStyle(color: palette.secondaryText),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: palette.infoBorder, width: 2),
      ),
    );
  }

  Widget _buildRecordsSection(
    _SafetyPalette palette,
    List<SafetyCheckpointRecord> records,
  ) {
    if (records.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: palette.cardSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            '停止中の安全チェックポイントはありません。',
            softWrap: true,
            style: TextStyle(color: palette.secondaryText),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: records.map((SafetyCheckpointRecord record) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildRecordCard(palette, record),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildRecordCard(
    _SafetyPalette palette,
    SafetyCheckpointRecord record,
  ) {
    final Color statusBg = record.isRejected
        ? palette.dangerBg
        : (record.isAwaitingApproval ? palette.warnBg : palette.okBg);
    final Color statusFg = record.isRejected
        ? palette.dangerFg
        : (record.isAwaitingApproval ? palette.warnFg : palette.okFg);
    final Color statusBorder = record.isRejected
        ? palette.dangerBorder
        : (record.isAwaitingApproval ? palette.warnBorder : palette.okBorder);

    return DecoratedBox(
      key: ValueKey<String>('safety-card-${record.runKey}'),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  '${record.toolName} (${record.runKey})',
                  softWrap: true,
                  style: TextStyle(
                    color: palette.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _buildBadge(
                  label: record.pauseStatus.labelJa,
                  bg: statusBg,
                  fg: statusFg,
                  border: statusBorder,
                ),
                if (record.approvalChannel != null)
                  _buildBadge(
                    label: record.approvalChannel!.labelJa,
                    bg: palette.infoBg,
                    fg: palette.infoFg,
                    border: palette.infoBorder,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Agent: ${record.agentName} | スコープ: ${record.requestedScopes.join(', ')}'
              '${record.githubIssueNumber != null ? ' | Issue #${record.githubIssueNumber}' : ''}',
              softWrap: true,
              style: TextStyle(color: palette.secondaryText),
            ),
            if (record.snapshotSha256.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                'Snapshot SHA: ${record.snapshotSha256}',
                softWrap: true,
                style: TextStyle(color: palette.secondaryText, fontSize: 12),
              ),
            ],
            if (record.isAwaitingApproval) ...<Widget>[
              const SizedBox(height: 10),
              if (widget.controller.canApproveAsAdmin)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: ElevatedButton(
                        key: ValueKey<String>(
                          'safety-approve-ui-${record.runKey}',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.primaryBtnBg,
                          foregroundColor: palette.primaryBtnFg,
                        ),
                        onPressed: widget.controller.isBusy
                            ? null
                            : () => widget.controller.approveCheckpoint(
                                  record,
                                  channel: SafetyApprovalChannel.adminUi,
                                ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.verified_user_outlined),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'UIで承認して再開',
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: OutlinedButton(
                        key: ValueKey<String>(
                          'safety-approve-issue-${record.runKey}',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.primaryText,
                          backgroundColor: palette.panelSurface,
                          side: BorderSide(color: palette.border),
                        ),
                        onPressed: widget.controller.isBusy
                            ? null
                            : () => widget.controller.approveCheckpoint(
                                  record,
                                  channel: SafetyApprovalChannel.githubIssue,
                                  githubIssueNumber:
                                      _resolveIssueNumber(record),
                                ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.fact_check_outlined),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Issue承認で確認再開',
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: OutlinedButton(
                        key: ValueKey<String>(
                          'safety-reject-${record.runKey}',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.dangerFg,
                          backgroundColor: palette.dangerBg,
                          side: BorderSide(color: palette.dangerBorder),
                        ),
                        onPressed: widget.controller.isBusy
                            ? null
                            : () => widget.controller.rejectCheckpoint(record),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.block_outlined),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '拒否（実行停止）',
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              else
                _buildBadge(
                  key: ValueKey<String>('safety-admin-only-${record.runKey}'),
                  label: '管理者承認待ち（管理者のUI承認またはGitHub Issue承認が必要）',
                  bg: palette.warnBg,
                  fg: palette.warnFg,
                  border: palette.warnBorder,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBadge({
    Key? key,
    required String label,
    required Color bg,
    required Color fg,
    required Color border,
  }) {
    return DecoratedBox(
      key: key,
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

class _SafetyPalette {
  const _SafetyPalette({
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

  static _SafetyPalette fromBrightness(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const _SafetyPalette(
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
    return const _SafetyPalette(
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
