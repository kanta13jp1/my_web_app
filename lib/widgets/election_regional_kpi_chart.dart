import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/local_election_plan.dart';

class ElectionRegionalKpiChart extends StatefulWidget {
  final List<LocalElectionPrefecturePlan> prefectures;
  final GlobalKey? pieChartKey;

  const ElectionRegionalKpiChart({
    super.key,
    required this.prefectures,
    this.pieChartKey,
  });

  @override
  State<ElectionRegionalKpiChart> createState() =>
      _ElectionRegionalKpiChartState();
}

class _ElectionRegionalKpiChartState extends State<ElectionRegionalKpiChart> {
  final GlobalKey _barChartKey = GlobalKey();
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = ascending;
      }
    });
  }

  Future<void> _printChart() async {
    try {
      // 棒グラフをキャプチャ
      final barChartBoundary = _barChartKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (barChartBoundary == null) return;

      final barChartImage = await barChartBoundary.toImage(pixelRatio: 3.0);
      final barChartByteData =
          await barChartImage.toByteData(format: ui.ImageByteFormat.png);
      if (barChartByteData == null) return;
      final barChartPdfImage =
          pw.MemoryImage(barChartByteData.buffer.asUint8List());

      // 円グラフをキャプチャ
      pw.MemoryImage? pieChartPdfImage;
      if (widget.pieChartKey != null) {
        final pieChartBoundary = widget.pieChartKey!.currentContext
            ?.findRenderObject() as RenderRepaintBoundary?;
        if (pieChartBoundary != null) {
          final pieChartImage = await pieChartBoundary.toImage(pixelRatio: 3.0);
          final pieChartByteData =
              await pieChartImage.toByteData(format: ui.ImageByteFormat.png);
          if (pieChartByteData != null) {
            pieChartPdfImage =
                pw.MemoryImage(pieChartByteData.buffer.asUint8List());
          }
        }
      }

      // 日本語フォントの読み込み（文字化け防止）
      final ttfRegular = await PdfGoogleFonts.notoSansJPRegular();
      final ttfBold = await PdfGoogleFonts.notoSansJPBold();

      // ロゴ画像をアセットから読み込む (パスはプロジェクトに合わせて調整してください)
      final logoData = await rootBundle.load('assets/icon/icon.png');
      final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

      // ユーザー名の取得
      String authorName = 'システム管理者';
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          final profile = await Supabase.instance.client
              .from('user_profiles')
              .select('display_name')
              .eq('user_id', user.id)
              .maybeSingle();
          if (profile != null &&
              profile['display_name']?.toString().isNotEmpty == true) {
            authorName = profile['display_name'].toString();
          } else if (user.email != null) {
            authorName = user.email!;
          }
        }
      } catch (_) {}

      final now = DateTime.now();
      final dateStr =
          '${now.year}年${now.month}月${now.day}日 ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      // ファイル名用に日付文字列を生成 (例: 20260328)
      final dateFilenameStr =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final filename = 'election_report_$dateFilenameStr.pdf';

      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '統一地方選700 必達管理レポート',
                      style: pw.TextStyle(
                        font: ttfBold,
                        fontSize: 18,
                        height: 1.5,
                      ),
                    ),
                    pw.Text(
                      '出力日時: $dateStr\n作成者: $authorName\nページ: ${context.pageNumber} / ${context.pagesCount}',
                      style: pw.TextStyle(
                        font: ttfRegular,
                        fontSize: 10,
                        color: PdfColors.grey700,
                        height: 1.5,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ],
                ),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(
                  height: 10,
                ),
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      if (pieChartPdfImage != null)
                        pw.Expanded(
                          flex: 2,
                          child: pw.Center(child: pw.Image(pieChartPdfImage)),
                        ),
                      if (pieChartPdfImage != null)
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 8),
                          child: pw.Divider(color: PdfColors.grey400),
                        ),
                      pw.Expanded(
                        flex: 3,
                        child: pw.Center(child: pw.Image(barChartPdfImage)),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(
                  height: 10,
                ),
                pw.Divider(color: PdfColors.grey300),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Image(
                      logoImage,
                      width: 24,
                      height: 24,
                    ),
                    pw.Text(
                      '自分株式会社 - 経営コックピット',
                      style: pw.TextStyle(
                        font: ttfRegular,
                        fontSize: 8,
                        color: PdfColors.grey500,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: filename,
      );
    } catch (e) {
      debugPrint('PDF出力エラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.prefectures.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalRetain = widget.prefectures
        .fold<int>(0, (sum, p) => sum + p.incumbentRetentionTarget);
    final totalNew =
        widget.prefectures.fold<int>(0, (sum, p) => sum + p.newCandidateTarget);
    final totalTarget = totalRetain + totalNew;

    // 月次進捗データの集計
    final monthlyStats = <String, Map<String, int>>{};
    for (final p in widget.prefectures) {
      final month = p.endorsementDeadlineMonth;
      if (month.isEmpty) continue;
      monthlyStats.putIfAbsent(month, () => {'total': 0, 'confirmed': 0});
      monthlyStats[month]!['total'] = monthlyStats[month]!['total']! + 1;
      if (p.endorsementConfirmed) {
        monthlyStats[month]!['confirmed'] =
            monthlyStats[month]!['confirmed']! + 1;
      }
    }

    final sortedMonths = monthlyStats.keys.toList();
    sortedMonths.sort((a, b) {
      final statA = monthlyStats[a]!;
      final statB = monthlyStats[b]!;

      int cmp = 0;
      switch (_sortColumnIndex) {
        case 0:
          cmp = a.compareTo(b);
          break;
        case 1:
          cmp = statA['total']!.compareTo(statB['total']!);
          break;
        case 2:
          cmp = statA['confirmed']!.compareTo(statB['confirmed']!);
          break;
        case 3:
          final unconfA = statA['total']! - statA['confirmed']!;
          final unconfB = statB['total']! - statB['confirmed']!;
          cmp = unconfA.compareTo(unconfB);
          break;
        case 4:
          final progA =
              statA['total']! > 0 ? statA['confirmed']! / statA['total']! : 0.0;
          final progB =
              statB['total']! > 0 ? statB['confirmed']! / statB['total']! : 0.0;
          cmp = progA.compareTo(progB);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '都道府県連別 目標配分 (現職維持 + 新人擁立)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.print),
                  tooltip: 'PDFレポートを出力・印刷',
                  onPressed: _printChart,
                ),
              ],
            ),
            const SizedBox(
              height: 16,
            ),
            RepaintBoundary(
              key: _barChartKey,
              child: Container(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBBDEFB)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildSummaryItem(
                                '現職維持 合計',
                                totalRetain.toString(),
                                const Color(0xFF1976D2),
                              ),
                              _buildSummaryItem(
                                '新人擁立 合計',
                                totalNew.toString(),
                                const Color(0xFFFF9800),
                              ),
                              _buildSummaryItem(
                                '総合計',
                                totalTarget.toString(),
                                const Color(0xFF303F9F),
                              ),
                            ],
                          ),
                          if (totalTarget < 700) ...[
                            const SizedBox(
                              height: 12,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.red.shade700,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '必達目標(700名)まで あと ${700 - totalTarget}名 不足しています',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 32,
                    ),
                    SizedBox(
                      height: 300,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: _getMaxY(),
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipColor: (group) =>
                                  const Color(0xFF263238),
                              getTooltipItem:
                                  (group, groupIndex, rod, rodIndex) {
                                final data = widget.prefectures[group.x];
                                final isAchieved =
                                    data.additionalSeatTarget > 0 &&
                                        data.newCandidateTarget >=
                                            data.additionalSeatTarget;
                                final newTargetColor = isAchieved
                                    ? Colors.green.shade400
                                    : const Color(0xFFFF9800);

                                return BarTooltipItem(
                                  '${data.prefecture}\n',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    height: 1.5,
                                  ),
                                  children: [
                                    TextSpan(
                                      text:
                                          '現職維持: ${data.incumbentRetentionTarget}\n',
                                      style: const TextStyle(
                                        color: Color(0xFF64B5F6),
                                        fontSize: 12,
                                        fontWeight: FontWeight.normal,
                                        height: 1.5,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          '新人擁立: ${data.newCandidateTarget}\n',
                                      style: TextStyle(
                                        color: newTargetColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.normal,
                                        height: 1.5,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          '純増割当: ${data.additionalSeatTarget}\n',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.normal,
                                        height: 1.5,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          '合計: ${data.incumbentRetentionTarget + data.newCandidateTarget}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() >= 0 &&
                                      value.toInt() <
                                          widget.prefectures.length) {
                                    final region = widget
                                        .prefectures[value.toInt()].prefecture;
                                    final displayRegion = region.length > 3
                                        ? region.substring(0, 2)
                                        : region;
                                    return SideTitleWidget(
                                      meta: meta,
                                      child: Text(
                                        displayRegion,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          height: 1.5,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    );
                                  }
                                  return SideTitleWidget(
                                    meta: meta,
                                    child: const SizedBox.shrink(),
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  return SideTitleWidget(
                                    meta: meta,
                                    child: Text(
                                      value.toInt().toString(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        height: 1.5,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          gridData: const FlGridData(
                            show: true,
                            drawVerticalLine: false,
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups:
                              widget.prefectures.asMap().entries.map((entry) {
                            final index = entry.key;
                            final data = entry.value;
                            final retainTarget =
                                data.incumbentRetentionTarget.toDouble();
                            final newTarget =
                                data.newCandidateTarget.toDouble();
                            final additionalTarget =
                                data.additionalSeatTarget.toDouble();
                            final isAchieved = additionalTarget > 0 &&
                                newTarget >= additionalTarget;
                            final newTargetColor = isAchieved
                                ? Colors.green.shade400
                                : const Color(0xFFFF9800);

                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: retainTarget + newTarget,
                                  width: 16,
                                  borderRadius: BorderRadius.circular(4),
                                  rodStackItems: [
                                    BarChartRodStackItem(
                                      0,
                                      retainTarget,
                                      const Color(0xFF64B5F6),
                                    ),
                                    BarChartRodStackItem(
                                      retainTarget,
                                      retainTarget + newTarget,
                                      newTargetColor,
                                    ),
                                  ],
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLegend(const Color(0xFF64B5F6), '現職維持目標'),
                        const SizedBox(width: 16),
                        _buildLegend(const Color(0xFFFF9800), '新人擁立目標 (未達)'),
                        const SizedBox(width: 16),
                        _buildLegend(Colors.green.shade400, '新人擁立目標 (達成)'),
                      ],
                    ),
                    const SizedBox(
                      height: 32,
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '月次公認内定 進捗状況',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    _buildMonthlyTable(sortedMonths, monthlyStats),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getMaxY() {
    double max = 0;
    for (final data in widget.prefectures) {
      final retain = data.incumbentRetentionTarget.toDouble();
      final newTarget = data.newCandidateTarget.toDouble();
      final total = retain + newTarget;
      if (total > max) {
        max = total;
      }
    }
    return max == 0 ? 10 : max * 1.2;
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(
          height: 4,
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  void _showMonthlyDetailsDialog(BuildContext context, String month) {
    final prefecturesInMonth = widget.prefectures
        .where((p) => p.endorsementDeadlineMonth == month)
        .toList();
    // 未確定の県連が上に来るようにソート
    prefecturesInMonth.sort((a, b) {
      if (a.endorsementConfirmed == b.endorsementConfirmed) {
        return a.prefecture.compareTo(b.prefecture);
      }
      return a.endorsementConfirmed ? 1 : -1;
    });

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$month 公認内定期限の県連一覧'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: prefecturesInMonth.length,
              itemBuilder: (context, index) {
                final p = prefecturesInMonth[index];
                return ListTile(
                  leading: Icon(
                    p.endorsementConfirmed
                        ? Icons.check_circle
                        : Icons.warning_amber_rounded,
                    color: p.endorsementConfirmed
                        ? Colors.green
                        : const Color(0xFFFF6B35),
                  ),
                  title: Text(
                    p.prefecture,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                  subtitle: Text(
                    '現職維持: ${p.incumbentRetentionTarget}名 / 新人擁立: ${p.newCandidateTarget}名',
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMonthlyTable(
    List<String> sortedMonths,
    Map<String, Map<String, int>> stats,
  ) {
    if (sortedMonths.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: DataTable(
          showCheckboxColumn: false,
          sortColumnIndex: _sortColumnIndex,
          sortAscending: _sortAscending,
          headingRowColor: WidgetStateProperty.all(const Color(0xFFECEFF1)),
          columns: [
            DataColumn(label: const Text('公認内定期限'), onSort: _onSort),
            DataColumn(
              label: const Text('対象県連数'),
              numeric: true,
              onSort: _onSort,
            ),
            DataColumn(
              label: const Text('確定済み'),
              numeric: true,
              onSort: _onSort,
            ),
            DataColumn(
              label: const Text('未確定'),
              numeric: true,
              onSort: _onSort,
            ),
            DataColumn(
              label: const Text('進捗率'),
              numeric: true,
              onSort: _onSort,
            ),
          ],
          rows: sortedMonths.map((month) {
            final s = stats[month]!;
            final total = s['total']!;
            final confirmed = s['confirmed']!;
            final unconfirmed = total - confirmed;
            final progress = total > 0
                ? (confirmed / total * 100).toStringAsFixed(1)
                : '0.0';

            return DataRow(
              onSelectChanged: (_) => _showMonthlyDetailsDialog(context, month),
              color: unconfirmed > 0
                  ? WidgetStateProperty.all(const Color(0xFFFFF8E1))
                  : (total > 0 && unconfirmed == 0)
                      ? WidgetStateProperty.all(Colors.green.shade50)
                      : null,
              cells: [
                DataCell(
                  Text(
                    month,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ),
                DataCell(Text(total.toString())),
                DataCell(
                  Text(
                    confirmed.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      height: 1.5,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    unconfirmed.toString(),
                    style: TextStyle(
                      color: unconfirmed > 0 ? Colors.red : null,
                      height: 1.5,
                    ),
                  ),
                ),
                DataCell(Text('$progress%')),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
