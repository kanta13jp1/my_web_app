import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

class FinancialReportPage extends StatefulWidget {
  const FinancialReportPage({super.key});

  @override
  State<FinancialReportPage> createState() => _FinancialReportPageState();
}

class _FinancialReportPageState extends State<FinancialReportPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  // タブ: 日次 / 週次 / 月次
  @override
  List<String> get tabUrlSlugs => const <String>['daily', 'weekly', 'monthly'];

  @override
  TabController get tabUrlController => _tabController;

  late TabController _tabController;
  Map<String, Map<String, double>> _assetData = {};
  List<String> _sortedDates = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAssetData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAssetData() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      final data = await client
          .from('cfo_assets')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);
      final Map<String, Map<String, double>> loaded = {};
      for (final item in data) {
        final dt = DateTime.tryParse(item['created_at']?.toString() ?? '');
        if (dt == null) continue;
        final dateKey = DateFormat('yyyy-MM-dd').format(dt.toLocal());
        final title = item['title']?.toString() ?? '';
        final amount = (item['amount'] as num?)?.toDouble() ?? 0;
        loaded.putIfAbsent(dateKey, () => {})[title] = amount;
      }
      if (!mounted) return;
      setState(() {
        _assetData = loaded;
        _sortedDates = loaded.keys.toList()..sort();
      });
    } catch (e) {
      debugPrint('FinancialReportPage load error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('決算レポート'),
        backgroundColor: const Color(0xFF388E3C),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: '日次'),
            Tab(text: '週次'),
            Tab(text: '月次'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReportView(ReportPeriod.daily),
          _buildReportView(ReportPeriod.weekly),
          _buildReportView(ReportPeriod.monthly),
        ],
      ),
    );
  }

  Widget _buildReportView(ReportPeriod period) {
    if (_sortedDates.isEmpty) {
      return const Center(child: Text('データがありません。'));
    }

    final now = DateTime.now();
    final reportData = _calculateReportData(period, now);

    if (reportData == null) {
      return const Center(child: Text('レポートを生成するための十分なデータがありません。'));
    }

    final formatter = NumberFormat.simpleCurrency(locale: 'ja_JP');
    final diff = reportData.endBalance - reportData.startBalance;
    final percentage = reportData.startBalance != 0
        ? (diff / reportData.startBalance) * 100
        : 0.0;
    final diffColor =
        diff >= 0 ? const Color(0xFF4CAF50) : const Color(0xFFE53935);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            reportData.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryCard(formatter, reportData, diff, diffColor, percentage),
          const SizedBox(height: 24),
          _buildChartCard(reportData, period),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    NumberFormat formatter,
    ReportData data,
    double diff,
    Color diffColor,
    double percentage,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSummaryRow('開始残高', formatter.format(data.startBalance)),
            _buildSummaryRow('終了残高', formatter.format(data.endBalance)),
            const Divider(height: 24),
            _buildSummaryRow(
              '増減額',
              '${diff >= 0 ? '+' : ''}${formatter.format(diff)}',
              valueColor: diffColor,
            ),
            _buildSummaryRow(
              '増減率',
              '${percentage.toStringAsFixed(2)}%',
              valueColor: diffColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String title, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFFB0B0B0),
              height: 1.7,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: valueColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(ReportData data, ReportPeriod period) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '総資産推移',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final date = data.chartSpots[groupIndex].date;
                        final formattedDate = period == ReportPeriod.monthly
                            ? DateFormat('d').format(date)
                            : DateFormat.E('ja').format(date);
                        final value = NumberFormat.compact(locale: 'ja_JP')
                            .format(rod.toY);
                        return BarTooltipItem(
                          '$formattedDate\n$value',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(
                            NumberFormat.compact(locale: 'ja_JP').format(value),
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) =>
                            _getBottomTitle(value, meta, data, period),
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData:
                      const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  barGroups: data.chartSpots.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.total,
                          color: const Color(0xFF4CAF50),
                          width: 16,
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getBottomTitle(
    double value,
    TitleMeta meta,
    ReportData data,
    ReportPeriod period,
  ) {
    String text = '';
    final spot = data.chartSpots[value.toInt()];
    switch (period) {
      case ReportPeriod.daily:
      case ReportPeriod.weekly:
        text = DateFormat.E('ja').format(spot.date);
        break;
      case ReportPeriod.monthly:
        text = DateFormat('d').format(spot.date);
        break;
    }
    return SideTitleWidget(
      meta: meta,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          height: 1.5,
        ),
      ),
    );
  }

  // #region Report Logic
  ReportData? _calculateReportData(ReportPeriod period, DateTime now) {
    DateTime startOfPeriod;
    DateTime endOfPeriod;
    String title;

    switch (period) {
      case ReportPeriod.daily:
        endOfPeriod = DateTime(now.year, now.month, now.day);
        startOfPeriod = endOfPeriod.subtract(const Duration(days: 1));
        title = '${DateFormat.yMMMd('ja').format(endOfPeriod)} 日次レポート';
        break;
      case ReportPeriod.weekly:
        endOfPeriod = DateTime(now.year, now.month, now.day);
        startOfPeriod =
            endOfPeriod.subtract(Duration(days: now.weekday)); // Sunday
        title =
            '${DateFormat.yMMMd('ja').format(startOfPeriod)} - ${DateFormat.yMMMd('ja').format(endOfPeriod)} 週次レポート';
        break;
      case ReportPeriod.monthly:
        endOfPeriod = DateTime(now.year, now.month, now.day);
        startOfPeriod = DateTime(now.year, now.month, 1);
        title = '${DateFormat.yMMM('ja').format(now)} 月次レポート';
        break;
    }

    final dataInRange = _getDataForPeriod(startOfPeriod, endOfPeriod);
    if (dataInRange.isEmpty) return null;

    final startBalance = _getTotalForDate(dataInRange.entries.first.key);
    final endBalance = _getTotalForDate(dataInRange.entries.last.key);

    final List<ChartSpot> spots = [];
    DateTime currentDate = startOfPeriod;
    while (currentDate.isBefore(endOfPeriod) ||
        currentDate.isAtSameMomentAs(endOfPeriod)) {
      spots.add(
        ChartSpot(
          date: currentDate,
          total: _getTotalForDate(DateFormat('yyyy-MM-dd').format(currentDate)),
        ),
      );
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return ReportData(
      title: title,
      startBalance: startBalance,
      endBalance: endBalance,
      chartSpots: spots,
    );
  }

  Map<String, Map<String, double>> _getDataForPeriod(
    DateTime start,
    DateTime end,
  ) {
    final Map<String, Map<String, double>> periodData = {};
    for (var dateStr in _sortedDates) {
      final date = DateTime.parse(dateStr);
      if ((date.isAfter(start) || date.isAtSameMomentAs(start)) &&
          (date.isBefore(end) || date.isAtSameMomentAs(end))) {
        periodData[dateStr] = _assetData[dateStr]!;
      }
    }
    return periodData;
  }

  double _getTotalForDate(String dateStr) {
    double total = 0;

    String? effectiveDate = dateStr;
    if (!_assetData.containsKey(effectiveDate)) {
      // Find the closest previous date with data
      effectiveDate = _sortedDates.lastWhere(
        (d) => d.compareTo(dateStr) <= 0,
        orElse: () => '',
      );
      if (effectiveDate.isEmpty) return 0;
    }

    _assetData[effectiveDate]?.forEach((_, value) {
      total += value;
    });
    return total;
  }
  // #endregion
}

enum ReportPeriod { daily, weekly, monthly }

class ReportData {
  final String title;
  final double startBalance;
  final double endBalance;
  final List<ChartSpot> chartSpots;

  ReportData({
    required this.title,
    required this.startBalance,
    required this.endBalance,
    required this.chartSpots,
  });
}

class ChartSpot {
  final DateTime date;
  final double total;
  ChartSpot({required this.date, required this.total});
}
