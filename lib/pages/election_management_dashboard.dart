import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

class ElectionManagementDashboard extends StatefulWidget {
  const ElectionManagementDashboard({super.key});

  @override
  State<ElectionManagementDashboard> createState() =>
      _ElectionManagementDashboardState();
}

class _ElectionManagementDashboardState
    extends State<ElectionManagementDashboard>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  // タブ: 月次工程管理 (KPI) / 最新実データ (AI取得) / 選挙スケジュール
  @override
  List<String> get tabUrlSlugs => const <String>[
        'kpi',
        'live-data',
        'schedule',
      ];

  @override
  TabController get tabUrlController => _tabController;

  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _politicians = [];
  Map<String, dynamic>? _monthlyKpi;
  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _timeSeriesData = [];
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchElectionData();
  }

  Future<void> _fetchElectionData() async {
    if (Supabase.instance.client.auth.currentUser == null) return;
    try {
      // Edge Function経由でAI検索・整形された最新の実データを取得
      final response = await Supabase.instance.client.functions.invoke(
        'ai-hub',
        body: {'action': 'election.analyze'},
      );
      final data = response.data;
      if (mounted && data != null) {
        final raw = data as Map<String, dynamic>;
        setState(() {
          _politicians = (raw['politicians'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .toList();
          _monthlyKpi = raw['monthlyKpi'] as Map<String, dynamic>?;
          _schedules = (raw['electionSchedules'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .toList();
          _timeSeriesData = (raw['timeSeriesData'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching election data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('統一地方選 700人倍増 KPI管理'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: '月次工程管理 (KPI)'),
            Tab(icon: Icon(Icons.people), text: '最新実データ (AI取得)'),
            Tab(icon: Icon(Icons.calendar_month), text: '選挙スケジュール'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildKpiTab(),
                _buildPoliticiansTab(),
                _buildSchedulesTab(),
              ],
            ),
    );
  }

  Widget _buildKpiTab() {
    if (_monthlyKpi == null) return const Center(child: Text('データがありません'));

    final regions = (_monthlyKpi!['regions'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF3A1010)
                : const Color(0xFFFFEBEE),
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFFEF9A9A)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '党全体必達目標',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE53935),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '現在の現職数: ${_monthlyKpi!['currentTotal']}人',
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  Text(
                    '必達目標数: ${_monthlyKpi!['targetTotal']}人',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                  const Divider(height: 24),
                  Text(
                    '必要な純増数: ${_monthlyKpi!['requiredAddition']}人',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE53935),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _monthlyKpi!['message'],
                    style: const TextStyle(
                      color: Color(0xFFE53935),
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '※万が一達成できなければ解党の覚悟で臨む“工程管理”の勝負です。',
                    style: TextStyle(
                      color: Color(0xFFE53935),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '地方議員数の推移と目標',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildTrendChart(),
          const SizedBox(height: 24),
          const Text(
            '都道府県連ごとの月次KPI配分',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.resolveWith<Color>(
                (Set<WidgetState> states) =>
                    Theme.of(context).colorScheme.surfaceContainerHigh,
              ),
              columns: const [
                DataColumn(
                  label: Text(
                    '都道府県',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    '現職維持目標',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    '必達目標',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    '新人擁立数',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    '接戦区支援回数',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    '公認内定時期',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
              rows: regions.map((region) {
                return DataRow(
                  cells: [
                    DataCell(Text(region['name']?.toString() ?? '')),
                    DataCell(Text(region['current']?.toString() ?? '')),
                    DataCell(Text(region['target']?.toString() ?? '')),
                    DataCell(Text(region['newCandidates']?.toString() ?? '')),
                    DataCell(Text(region['supportCount']?.toString() ?? '')),
                    DataCell(
                      Text(region['expectedEndorsement']?.toString() ?? ''),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart() {
    if (_timeSeriesData.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 800,
          barTouchData: const BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < _timeSeriesData.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _timeSeriesData[index]['label']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1.5,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barGroups: _timeSeriesData.asMap().entries.map((entry) {
            final count = (entry.value['count'] as num?)?.toDouble() ?? 0;
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: count,
                  color: count >= 700
                      ? const Color(0xFFE53935)
                      : const Color(0xFF3D5AFE),
                  width: 24,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
              showingTooltipIndicators: [0],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPoliticiansTab() {
    if (_politicians.isEmpty) return const Center(child: Text('議員データがありません'));

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _politicians.length,
      itemBuilder: (context, index) {
        final p = _politicians[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: p['gender'] == '女性'
                  ? const Color(0xFFF8BBD0)
                  : const Color(0xFFBBDEFB),
              child: Text(
                p['gender'] == '女性' ? '👩' : '👨',
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.5,
                ),
              ),
            ),
            title: Text('${p['name']} (${p['age']}歳) - ${p['gender']}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(
                  '${p['region']} ${p['municipality']} / ${p['type']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  p['profile']?.toString() ?? '',
                  style: const TextStyle(height: 1.3),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildSchedulesTab() {
    if (_schedules.isEmpty) return const Center(child: Text('スケジュールデータがありません'));

    final filteredSchedules = _schedules.where((s) {
      final dateStr = s['date']?.toString() ?? '';
      final parsedDate = DateTime.tryParse(dateStr);
      if (parsedDate == null) return false;
      return parsedDate.year == _selectedDate.year &&
          parsedDate.month == _selectedDate.month;
    }).toList();

    // 日付順にソート
    filteredSchedules.sort((a, b) {
      final aDateStr = a['date']?.toString() ?? '';
      final bDateStr = b['date']?.toString() ?? '';
      return aDateStr.compareTo(bDateStr);
    });

    return Column(
      children: [
        _buildCustomCalendar(),
        const Divider(),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: filteredSchedules.isEmpty
                ? Center(
                    key: ValueKey<String>(
                      'empty_${_selectedDate.year}_${_selectedDate.month}',
                    ),
                    child: const Text('選択した月の選挙スケジュールはありません'),
                  )
                : ListView.builder(
                    key: ValueKey<String>(
                      'list_${_selectedDate.year}_${_selectedDate.month}',
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: filteredSchedules.length,
                    itemBuilder: (context, index) {
                      final s = filteredSchedules[index];
                      final candidateCount =
                          s['dppCandidateCount'] as int? ?? 0;

                      Color? tileColor;
                      if (candidateCount == 0) {
                        tileColor = const Color(0xFFFFCDD2);
                      } else if (candidateCount == 1) {
                        tileColor = const Color(0xFFFFECB3);
                      } else if (candidateCount >= 2) {
                        tileColor = const Color(0xFFC8E6C9);
                      }

                      final sDateStr = s['date']?.toString() ?? '';
                      final sParsedDate = DateTime.tryParse(sDateStr);
                      final isSelectedDate = sParsedDate != null &&
                          sParsedDate.year == _selectedDate.year &&
                          sParsedDate.month == _selectedDate.month &&
                          sParsedDate.day == _selectedDate.day;

                      return Card(
                        color: tileColor,
                        margin: const EdgeInsets.only(bottom: 12.0),
                        shape: isSelectedDate
                            ? RoundedRectangleBorder(
                                side: const BorderSide(
                                  color: Color(0xFF3D5AFE),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              )
                            : null,
                        child: ListTile(
                          leading: const Icon(Icons.event),
                          title: Text(
                            '${s['electionName']} (${s['date']})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              height: 1.5,
                            ),
                          ),
                          subtitle: Text(
                            '${s['location']} - 国民民主党 候補者擁立数: $candidateCount人',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomCalendar() {
    final year = _selectedDate.year;
    final month = _selectedDate.month;
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final startWeekday = firstDay.weekday % 7; // Sunday = 0
    final totalDays = lastDay.day;
    final weeks = ((totalDays + startWeekday) / 7).ceil();

    final scheduleDates = <DateTime, int>{};
    for (var s in _schedules) {
      final dateStr = s['date']?.toString() ?? '';
      final parsedDate = DateTime.tryParse(dateStr);
      if (parsedDate != null) {
        final date =
            DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
        final candidateCount = s['dppCandidateCount'] as int? ?? 0;
        if (candidateCount > (scheduleDates[date] ?? -1)) {
          scheduleDates[date] = candidateCount;
        }
      }
    }

    const weekdays = ['日', '月', '火', '水', '木', '金', '土'];
    final now = DateTime.now();

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == 0) return;
        if (details.primaryVelocity! > 0) {
          // 右へスワイプ -> 前の月へ
          setState(() {
            _selectedDate = DateTime(year, month - 1, 1);
          });
        } else {
          // 左へスワイプ -> 次の月へ
          setState(() {
            _selectedDate = DateTime(year, month + 1, 1);
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _selectedDate = DateTime(year, month - 1, 1);
                    });
                  },
                ),
                Text(
                  '$year年 $month月',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _selectedDate = DateTime(year, month + 1, 1);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: weekdays
                  .map(
                    (w) => Expanded(
                      child: Center(
                        child: Text(
                          w,
                          style: const TextStyle(
                            color: Color(0xFFB0B0B0),
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeIn,
                switchOutCurve: Curves.easeOut,
                child: GridView.builder(
                  key: ValueKey<String>('calendar_grid_${year}_$month'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: weeks * 7,
                  itemBuilder: (context, index) {
                    final day = index - startWeekday + 1;
                    if (day < 1 || day > totalDays) {
                      return const SizedBox.shrink();
                    }
                    final currentDate = DateTime(year, month, day);
                    final isSelected = _selectedDate.year == year &&
                        _selectedDate.month == month &&
                        _selectedDate.day == day;
                    final isToday = now.year == year &&
                        now.month == month &&
                        now.day == day;
                    final candidateCount = scheduleDates[currentDate];
                    final hasSchedule = candidateCount != null;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDate = currentDate;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFBBDEFB)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: isToday
                              ? Border.all(color: const Color(0xFF3D5AFE))
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$day',
                              style: TextStyle(
                                fontWeight: isSelected || isToday
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                height: 1.5,
                              ),
                            ),
                            if (hasSchedule) ...[
                              const SizedBox(height: 2),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: candidateCount == 0
                                      ? const Color(0xFFE53935)
                                      : (candidateCount == 1
                                          ? const Color(0xFFFFC107)
                                          : const Color(0xFF4CAF50)),
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
