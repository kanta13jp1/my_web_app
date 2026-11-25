import 'package:flutter/material.dart';

import '../application/llm_healthcheck_controller.dart';
import '../domain/llm_healthcheck_models.dart';

@immutable
class _LlmHealthPalette {
  const _LlmHealthPalette({
    required this.surface,
    required this.surfaceSubtle,
    required this.border,
    required this.ink,
    required this.inkSecondary,
    required this.accent,
    required this.onAccent,
    required this.okBg,
    required this.okBorder,
    required this.okInk,
    required this.warnBg,
    required this.warnBorder,
    required this.warnInk,
    required this.dangerBg,
    required this.dangerBorder,
    required this.dangerInk,
  });

  factory _LlmHealthPalette.fromBrightness(final Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const _LlmHealthPalette(
        surface: Color(0xFF111827),
        surfaceSubtle: Color(0xFF1F2937),
        border: Color(0xFF9CA3AF),
        ink: Color(0xFFF9FAFB),
        inkSecondary: Color(0xFFE5E7EB),
        accent: Color(0xFF5EEAD4),
        onAccent: Color(0xFF042F2E),
        okBg: Color(0xFF022C22),
        okBorder: Color(0xFF5EEAD4),
        okInk: Color(0xFFCCFBF1),
        warnBg: Color(0xFF332100),
        warnBorder: Color(0xFFFBBF24),
        warnInk: Color(0xFFFEF3C7),
        dangerBg: Color(0xFF450A0A),
        dangerBorder: Color(0xFFFCA5A5),
        dangerInk: Color(0xFFFEE2E2),
      );
    }
    return const _LlmHealthPalette(
      surface: Color(0xFFFFFFFF),
      surfaceSubtle: Color(0xFFF3F5F8),
      border: Color(0xFF4B5563),
      ink: Color(0xFF111827),
      inkSecondary: Color(0xFF374151),
      accent: Color(0xFF115E59),
      onAccent: Color(0xFFFFFFFF),
      okBg: Color(0xFFECFDF5),
      okBorder: Color(0xFF115E59),
      okInk: Color(0xFF064E3B),
      warnBg: Color(0xFFFFF4E5),
      warnBorder: Color(0xFF8A4B00),
      warnInk: Color(0xFF5A2E00),
      dangerBg: Color(0xFFFEF2F2),
      dangerBorder: Color(0xFFB91C1C),
      dangerInk: Color(0xFF7F1D1D),
    );
  }

  final Color surface;
  final Color surfaceSubtle;
  final Color border;
  final Color ink;
  final Color inkSecondary;
  final Color accent;
  final Color onAccent;
  final Color okBg;
  final Color okBorder;
  final Color okInk;
  final Color warnBg;
  final Color warnBorder;
  final Color warnInk;
  final Color dangerBg;
  final Color dangerBorder;
  final Color dangerInk;
}

class LlmHealthcheckView extends StatelessWidget {
  const LlmHealthcheckView({
    super.key,
    required this.state,
    required this.providerNameController,
    required this.endpointUrlController,
    required this.timeoutMsController,
    required this.alertChannelController,
    required this.onRefresh,
    required this.onSeedDefaults,
    required this.onDraftMethodChanged,
    required this.onSaveEndpoint,
    required this.onDeleteEndpoint,
    required this.onRunProbeAll,
    required this.onRunProbeSingle,
  });

  final LlmHealthcheckState state;
  final TextEditingController providerNameController;
  final TextEditingController endpointUrlController;
  final TextEditingController timeoutMsController;
  final TextEditingController alertChannelController;
  final VoidCallback onRefresh;
  final VoidCallback onSeedDefaults;
  final ValueChanged<String> onDraftMethodChanged;
  final VoidCallback onSaveEndpoint;
  final ValueChanged<String> onDeleteEndpoint;
  final VoidCallback onRunProbeAll;
  final ValueChanged<String> onRunProbeSingle;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final palette = _LlmHealthPalette.fromBrightness(theme.brightness);
    final snapshot = state.snapshot;

