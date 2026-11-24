import 'package:flutter/material.dart';

import '../services/weekly_performance_report_service.dart';

/// 週次パフォーマンスレポートの7日間集計サマリー・異常検知・
/// PII匿名化済みインサイトプレビュー・ドライラン配信トリガーパネル。
class WeeklyPerformanceReportPanel extends StatefulWidget {
  const WeeklyPerformanceReportPanel({
    super.key,
    required this.service,
  });

  final WeeklyPerformanceReportService service;

  @override
  State<WeeklyPerformanceReportPanel> createState() =>
      _WeeklyPerformanceReportPanelState();
}

class _WeeklyPerformanceReportPanelState
    extends State<WeeklyPerformanceReportPanel> {
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _WeeklyReportPalette palette = _WeeklyReportPalette.fromBrightness(
      Theme.of(context).brightness,
    );

    return ListenableBuilder(
      listenable: widget.service,
      builder: (BuildContext context, Widget? child) {
        final WeeklyPerformanceReport? report = widget.service.latestReport;

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
                _buildHeader(palette, report),
                if (widget.service.statusMessage.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  _buildBanner(
                    key: const ValueKey<String>('weekly-report-status-banner'),
                    text: widget.service.statusMessage,
                    bg: palette.infoBg,
                    fg: palette.infoFg,
                    border: palette.infoBorder,
                  ),
                ],
                const SizedBox(height: 14),
                if (report != null) ...<Widget>[
                  _buildMetricsGrid(palette, report),
                  const SizedBox(height: 12),
                  _buildAnomaliesSection(palette, report),
                  const SizedBox(height: 12),
                  _buildInsightCard(palette, report),
                  const SizedBox(height: 12),
                ],
                _buildControlsCard(palette),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    _WeeklyReportPalette palette,
    WeeklyPerformanceReport? report,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Icon(Icons.analytics_outlined, color: palette.primaryText),
        Text(
          '週次パフォーマンスレポート',
          style: TextStyle(
            color: palette.primaryText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (report != null) ...<Widget>[
          _buildPill(
            text: report.piiRedacted ? 'PII匿名化済み' : '要確認',
            bg: palette.okBg,
            fg: palette.okFg,
            border: palette.okBorder,
          ),
          _buildPill(
            key: const ValueKey<String>('weekly-report-delivery-pill'),
            text: report.deliveryStatus.labelJa,
            bg: palette.infoBg,
            fg: palette.infoFg,
            border: palette.infoBorder,
          ),
        ],
      ],
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
          style: TextStyle(color: fg),
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(
    _WeeklyReportPalette palette,
    WeeklyPerformanceReport report,
  ) {
    final String tasksDeltaStr =
        '${report.tasksDeltaPct >= 0 ? '+' : ''}${report.tasksDeltaPct.toStringAsFixed(1)}%';
    final String focusDeltaStr =
        '${report.focusDeltaPct >= 0 ? '+' : ''}${report.focusDeltaPct.toStringAsFixed(1)}%';

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
              '集計期間: ${report.periodStart} 〜 ${report.periodEnd}',
              softWrap: true,
              style: TextStyle(
                color: palette.secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _buildMetricBox(
                  palette,
                  label: '稼働日数',
                  value: '${report.activeDays} / 7日',
                ),
                _buildMetricBox(
                  palette,
                  label: '完了タスク',
                  value: '${report.tasksCompleted}件 ($tasksDeltaStr)',
                ),
                _buildMetricBox(
                  palette,
                  label: '集中時間',
                  value: '${report.focusMinutes}分 ($focusDeltaStr)',
                ),
                _buildMetricBox(
                  palette,
                  label: 'エラー件数',
                  value: '${report.errorCount}件',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricBox(
    _WeeklyReportPalette palette, {
    required String label,
    required String value,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.panelSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(color: palette.secondaryText, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              softWrap: true,
              style: TextStyle(
                color: palette.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnomaliesSection(
    _WeeklyReportPalette palette,
    WeeklyPerformanceReport report,
  ) {
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
              '異常検知ログ',
              style: TextStyle(
                color: palette.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (report.anomalies.isEmpty)
              Text(
                '特記すべき異常値は検知されませんでした。',
                softWrap: true,
                style: TextStyle(color: palette.secondaryText),
              )
            else
              ...report.anomalies.map(
                (WeeklyPerformanceAnomaly anomaly) {
                  final bool isAlert = anomaly.severity == 'high' ||
                      anomaly.severity == 'medium';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: isAlert ? palette.warnBg : palette.infoBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color:
                              isAlert ? palette.warnBorder : palette.infoBorder,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          '${anomaly.title}: ${anomaly.detail}',
                          softWrap: true,
                          style: TextStyle(
                            color: isAlert ? palette.warnFg : palette.infoFg,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(
    _WeeklyReportPalette palette,
    WeeklyPerformanceReport report,
  ) {
    return DecoratedBox(
      key: const ValueKey<String>('weekly-report-insight-card'),
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
              'AI 生成インサイト (サニタイズ済み)',
              style: TextStyle(
                color: palette.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              report.insightMarkdown,
              softWrap: true,
              style: TextStyle(color: palette.secondaryText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsCard(_WeeklyReportPalette palette) {
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
            TextFormField(
              key: const ValueKey<String>('weekly-report-note-field'),
              controller: _noteController,
              style: TextStyle(color: palette.primaryText),
              decoration: InputDecoration(
                filled: true,
                fillColor: palette.panelSurface,
                labelText: '補足メモ (送信前にPII自動マスク)',
                labelStyle: TextStyle(color: palette.secondaryText),
                hintText: '例: 来週は午前中の集中時間を増やす',
                hintMaxLines: 2,
                hintStyle: TextStyle(color: palette.secondaryText),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: palette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: palette.infoBorder, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: OutlinedButton(
                    key: const ValueKey<String>('weekly-report-dryrun-button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.primaryText,
                      backgroundColor: palette.panelSurface,
                      side: BorderSide(color: palette.border),
                    ),
                    onPressed: widget.service.isBusy
                        ? null
                        : () => widget.service.generateDryRunPreview(
                              contextNote: _noteController.text,
                            ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.preview_outlined),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'ドライラン生成',
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
                  child: ElevatedButton(
                    key: const ValueKey<String>('weekly-report-send-button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primaryBtnBg,
                      foregroundColor: palette.primaryBtnFg,
                    ),
                    onPressed: widget.service.isBusy
                        ? null
                        : () => widget.service.triggerDelivery(dryRun: false),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.mail_outline),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'レポート配信',
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

  Widget _buildPill({
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
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
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

class _WeeklyReportPalette {
  const _WeeklyReportPalette({
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
  final Color primaryBtnBg;
  final Color primaryBtnFg;

  static _WeeklyReportPalette fromBrightness(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const _WeeklyReportPalette(
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
        primaryBtnBg: Color(0xFF93C5FD),
        primaryBtnFg: Color(0xFF090D16),
      );
    }
    return const _WeeklyReportPalette(
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
      primaryBtnBg: Color(0xFF1E3A8A),
      primaryBtnFg: Color(0xFFFFFFFF),
    );
  }
}
