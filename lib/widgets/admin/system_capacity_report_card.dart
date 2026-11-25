import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../services/system_capacity_report_service.dart';

enum CapacityChartMetric {
  userAccess('アクセス数'),
  batchJobs('バッチ件数'),
  errorRate('エラー率 (%)');

  const CapacityChartMetric(this.label);

  final String label;
}

/// 管理者ダッシュボード向け: 月次システム利用統計とキャパシティレポートカード (#2745)。
class SystemCapacityReportCard extends StatefulWidget {
  const SystemCapacityReportCard({
    super.key,
    this.repository,
    this.initialReports,
  });

  final SystemCapacityReportRepository? repository;
  final List<SystemCapacityMonthlyStat>? initialReports;

  @override
  State<SystemCapacityReportCard> createState() =>
      _SystemCapacityReportCardState();
}

class _SystemCapacityReportCardState extends State<SystemCapacityReportCard> {
  SystemCapacityReportRepository? _repo;
  List<SystemCapacityMonthlyStat> _reports =
      const <SystemCapacityMonthlyStat>[];
  CapacityChartMetric _selectedMetric = CapacityChartMetric.userAccess;
  bool _loading = false;
  bool _aggregating = false;
  bool _notifying = false;
  String? _errorMessage;
  String? _statusMessage;

  SystemCapacityReportRepository _resolveRepository() {
    return _repo ??=
        widget.repository ?? SupabaseSystemCapacityReportRepository();
  }

  @override
  void initState() {
    super.initState();
    _repo = widget.repository;
    final seeded = widget.initialReports;
    if (seeded != null) {
      _reports = _sortDescending(seeded);
    } else {
      _loadReports();
    }
  }

  static List<SystemCapacityMonthlyStat> _sortDescending(
    List<SystemCapacityMonthlyStat> items,
  ) {
    final copy = List<SystemCapacityMonthlyStat>.from(items);
    copy.sort((a, b) => b.reportMonth.compareTo(a.reportMonth));
    return List<SystemCapacityMonthlyStat>.unmodifiable(copy);
  }

  List<SystemCapacityMonthlyStat> _chronologicalReports() {
    final copy = List<SystemCapacityMonthlyStat>.from(_reports);
    copy.sort((a, b) => a.reportMonth.compareTo(b.reportMonth));
    return copy;
  }

