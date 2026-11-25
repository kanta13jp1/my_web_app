import 'package:flutter/material.dart';

import '../application/external_diff_alert_controller.dart';
import '../domain/external_diff_alert_models.dart';

class ExternalDiffAlertView extends StatefulWidget {
  const ExternalDiffAlertView({
    super.key,
    required this.controller,
  });

  final ExternalDiffAlertController controller;

  @override
  State<ExternalDiffAlertView> createState() => _ExternalDiffAlertViewState();
}

class _ExternalDiffAlertViewState extends State<ExternalDiffAlertView> {
  final TextEditingController _sourceKeyController = TextEditingController(
    text: 'status_feed',
  );
  final TextEditingController _ruleNameController = TextEditingController(
    text: 'エラー件数急増アラート',
  );
  final TextEditingController _fieldPathController = TextEditingController(
    text: 'errors',
  );
  final TextEditingController _thresholdController = TextEditingController(
    text: '5',
  );
  final TextEditingController _recipientEmailController =
      TextEditingController();
  final TextEditingController _payloadJsonController = TextEditingController(
    text: '{"errors": 9, "latency_ms": 420}',
  );

  DiffRuleOperator _operator = DiffRuleOperator.gt;
  DiffAlertSeverity _severity = DiffAlertSeverity.critical;
  bool _notifyEmail = true;

  @override
  void dispose() {
    _sourceKeyController.dispose();
    _ruleNameController.dispose();
    _fieldPathController.dispose();
    _thresholdController.dispose();
    _recipientEmailController.dispose();
    _payloadJsonController.dispose();
    super.dispose();
  }

  Future<void> _submitRule() async {
    await widget.controller.saveRule(
      ruleName: _ruleNameController.text,
      sourceKey: _sourceKeyController.text,
      fieldPath: _fieldPathController.text,
      operatorType: _operator,
      thresholdValue: _thresholdController.text,
      severity: _severity,
      notifyEmail: _notifyEmail,
      recipientEmail: _recipientEmailController.text,
    );
  }

