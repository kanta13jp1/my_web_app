import 'package:flutter/material.dart';

import '../application/agent_pause_checkpoint_controller.dart';
import '../domain/agent_pause_checkpoint_models.dart';

/// エージェントチェックポイント状態・90%早期警告・無欠損一時停止/再開パネル。
class AgentPauseCheckpointView extends StatefulWidget {
  const AgentPauseCheckpointView({
    super.key,
    required this.controller,
  });

  final AgentPauseCheckpointController controller;

  @override
  State<AgentPauseCheckpointView> createState() =>
      _AgentPauseCheckpointViewState();
}

class _AgentPauseCheckpointViewState extends State<AgentPauseCheckpointView> {
  final TextEditingController _runKeyController = TextEditingController();
  final TextEditingController _agentNameController = TextEditingController();
  final TextEditingController _usagePctController =
      TextEditingController(text: '92.0');
  final TextEditingController _pendingStepController = TextEditingController();

  @override
  void dispose() {
    _runKeyController.dispose();
    _agentNameController.dispose();
    _usagePctController.dispose();
    _pendingStepController.dispose();
    super.dispose();
  }

  Future<void> _handleCapture() async {
    final double parsedUsage =
        double.tryParse(_usagePctController.text.trim()) ?? 100.0;
    await widget.controller.captureCheckpoint(
      runKey: _runKeyController.text,
      agentName: _agentNameController.text,
      usageRatioPct: parsedUsage,
      pendingStep: _pendingStepController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final _CheckpointPalette palette = _CheckpointPalette.fromBrightness(
      Theme.of(context).brightness,
    );

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final List<AgentPauseCheckpointRecord> records =
            widget.controller.records;

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
                _buildSummaryMetrics(palette),
                if (widget.controller.statusMessage.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  _buildBanner(
                    key: const ValueKey<String>('checkpoint-status-banner'),
                    text: widget.controller.statusMessage,
                    bg: palette.okBg,
                    fg: palette.okFg,
                    border: palette.okBorder,
                  ),
                ],
                if (widget.controller.errorMessage.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  _buildBanner(
                    key: const ValueKey<String>('checkpoint-error-banner'),
                    text: widget.controller.errorMessage,
                    bg: palette.dangerBg,
                    fg: palette.dangerFg,
                    border: palette.dangerBorder,
                  ),
                ],
                const SizedBox(height: 14),
                _buildCaptureForm(palette),
                const SizedBox(height: 14),
                _buildRecordsSection(palette, records),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(_CheckpointPalette palette) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Icon(Icons.shield_outlined, color: palette.primaryText),
        Text(
          'エージェント無欠損一時停止・90%監視',
          style: TextStyle(
            color: palette.primaryText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        _buildBadge(
          key: const ValueKey<String>('checkpoint-header-badge'),
          label: '90%早期警告 / 無欠損保全',
          bg: palette.infoBg,
          fg: palette.infoFg,
          border: palette.infoBorder,
        ),
      ],
    );
  }

  Widget _buildSummaryMetrics(_CheckpointPalette palette) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        _buildMetricTile(
          palette,
          label: '90%警告中',
          value: '${widget.controller.warning90Count} 件',
          bg: palette.warnBg,
          fg: palette.warnFg,
          border: palette.warnBorder,
        ),
        _buildMetricTile(
          palette,
          label: '無欠損一時停止',
          value: '${widget.controller.pausedCount} 件',
          bg: palette.dangerBg,
          fg: palette.dangerFg,
          border: palette.dangerBorder,
        ),
        _buildMetricTile(
          palette,
          label: 'サイレント防止発報',
          value: '${widget.controller.silentAlertedCount} 件',
          bg: palette.infoBg,
          fg: palette.infoFg,
          border: palette.infoBorder,
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    _CheckpointPalette palette, {
    required String label,
    required String value,
    required Color bg,
    required Color fg,
    required Color border,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
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

  Widget _buildCaptureForm(_CheckpointPalette palette) {
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
              'チェックポイント記録（クレジット枯渇前保全）',
              style: TextStyle(
                color: palette.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const ValueKey<String>('checkpoint-run-key-field'),
              controller: _runKeyController,
              style: TextStyle(color: palette.primaryText),
              decoration: _inputDecoration(
                palette,
                label: 'Runキー',
                hint: '例: daily-brief-run-01',
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const ValueKey<String>('checkpoint-agent-name-field'),
              controller: _agentNameController,
              style: TextStyle(color: palette.primaryText),
              decoration: _inputDecoration(
                palette,
                label: 'エージェント名',
                hint: '例: digest-worker',
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const ValueKey<String>('checkpoint-usage-pct-field'),
              controller: _usagePctController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: palette.primaryText),
              decoration: _inputDecoration(
                palette,
                label: '使用率 (%)',
                hint: '90 以上で早期警告、100 以上で無欠損停止',
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const ValueKey<String>('checkpoint-pending-step-field'),
              controller: _pendingStepController,
              style: TextStyle(color: palette.primaryText),
              decoration: _inputDecoration(
                palette,
                label: '保全する未完了ステップ',
                hint: '例: step_3_publish_digest',
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
                  key: const ValueKey<String>('checkpoint-save-button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primaryBtnBg,
                    foregroundColor: palette.primaryBtnFg,
                  ),
                  onPressed: widget.controller.isBusy ? null : _handleCapture,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.save_outlined),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'スナップショット保存',
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
    _CheckpointPalette palette, {
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
    _CheckpointPalette palette,
    List<AgentPauseCheckpointRecord> records,
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
            '登録済みのエージェントチェックポイントはありません。',
            softWrap: true,
            style: TextStyle(color: palette.secondaryText),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: records.map((AgentPauseCheckpointRecord record) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildRecordCard(palette, record),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildRecordCard(
    _CheckpointPalette palette,
    AgentPauseCheckpointRecord record,
  ) {
    final Color statusBg = record.isLosslessPaused
        ? palette.dangerBg
        : (record.isWarning90OrAbove ? palette.warnBg : palette.okBg);
    final Color statusFg = record.isLosslessPaused
        ? palette.dangerFg
        : (record.isWarning90OrAbove ? palette.warnFg : palette.okFg);
    final Color statusBorder = record.isLosslessPaused
        ? palette.dangerBorder
        : (record.isWarning90OrAbove ? palette.warnBorder : palette.okBorder);

    return DecoratedBox(
      key: ValueKey<String>('checkpoint-card-${record.runKey}'),
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
                  '${record.runKey} (${record.agentName})',
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
                if (record.silentPauseAlerted)
                  _buildBadge(
                    label: 'サイレント停止アラート発報済',
                    bg: palette.dangerBg,
                    fg: palette.dangerFg,
                    border: palette.dangerBorder,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'seq ${record.checkpointSeq} | 使用率 ${record.usageRatioPct.toStringAsFixed(1)}% '
              '| 完了 ${record.completedCount} 件 | 未完了ステップ: '
              '${record.pendingStep.isEmpty ? '待機中' : record.pendingStep}',
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
            if (record.isLosslessPaused) ...<Widget>[
              const SizedBox(height: 10),
              if (widget.controller.canResumeAsAdmin)
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: OutlinedButton(
                    key: ValueKey<String>(
                      'checkpoint-resume-${record.runKey}',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.primaryText,
                      backgroundColor: palette.panelSurface,
                      side: BorderSide(color: palette.border),
                    ),
                    onPressed: widget.controller.isBusy
                        ? null
                        : () => widget.controller.resumeCheckpoint(record),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.play_arrow_outlined),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '無欠損再開',
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                _buildBadge(
                  key: ValueKey<String>(
                    'checkpoint-admin-only-${record.runKey}',
                  ),
                  label: '管理者レビュー待ち (is_admin のみ再開可)',
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

class _CheckpointPalette {
  const _CheckpointPalette({
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

  static _CheckpointPalette fromBrightness(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const _CheckpointPalette(
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
    return const _CheckpointPalette(
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