    return Container(
      color: palette.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildHeader(theme, palette),
            const SizedBox(height: 12),
            if (state.errorMessage != null) ...<Widget>[
              _buildBanner(
                key: const ValueKey<String>('llm_health_error_banner'),
                icon: Icons.error_outline,
                bg: palette.dangerBg,
                border: palette.dangerBorder,
                fg: palette.dangerInk,
                title: 'エラーが発生しました',
                body: state.errorMessage!,
                theme: theme,
              ),
              const SizedBox(height: 12),
            ],
            if (state.noticeMessage != null) ...<Widget>[
              _buildBanner(
                key: const ValueKey<String>('llm_health_notice_banner'),
                icon: Icons.check_circle_outline,
                bg: palette.okBg,
                border: palette.okBorder,
                fg: palette.okInk,
                title: '実行結果',
                body: state.noticeMessage!,
                theme: theme,
              ),
              const SizedBox(height: 12),
            ],
            _buildSummaryKpis(theme, palette, snapshot),
            const SizedBox(height: 16),
            _buildProviderUptimeCard(theme, palette, snapshot),
            const SizedBox(height: 16),
            _buildLatencyHistoryCard(theme, palette, snapshot),
            const SizedBox(height: 16),
            _buildEndpointsCard(theme, palette, snapshot),
            const SizedBox(height: 16),
            _buildEndpointFormCard(theme, palette),
            const SizedBox(height: 16),
            _buildAlertsCard(theme, palette, snapshot),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(final ThemeData theme, final _LlmHealthPalette palette) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '新規 LLM プロバイダー API ヘルスチェック監視',
              style: theme.textTheme.titleLarge?.copyWith(
                color: palette.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '動的登録エンドポイントの稼働率・応答時間履歴・タイムアウト自動検知',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.inkSecondary,
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                key: const ValueKey<String>('llm_health_seed_button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.accent,
                  side: BorderSide(color: palette.accent),
                  minimumSize: const Size(48, 48),
                ),
                onPressed: state.isSaving ? null : onSeedDefaults,
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: const Text('サンプル投入'),
              ),
            ),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                key: const ValueKey<String>('llm_health_run_probe_button'),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.accent,
                  foregroundColor: palette.onAccent,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: state.isSaving ? null : onRunProbeAll,
                icon: const Icon(Icons.monitor_heart_outlined),
                label: const Text('全件即計測'),
              ),
            ),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                key: const ValueKey<String>('llm_health_refresh_button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.accent,
                  side: BorderSide(color: palette.accent),
                  minimumSize: const Size(48, 48),
                ),
                onPressed: state.isLoading ? null : onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('更新'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBanner({
    required final Key key,
    required final IconData icon,
    required final Color bg,
    required final Color border,
    required final Color fg,
    required final String title,
    required final String body,
    required final ThemeData theme,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryKpis(
    final ThemeData theme,
    final _LlmHealthPalette palette,
    final LlmHealthDashboardSnapshot snapshot,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        _buildKpiTile(
          key: const ValueKey<String>('llm_health_uptime_kpi'),
          theme: theme,
          palette: palette,
          label: '全体稼働率',
          value: '${snapshot.overallUptimePct.toStringAsFixed(1)}%',
          subtext: '${snapshot.logs.length} 回の直近プローブ基準',
        ),
        _buildKpiTile(
          key: const ValueKey<String>('llm_health_latency_kpi'),
          theme: theme,
          palette: palette,
          label: '平均応答時間',
          value: '${snapshot.avgLatencyMs} ms',
          subtext: '${snapshot.endpoints.length} 件の監視対象を登録中',
        ),
        _buildKpiTile(
          key: const ValueKey<String>('llm_health_alert_count_kpi'),
          theme: theme,
          palette: palette,
          label: '検知済み障害アラート',
          value: '${snapshot.alerts.length} 件',
          subtext: 'タイムアウト・HTTP異常発生時に記録',
        ),
      ],
    );
  }

  Widget _buildKpiTile({
    required final Key key,
    required final ThemeData theme,
    required final _LlmHealthPalette palette,
    required final String label,
    required final String value,
    required final String subtext,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 360),
      child: Container(
        key: key,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surfaceSubtle,
          border: Border.all(color: palette.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: palette.inkSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: palette.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtext,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.inkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderUptimeCard(
    final ThemeData theme,
    final _LlmHealthPalette palette,
    final LlmHealthDashboardSnapshot snapshot,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'プロバイダー別稼働率・レイテンシ',
            style: theme.textTheme.titleMedium?.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (snapshot.providers.isEmpty)
            Text(
              '監視対象の LLM エンドポイントはまだ登録されていません。',
              key: const ValueKey<String>('llm_health_empty_state'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.inkSecondary,
              ),
            )
          else
            for (final item in snapshot.providers) ...<Widget>[
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 2,
                  children: <Widget>[
                    Text(
                      '${item.providerName} (${item.healthyChecks}/${item.totalChecks})',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${item.uptimePct.toStringAsFixed(1)}% ・ ${item.avgLatencyMs} ms',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: (item.uptimePct / 100.0).clamp(0.0, 1.0),
                color: item.uptimePct >= 95
                    ? palette.accent
                    : palette.dangerBorder,
                backgroundColor: palette.surface,
                minHeight: 8,
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _buildLatencyHistoryCard(
    final ThemeData theme,
    final _LlmHealthPalette palette,
    final LlmHealthDashboardSnapshot snapshot,
  ) {
    final recentLogs = snapshot.logs.take(12).toList(growable: false);
    final maxLatency = recentLogs.isEmpty
        ? 100
        : recentLogs
            .map((final l) => l.latencyMs)
            .reduce((final a, final b) => a > b ? a : b)
            .clamp(100, 15000);

    return Container(
      key: const ValueKey<String>('llm_health_latency_history'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '応答時間履歴 (直近最大12件)',
            style: theme.textTheme.titleMedium?.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (recentLogs.isEmpty)
            Text(
              'まだヘルスチェック実行履歴はありません。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.inkSecondary,
              ),
            )
          else
            for (final log in recentLogs) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 2,
                        children: <Widget>[
                          Text(
                            '${log.providerName} (${log.status})',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${log.latencyMs} ms',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    LinearProgressIndicator(
                      value: (log.latencyMs / maxLatency).clamp(0.05, 1.0),
                      color: log.status == 'down'
                          ? palette.dangerBorder
                          : log.status == 'degraded'
                              ? palette.warnBorder
                              : palette.accent,
                      backgroundColor: palette.surface,
                      minHeight: 8,
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildEndpointsCard(
    final ThemeData theme,
    final _LlmHealthPalette palette,
    final LlmHealthDashboardSnapshot snapshot,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '動的登録済みエンドポイント一覧',
            style: theme.textTheme.titleMedium?.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (snapshot.endpoints.isEmpty)
            Text(
              '下のフォームから https:// エンドポイントを追加してください。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.inkSecondary,
              ),
            )
          else
            for (final ep in snapshot.endpoints)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.surface,
                  border: Border.all(color: palette.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${ep.providerName} [${ep.method}]',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: palette.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${ep.endpointUrl} ・ ${ep.timeoutMs} ms ・ ${ep.alertChannel}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: ValueKey<String>('probe_endpoint_${ep.id}'),
                      tooltip: '${ep.providerName} を今すぐ計測',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      color: palette.accent,
                      onPressed:
                          state.isSaving ? null : () => onRunProbeSingle(ep.id),
                      icon: const Icon(Icons.play_arrow_outlined),
                    ),
                    IconButton(
                      key: ValueKey<String>('delete_endpoint_${ep.id}'),
                      tooltip: '${ep.providerName} を削除',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      color: palette.dangerBorder,
                      onPressed:
                          state.isSaving ? null : () => onDeleteEndpoint(ep.id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildEndpointFormCard(
    final ThemeData theme,
    final _LlmHealthPalette palette,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '新規 LLM エンドポイント登録 (SSRF ガード付き)',
            style: theme.textTheme.titleMedium?.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: TextField(
                  key: const ValueKey<String>('llm_health_provider_field'),
                  controller: providerNameController,
                  style: TextStyle(color: palette.ink),
                  decoration: InputDecoration(
                    labelText: 'プロバイダー名',
                    labelStyle: TextStyle(color: palette.inkSecondary),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: palette.surface,
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: TextField(
                  key: const ValueKey<String>('llm_health_url_field'),
                  controller: endpointUrlController,
                  style: TextStyle(color: palette.ink),
                  decoration: InputDecoration(
                    labelText: '監視 URL (https:// のみ)',
                    labelStyle: TextStyle(color: palette.inkSecondary),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: palette.surface,
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: DropdownButtonFormField<String>(
                  key: const ValueKey<String>('llm_health_method_dropdown'),
                  isExpanded: true,
                  initialValue: state.draftMethod,
                  decoration: InputDecoration(
                    labelText: '方式',
                    labelStyle: TextStyle(color: palette.inkSecondary),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: palette.surface,
                  ),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(value: 'GET', child: Text('GET')),
                    DropdownMenuItem<String>(
                      value: 'HEAD',
                      child: Text('HEAD'),
                    ),
                  ],
                  onChanged: (final val) {
                    if (val != null) onDraftMethodChanged(val);
                  },
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: TextField(
                  key: const ValueKey<String>('llm_health_timeout_field'),
                  controller: timeoutMsController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: palette.ink),
                  decoration: InputDecoration(
                    labelText: 'タイムアウト (ms)',
                    labelStyle: TextStyle(color: palette.inkSecondary),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: palette.surface,
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: TextField(
                  key: const ValueKey<String>('llm_health_channel_field'),
                  controller: alertChannelController,
                  style: TextStyle(color: palette.ink),
                  decoration: InputDecoration(
                    labelText: '通知チャンネル',
                    labelStyle: TextStyle(color: palette.inkSecondary),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: palette.surface,
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  key: const ValueKey<String>('llm_health_save_button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.accent,
                    foregroundColor: palette.onAccent,
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: state.isSaving ? null : onSaveEndpoint,
                  icon: const Icon(Icons.add_link_outlined),
                  label: const Text('監視先を登録'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsCard(
    final ThemeData theme,
    final _LlmHealthPalette palette,
    final LlmHealthDashboardSnapshot snapshot,
  ) {
    return Container(
      key: const ValueKey<String>('llm_health_alerts_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'タイムアウト・障害アラート履歴',
            style: theme.textTheme.titleMedium?.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (snapshot.alerts.isEmpty)
            Text(
              '現在アラートは記録されていません。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.inkSecondary,
              ),
            )
          else
            for (final alert in snapshot.alerts.take(10))
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.dangerBg,
                  border: Border.all(color: palette.dangerBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${alert.providerName} ・ ${alert.errorType} (${alert.deliveryStatus})',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.dangerInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'チャンネル: ${alert.alertChannel} ・ ${alert.errorMessage}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.dangerInk,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