  Future<void> _submitSnapshotDetect() async {
    await widget.controller.runSnapshotDetectFromJson(
      sourceKey: _sourceKeyController.text,
      rawPayloadJson: _payloadJsonController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('外部連携 差分検知・リアルタイムアラート'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        actions: <Widget>[
          IconButton(
            key: const Key('external_diff_refresh_btn'),
            tooltip: '再読み込み',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: widget.controller.loadDashboard,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (BuildContext context, Widget? child) {
          final state = widget.controller.state;
          if (state.isLoading && state.alerts.isEmpty && state.rules.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _RealtimeSummaryCard(state: state),
                    const SizedBox(height: 16),
                    if (state.errorMessage != null) ...<Widget>[
                      _BannerCard(
                        bannerKey: const Key('external_diff_error_banner'),
                        message: state.errorMessage!,
                        isError: true,
                        onRetry: widget.controller.loadDashboard,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (state.statusNotice != null) ...<Widget>[
                      _BannerCard(
                        bannerKey: const Key('external_diff_status_banner'),
                        message: state.statusNotice!,
                        isError: false,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _RuleAndSnapshotFormCard(
                      sourceKeyController: _sourceKeyController,
                      ruleNameController: _ruleNameController,
                      fieldPathController: _fieldPathController,
                      thresholdController: _thresholdController,
                      recipientEmailController: _recipientEmailController,
                      payloadJsonController: _payloadJsonController,
                      operatorType: _operator,
                      severity: _severity,
                      notifyEmail: _notifyEmail,
                      isSubmitting: state.isSubmitting,
                      onOperatorChanged: (DiffRuleOperator? value) {
                        if (value != null) {
                          setState(() => _operator = value);
                        }
                      },
                      onSeverityChanged: (DiffAlertSeverity? value) {
                        if (value != null) {
                          setState(() => _severity = value);
                        }
                      },
                      onNotifyEmailChanged: (bool value) {
                        setState(() => _notifyEmail = value);
                      },
                      onSaveRule: _submitRule,
                      onDetectDiff: _submitSnapshotDetect,
                    ),
                    const SizedBox(height: 16),
                    _AlertsFeedCard(
                      alerts: state.alerts,
                      onAcknowledge: widget.controller.acknowledgeAlert,
                    ),
                    const SizedBox(height: 16),
                    _RulesAndSnapshotsCard(
                      rules: state.rules,
                      snapshots: state.snapshots,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RealtimeSummaryCard extends StatelessWidget {
  const _RealtimeSummaryCard({required this.state});

  final ExternalDiffAlertState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Chip(
              key: const Key('external_diff_realtime_chip'),
              avatar: Icon(
                state.realtimeActive
                    ? Icons.sensors
                    : Icons.sensors_off_outlined,
                size: 18,
              ),
              label: Text(
                state.realtimeActive ? 'Realtime 監視接続中' : 'Realtime 待機中',
              ),
            ),
            Text(
              '未確認アラート: ${state.unacknowledgedCount} 件 / '
              'ルール: ${state.rules.length} 件 / '
              'スナップショット: ${state.snapshots.length} 件',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.bannerKey,
    required this.message,
    required this.isError,
    this.onRetry,
  });

  final Key bannerKey;
  final String message;
  final bool isError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg =
        isError ? colorScheme.errorContainer : colorScheme.secondaryContainer;
    final fg = isError
        ? colorScheme.onErrorContainer
        : colorScheme.onSecondaryContainer;
    return Semantics(
      liveRegion: true,
      child: Card(
        key: bannerKey,
        color: bg,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                message,
                style:
                    Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg),
              ),
              if (onRetry != null) ...<Widget>[
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('external_diff_retry_btn'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: fg,
                  ),
                  onPressed: onRetry,
                  child: const Text('再試行'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleAndSnapshotFormCard extends StatelessWidget {
  const _RuleAndSnapshotFormCard({
    required this.sourceKeyController,
    required this.ruleNameController,
    required this.fieldPathController,
    required this.thresholdController,
    required this.recipientEmailController,
    required this.payloadJsonController,
    required this.operatorType,
    required this.severity,
    required this.notifyEmail,
    required this.isSubmitting,
    required this.onOperatorChanged,
    required this.onSeverityChanged,
    required this.onNotifyEmailChanged,
    required this.onSaveRule,
    required this.onDetectDiff,
  });

  final TextEditingController sourceKeyController;
  final TextEditingController ruleNameController;
  final TextEditingController fieldPathController;
  final TextEditingController thresholdController;
  final TextEditingController recipientEmailController;
  final TextEditingController payloadJsonController;
  final DiffRuleOperator operatorType;
  final DiffAlertSeverity severity;
  final bool notifyEmail;
  final bool isSubmitting;
  final ValueChanged<DiffRuleOperator?> onOperatorChanged;
  final ValueChanged<DiffAlertSeverity?> onSeverityChanged;
  final ValueChanged<bool> onNotifyEmailChanged;
  final Future<void> Function() onSaveRule;
  final Future<void> Function() onDetectDiff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '差分検知トリガールール & スナップショット比較',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('external_diff_source_key_field'),
              controller: sourceKeyController,
              decoration: const InputDecoration(
                labelText: '外部ソースキー (source_key)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('external_diff_rule_name_field'),
              controller: ruleNameController,
              decoration: const InputDecoration(
                labelText: 'トリガールール名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                SizedBox(
                  width: 220,
                  child: TextField(
                    key: const Key('external_diff_field_path_field'),
                    controller: fieldPathController,
                    decoration: const InputDecoration(
                      labelText: '監視フィールドパス',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<DiffRuleOperator>(
                    key: const Key('external_diff_operator_dropdown'),
                    isExpanded: true,
                    initialValue: operatorType,
                    decoration: const InputDecoration(
                      labelText: '検知条件',
                      border: OutlineInputBorder(),
                    ),
                    items: DiffRuleOperator.values
                        .map(
                          (op) => DropdownMenuItem<DiffRuleOperator>(
                            value: op,
                            child: Text(
                              op.labelJa,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: onOperatorChanged,
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextField(
                    key: const Key('external_diff_threshold_field'),
                    controller: thresholdController,
                    decoration: const InputDecoration(
                      labelText: '閾値 / 一致語',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<DiffAlertSeverity>(
                    key: const Key('external_diff_severity_dropdown'),
                    isExpanded: true,
                    initialValue: severity,
                    decoration: const InputDecoration(
                      labelText: '重大度',
                      border: OutlineInputBorder(),
                    ),
                    items: DiffAlertSeverity.values
                        .map(
                          (sev) => DropdownMenuItem<DiffAlertSeverity>(
                            value: sev,
                            child: Text(
                              sev.labelJa,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: onSeverityChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('external_diff_recipient_email_field'),
              controller: recipientEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: '通知先メールアドレス（空欄時はアカウント登録メール）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('external_diff_notify_email_switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('アラート発生時にテンプレート通知メールを即時送信'),
              value: notifyEmail,
              onChanged: onNotifyEmailChanged,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('external_diff_payload_json_field'),
              controller: payloadJsonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '取得ペイロード JSON（前回スナップショットと差分比較）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                OutlinedButton(
                  key: const Key('external_diff_save_rule_btn'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: isSubmitting ? null : onSaveRule,
                  child: const Text('トリガールール保存'),
                ),
                FilledButton(
                  key: const Key('external_diff_detect_btn'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: isSubmitting ? null : onDetectDiff,
                  child: Text(isSubmitting ? '比較実行中...' : '前回差分を比較して通知実行'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertsFeedCard extends StatelessWidget {
  const _AlertsFeedCard({
    required this.alerts,
    required this.onAcknowledge,
  });

  final List<ExternalDiffAlertEvent> alerts;
  final Future<void> Function(String alertId) onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'リアルタイム発火アラート一覧',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (alerts.isEmpty)
              const Text('検知されたアラートはまだありません。')
            else
              for (final alert in alerts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          alert.title,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(alert.diffSummary),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            Text('重大度: ${alert.severity.labelJa}'),
                            Text('メール: ${alert.emailStatus}'),
                            if (alert.emailRecipientMasked.isNotEmpty)
                              Text('宛先: ${alert.emailRecipientMasked}'),
                            if (!alert.isAcknowledged)
                              TextButton(
                                key: Key('external_diff_ack_${alert.id}'),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                ),
                                onPressed: () {
                                  onAcknowledge(alert.id);
                                },
                                child: const Text('確認済みにする'),
                              )
                            else
                              const Text('確認済み'),
                          ],
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
}

class _RulesAndSnapshotsCard extends StatelessWidget {
  const _RulesAndSnapshotsCard({
    required this.rules,
    required this.snapshots,
  });

  final List<ExternalDiffRule> rules;
  final List<ExternalSnapshotSummary> snapshots;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '登録済みルール & 直近スナップショット',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (rules.isEmpty)
              const Text('トリガールールは未登録です。')
            else
              for (final rule in rules)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• ${rule.ruleName} (${rule.sourceKey}: '
                    '${rule.fieldPath} ${rule.operatorType.labelJa} '
                    '${rule.thresholdValue})',
                  ),
                ),
            const Divider(height: 24),
            if (snapshots.isEmpty)
              const Text('ベースラインスナップショットはまだ保存されていません。')
            else
              for (final snap in snapshots)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• ${snap.sourceKey} [${snap.payloadHash.substring(0, snap.payloadHash.length > 10 ? 10 : snap.payloadHash.length)}] (${snap.fetchedAt})',
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