  Future<void> _loadReports() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final fetched = await _resolveRepository().fetchMonthlyStats(limit: 12);
      if (!mounted) return;
      setState(() {
        _reports = _sortDescending(fetched);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = '月次統計の読み込みに失敗しました: $e';
      });
    }
  }

  Future<void> _runAggregate() async {
    setState(() {
      _aggregating = true;
      _errorMessage = null;
      _statusMessage = null;
    });
    try {
      final targetMonth =
          _reports.isNotEmpty ? _reports.first.reportMonth : null;
      final updated = await _resolveRepository().aggregateMonth(
        reportMonth: targetMonth,
      );
      if (!mounted) return;
      final merged = <SystemCapacityMonthlyStat>[
        updated,
        ..._reports.where((r) => r.reportMonth != updated.reportMonth),
      ];
      setState(() {
        _reports = _sortDescending(merged);
        _aggregating = false;
        _statusMessage = '${updated.reportMonth} のシステム利用統計を再集計しました';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aggregating = false;
        _errorMessage = '統計の集計に失敗しました: $e';
      });
    }
  }

  Future<void> _sendNotification() async {
    setState(() {
      _notifying = true;
      _errorMessage = null;
      _statusMessage = null;
    });
    try {
      final targetMonth =
          _reports.isNotEmpty ? _reports.first.reportMonth : null;
      final result = await _resolveRepository().notifyReport(
        reportMonth: targetMonth,
      );
      if (!mounted) return;
      final merged = <SystemCapacityMonthlyStat>[
        result.report,
        ..._reports.where((r) => r.reportMonth != result.report.reportMonth),
      ];
      setState(() {
        _reports = _sortDescending(merged);
        _notifying = false;
        _statusMessage = result.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _notifying = false;
        _errorMessage = '月次レポート通知の送信に失敗しました: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final palette = _CapacityPalette.fromBrightness(isDark);
    final isBusy = _loading || _aggregating || _notifying;
    final latest = _reports.isNotEmpty ? _reports.first : null;
    final chronological = _chronologicalReports();

    return Card(
      key: const ValueKey<String>('system_capacity_report_card'),
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
                Icon(Icons.analytics_outlined, color: palette.accentFg),
                const SizedBox(width: 8),
                Flexible(
                  fit: FlexFit.tight,
                  child: Text(
                    '月次システム利用統計・キャパシティレポート',
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
                    key: const ValueKey<String>('capacity_report_refresh_btn'),
                    tooltip: '最新統計を再読込',
                    color: palette.textPrimary,
                    onPressed: isBusy ? null : _loadReports,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'ユーザーアクセス数・バッチ処理件数・エラー発生率の月次推移と関係者通知状況を確認できます。',
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
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: ElevatedButton.icon(
                    key: const ValueKey<String>(
                      'capacity_report_aggregate_btn',
                    ),
                    onPressed: isBusy ? null : _runAggregate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primaryBtnBg,
                      foregroundColor: palette.primaryBtnFg,
                      disabledBackgroundColor: palette.disabledBg,
                      disabledForegroundColor: palette.disabledFg,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.calculate_outlined, size: 18),
                    label: Text(
                      _aggregating ? '集計中...' : '今月を集計',
                      softWrap: true,
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: OutlinedButton.icon(
                    key: const ValueKey<String>('capacity_report_notify_btn'),
                    onPressed: isBusy ? null : _sendNotification,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: palette.cardBg,
                      foregroundColor: palette.secondaryBtnFg,
                      disabledForegroundColor: palette.disabledFg,
                      side: BorderSide(color: palette.secondaryBtnFg),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.mail_outline, size: 18),
                    label: Text(
                      _notifying ? '送信中...' : '月次レポート通知',
                      softWrap: true,
                    ),
                  ),
                ),
              ],
            ),
            if (isBusy) ...<Widget>[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              _buildStatusBanner(
                key: const ValueKey<String>('capacity_report_error_banner'),
                icon: Icons.error_outline,
                message: _errorMessage!,
                fg: palette.errorFg,
                bg: palette.errorBg,
                borderColor: palette.errorFg,
              ),
            ],
            if (_statusMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              _buildStatusBanner(
                key: const ValueKey<String>('capacity_report_status_banner'),
                icon: Icons.check_circle_outline,
                message: _statusMessage!,
                fg: palette.successFg,
                bg: palette.successBg,
                borderColor: palette.successFg,
              ),
            ],
            const SizedBox(height: 16),
            if (latest == null)
              Container(
                key: const ValueKey<String>('capacity_report_empty_state'),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.surfaceAltBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  '月次キャパシティ統計データがまだありません。「今月を集計」から初回集計を実行できます。',
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 13,
                    color: palette.textSecondary,
                    height: 1.5,
                  ),
                ),
              )
            else ...<Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _buildKpiTile(
                    key: const ValueKey<String>('capacity_kpi_access'),
                    label: '最新月 (${latest.reportMonth}) アクセス',
                    value: '${latest.userAccessCount} 件',
                    fg: palette.infoFg,
                    bg: palette.infoBg,
                  ),
                  _buildKpiTile(
                    key: const ValueKey<String>('capacity_kpi_batch'),
                    label: 'バッチ処理件数',
                    value: '${latest.batchJobCount} 件',
                    fg: palette.successFg,
                    bg: palette.successBg,
                  ),
                  _buildKpiTile(
                    key: const ValueKey<String>('capacity_kpi_error_rate'),
                    label: 'エラー発生率 (${latest.errorCount}件)',
                    value: '${latest.errorRatePercent.toStringAsFixed(2)}%',
                    fg: latest.errorRatePercent >= 5.0
                        ? palette.errorFg
                        : palette.infoFg,
                    bg: latest.errorRatePercent >= 5.0
                        ? palette.errorBg
                        : palette.infoBg,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CapacityChartMetric.values.map((metric) {
                  final selected = _selectedMetric == metric;
                  return ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: ChoiceChip(
                      key: ValueKey<String>(
                        'capacity_metric_chip_${metric.name}',
                      ),
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
                          _selectedMetric = metric;
                        });
                      },
                      label: Text(metric.label),
                    ),
                  );
                }).toList(growable: false),
              ),
              const SizedBox(height: 12),
              _buildTrendChart(context, chronological, palette),
              const SizedBox(height: 16),
              Text(
                '月次集計テーブル (${_reports.length}か月分)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 560) {
                    return _buildDesktopTable(palette);
                  }
                  return _buildMobileSummaryList(palette);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner({
    required Key key,
    required IconData icon,
    required String message,
    required Color fg,
    required Color bg,
    required Color borderColor,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
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

  double _metricValue(SystemCapacityMonthlyStat stat) {
    switch (_selectedMetric) {
      case CapacityChartMetric.userAccess:
        return stat.userAccessCount.toDouble();
      case CapacityChartMetric.batchJobs:
        return stat.batchJobCount.toDouble();
      case CapacityChartMetric.errorRate:
        return stat.errorRatePercent;
    }
  }

  Color _metricColor(_CapacityPalette palette) {
    switch (_selectedMetric) {
      case CapacityChartMetric.userAccess:
        return palette.chartAccessLine;
      case CapacityChartMetric.batchJobs:
        return palette.chartBatchLine;
      case CapacityChartMetric.errorRate:
        return palette.chartErrorLine;
    }
  }

  Widget _buildTrendChart(
    BuildContext context,
    List<SystemCapacityMonthlyStat> chronological,
    _CapacityPalette palette,
  ) {
    final spots = <FlSpot>[];
    var maxValue = 0.0;
    for (var i = 0; i < chronological.length; i += 1) {
      final value = _metricValue(chronological[i]);
      if (value > maxValue) maxValue = value;
      spots.add(FlSpot(i.toDouble(), value));
    }
    final maxY = maxValue <= 0 ? 10.0 : (maxValue * 1.2).ceilToDouble();
    final horizontalInterval =
        (maxY / 4).clamp(1.0, double.infinity).toDouble();
    final lineColor = _metricColor(palette);
    final maxX =
        chronological.length <= 1 ? 1.0 : (chronological.length - 1).toDouble();
    final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(
          1.0,
          2.5,
        );
    final bottomInterval = chronological.length <= 4
        ? 1.0
        : (chronological.length / 4).ceilToDouble();

    return Container(
      key: const ValueKey<String>('capacity_report_chart_container'),
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      decoration: BoxDecoration(
        color: palette.surfaceAltBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: 0,
          maxY: maxY,
          lineTouchData: const LineTouchData(enabled: false),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: horizontalInterval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: palette.border,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48 * textScale,
                interval: horizontalInterval,
                getTitlesWidget: (value, meta) {
                  final formatted =
                      _selectedMetric == CapacityChartMetric.errorRate
                          ? '${value.toStringAsFixed(1)}%'
                          : value.round().toString();
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      formatted,
                      style: TextStyle(
                        fontSize: 10,
                        color: palette.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28 * textScale,
                interval: bottomInterval,
                getTitlesWidget: (value, meta) {
                  if (value != value.roundToDouble()) {
                    return const SizedBox.shrink();
                  }
                  final idx = value.toInt();
                  if (idx < 0 || idx >= chronological.length) {
                    return const SizedBox.shrink();
                  }
                  final ym = chronological[idx].reportMonth;
                  final label = ym.length >= 7 ? ym.substring(2) : ym;
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        color: palette.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: lineColor,
              barWidth: 2.5,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: lineColor.withValues(alpha: 0.14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTable(_CapacityPalette palette) {
    final headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: palette.textPrimary,
      height: 1.4,
    );
    final cellStyle = TextStyle(
      fontSize: 12,
      color: palette.textPrimary,
      height: 1.4,
    );

    return Table(
      key: const ValueKey<String>('capacity_report_table'),
      border: TableBorder.all(
        color: palette.border,
        borderRadius: BorderRadius.circular(8),
      ),
      columnWidths: const <int, TableColumnWidth>{
        0: FlexColumnWidth(1.2),
        1: FlexColumnWidth(1.1),
        2: FlexColumnWidth(1.1),
        3: FlexColumnWidth(0.9),
        4: FlexColumnWidth(1.0),
        5: FlexColumnWidth(1.3),
      },
      children: <TableRow>[
        TableRow(
          decoration: BoxDecoration(color: palette.surfaceAltBg),
          children: <Widget>[
            _tableCell('対象月', headerStyle),
            _tableCell('アクセス数', headerStyle),
            _tableCell('バッチ件数', headerStyle),
            _tableCell('エラー数', headerStyle),
            _tableCell('エラー率', headerStyle),
            _tableCell('通知状態', headerStyle),
          ],
        ),
        for (final row in _reports)
          TableRow(
            children: <Widget>[
              _tableCell(row.reportMonth, cellStyle),
              _tableCell('${row.userAccessCount}', cellStyle),
              _tableCell('${row.batchJobCount}', cellStyle),
              _tableCell('${row.errorCount}', cellStyle),
              _tableCell(
                '${row.errorRatePercent.toStringAsFixed(2)}%',
                cellStyle,
              ),
              _tableCell(
                row.isNotified ? '通知済み' : '未通知',
                cellStyle,
              ),
            ],
          ),
      ],
    );
  }

  Widget _tableCell(String text, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(text, softWrap: true, style: style),
    );
  }

  Widget _buildMobileSummaryList(_CapacityPalette palette) {
    return Column(
      key: const ValueKey<String>('capacity_report_mobile_table'),
      children: _reports.map((row) {
        final notifFg = row.isNotified ? palette.successFg : palette.warningFg;
        final notifBg = row.isNotified ? palette.successBg : palette.warningBg;
        return Container(
          key: ValueKey<String>('capacity_mobile_row_${row.reportMonth}'),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.surfaceAltBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      row.reportMonth,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: notifBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      row.isNotified ? '通知済み' : '未通知',
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: notifFg,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Flexible(
                    fit: FlexFit.tight,
                    child: Text(
                      'アクセス: ${row.userAccessCount}',
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    fit: FlexFit.tight,
                    child: Text(
                      'バッチ: ${row.batchJobCount}',
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  Flexible(
                    fit: FlexFit.tight,
                    child: Text(
                      'エラー数: ${row.errorCount}',
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    fit: FlexFit.tight,
                    child: Text(
                      'エラー率: ${row.errorRatePercent.toStringAsFixed(2)}%',
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _CapacityPalette {
  const _CapacityPalette({
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
    required this.chartAccessLine,
    required this.chartBatchLine,
    required this.chartErrorLine,
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
  final Color chartAccessLine;
  final Color chartBatchLine;
  final Color chartErrorLine;

  factory _CapacityPalette.fromBrightness(bool isDark) {
    if (isDark) {
      return const _CapacityPalette(
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
        chartAccessLine: Color(0xFF93C5FD),
        chartBatchLine: Color(0xFF6EE7B7),
        chartErrorLine: Color(0xFFFCA5A5),
      );
    }
    return const _CapacityPalette(
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
      chartAccessLine: Color(0xFF1E3A8A),
      chartBatchLine: Color(0xFF065F46),
      chartErrorLine: Color(0xFF991B1B),
    );
  }
}
