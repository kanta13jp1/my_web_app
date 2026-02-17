import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class AssetManagementPage extends StatefulWidget {
  const AssetManagementPage({super.key});

  @override
  _AssetManagementPageState createState() => _AssetManagementPageState();
}

class _AssetManagementPageState extends State<AssetManagementPage> {
  final _supabase = Supabase.instance.client;

  // 既存の変数
  Map<String, TextEditingController> _controllers = {};
  List<String> _assetTypes = ['現金'];
  Map<String, Map<String, double>> _assetData = {};

  // グラフデータ
  List<LineChartBarData> _lineChartBars = []; // 資産推移用
  List<BarChartGroupData> _barChartGroups = []; // 日次損益用
  double _maxDailyChange = 0; // 棒グラフのスケール用

  List<String> _sortedDates = [];
  Map<String, String?> _lastUpdatedDates = {};

  // 表示モード
  bool _isStacked = true; // 積み上げ(合計) vs 個別
  bool _showDailyChange = false; // 資産推移(Line) vs 日次損益(Bar)

  // 富の攻防戦用State
  int _todayDefended = 0;
  int _todayConquered = 0;
  bool _isLoadingStruggle = false;

  final List<Color> _colors = [
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
    Colors.cyan,
    Colors.brown,
  ];

  @override
  void initState() {
    super.initState();
    _loadDataFromSupabase();
    _fetchTodayStruggleData();
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  // #region Data Persistence
  Future<void> _loadDataFromSupabase() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await _supabase
          .from('cfo_assets')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);
      final Map<String, Map<String, double>> loadedData = {};
      final Set<String> loadedTypes = {'現金'};
      for (var item in data) {
        final DateTime createdAt = DateTime.parse(item['created_at']).toLocal();
        final String dateKey = DateFormat('yyyy-MM-dd').format(createdAt);
        final String title = item['title'];
        final double amount = (item['amount'] as num).toDouble();
        loadedTypes.add(title);
        if (!loadedData.containsKey(dateKey)) {
          loadedData[dateKey] = {};
        }
        loadedData[dateKey]![title] = amount;
      }
      if (mounted) {
        setState(() {
          _assetTypes = loadedTypes.toList();
          _assetData = loadedData;
          _initControllers();
          _updateChartData();
          _updateLastUpdatedDates();
        });
      }
    } catch (e) {
      debugPrint('Error loading assets: $e');
    }
  }

  Future<void> _saveAssetData() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final Map<String, double> todayData = {};
    bool hasData = false;

    _controllers.forEach((assetType, controller) {
      if (controller.text.isNotEmpty) {
        final cleanText = controller.text.replaceAll(',', '');
        final double amount = double.tryParse(cleanText) ?? 0.0;
        todayData[assetType] = amount;
        hasData = true;
      }
    });

    if (!hasData) return;

    try {
      for (var entry in todayData.entries) {
        await _supabase.from('cfo_assets').insert({
          'user_id': userId,
          'title': entry.key,
          'amount': entry.value,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      setState(() {
        if (!_assetData.containsKey(today)) _assetData[today] = {};
        _assetData[today]!.addAll(todayData);
        _updateChartData();
        _updateLastUpdatedDates();
      });
      _controllers.forEach((_, controller) => controller.clear());
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('戦況を記録しました。')));
    } catch (e) {
      debugPrint('Error saving assets: $e');
    }
  }

  Future<void> _removeAssetType(String name) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase
          .from('cfo_assets')
          .delete()
          .eq('user_id', userId)
          .eq('title', name);
      setState(() {
        _assetTypes.remove(name);
        _controllers.remove(name)?.dispose();
        _assetData.forEach((date, assets) {
          assets.remove(name);
        });
        _initControllers();
        _updateChartData();
        _updateLastUpdatedDates();
      });
    } catch (e) {
      debugPrint('Error deleting asset type: $e');
    }
  }
  // #endregion

  // #region Struggle Logic
  Future<void> _fetchTodayStruggleData() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _isLoadingStruggle = true);
    try {
      final now = DateTime.now();
      final startOfDay =
          DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59)
          .toUtc()
          .toIso8601String();

      final data = await _supabase
          .from('wealth_struggles')
          .select('action_type, amount')
          .eq('user_id', userId)
          .gte('occurred_at', startOfDay)
          .lte('occurred_at', endOfDay);

      int defended = 0;
      int conquered = 0;
      for (var item in data) {
        final amount = item['amount'] as int;
        if (item['action_type'] == 'defend') {
          defended += amount;
        } else {
          conquered += amount;
        }
      }
      if (mounted) {
        setState(() {
          _todayDefended = defended;
          _todayConquered = conquered;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingStruggle = false);
    }
  }

  void _showStruggleDialog(String actionType) {
    final isDefend = actionType == 'defend';
    final title = isDefend ? '富の防衛 (節約)' : '富の奪取 (稼ぎ)';
    final amountController = TextEditingController();
    final memoController = TextEditingController();
    final color = isDefend ? Colors.blue[800]! : Colors.orange[800]!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title,
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isDefend
                    ? '1円を節約した＝1円の富を守り切った。\n敵から富を死守せよ。'
                    : '1円稼いだ＝誰かの富を奪った。\n市場から富を奪取せよ。',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '金額 (円)',
                  prefixIcon: Icon(Icons.currency_yen, color: color),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: memoController,
                decoration: const InputDecoration(
                  labelText: '戦況詳細 (例: コンビニ回避)',
                  prefixIcon: Icon(Icons.notes),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('撤退')),
          ElevatedButton.icon(
            onPressed: () async {
              final amountStr = amountController.text.replaceAll(',', '');
              final amount = int.tryParse(amountStr);
              if (amount == null || amount <= 0) return;
              Navigator.pop(context);
              await _recordStruggle(actionType, amount, memoController.text);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: color, foregroundColor: Colors.white),
            icon: Icon(isDefend ? Icons.shield : Icons.colorize),
            label: Text(isDefend ? '死守する' : '奪取する'),
          ),
        ],
      ),
    );
  }

  Future<void> _recordStruggle(
      String actionType, int amount, String description) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('wealth_struggles').insert({
        'user_id': userId,
        'action_type': actionType,
        'amount': amount,
        'description': description.isEmpty ? null : description,
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
      });
      await _fetchTodayStruggleData();
      if (mounted) {
        final isDefend = actionType == 'defend';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(isDefend ? '¥$amount の富を死守しました。' : '¥$amount の富を奪取しました。'),
          backgroundColor: isDefend ? Colors.blue[800] : Colors.orange[800],
        ));
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }
  // #endregion

  // #region Logic Helpers
  void _initControllers() {
    final newControllers = <String, TextEditingController>{};
    for (var type in _assetTypes) {
      if (_controllers.containsKey(type)) {
        newControllers[type] = _controllers[type]!;
      } else {
        newControllers[type] = TextEditingController();
      }
    }
    _controllers = newControllers;
  }

  void _addAssetType(String name) {
    if (name.isEmpty || _assetTypes.contains(name)) return;
    setState(() {
      _assetTypes.add(name);
      _initControllers();
      _updateLastUpdatedDates();
    });
  }

  void _updateLastUpdatedDates() {
    _lastUpdatedDates = {};
    final sortedDates = _assetData.keys.toList()..sort();
    for (var type in _assetTypes) {
      String? lastDate;
      for (var date in sortedDates.reversed) {
        if (_assetData[date]?.containsKey(type) ?? false) {
          lastDate = date;
          break;
        }
      }
      _lastUpdatedDates[type] = lastDate;
    }
  }

  // ★ 戦況分析データの作成（グラフ用）
  void _updateChartData() {
    _sortedDates = _assetData.keys.toList()..sort();
    if (_sortedDates.isEmpty) {
      _lineChartBars = [];
      _barChartGroups = [];
      return;
    }

    // 1. 資産推移データ (Line Chart) の作成
    final Map<String, List<FlSpot>> spotsData = {
      for (var type in _assetTypes) type: [],
    };

    // 日ごとの合計資産を計算（損益計算用）
    List<double> dailyTotals = [];

    for (int i = 0; i < _sortedDates.length; i++) {
      final String date = _sortedDates[i];
      double currentDayTotal = 0; // その日の合計
      double cumulativeValue = 0; // 積み上げグラフ用

      // 前日データの補完
      if (i > 0) {
        final prevDate = _sortedDates[i - 1];
        for (var type in _assetTypes) {
          if (!_assetData[date]!.containsKey(type) &&
              _assetData[prevDate]!.containsKey(type)) {
            _assetData[date]![type] = _assetData[prevDate]![type]!;
          }
        }
      }

      for (var type in _assetTypes) {
        final double value = _assetData[date]?[type] ?? 0;
        currentDayTotal += value;

        if (_isStacked) {
          cumulativeValue += value;
          spotsData[type]!.add(FlSpot(i.toDouble(), cumulativeValue));
        } else {
          spotsData[type]!.add(FlSpot(i.toDouble(), value));
        }
      }
      dailyTotals.add(currentDayTotal);
    }

    _lineChartBars = _assetTypes
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final type = entry.value;
          final color = _colors[index % _colors.length];
          final spots = spotsData[type] ?? [];
          if (spots.isEmpty) return null;

          return LineChartBarData(
            spots: spots,
            isCurved: false,
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: _isStacked,
              color: color.withOpacity(0.5),
            ),
          );
        })
        .whereType<LineChartBarData>()
        .toList();

    if (_isStacked) {
      _lineChartBars = _lineChartBars.reversed.toList();
    }

    // 2. 日次損益データ (Bar Chart) の作成
    _barChartGroups = [];
    _maxDailyChange = 0;

    for (int i = 0; i < dailyTotals.length; i++) {
      double diff = 0;
      if (i > 0) {
        diff = dailyTotals[i] - dailyTotals[i - 1];
      }

      // 最大値更新（グラフスケール用）
      if (diff.abs() > _maxDailyChange) {
        _maxDailyChange = diff.abs();
      }

      // 勝てば緑(富の奪取)、負ければ赤(富の喪失)
      final color = diff >= 0 ? Colors.green : Colors.red;

      _barChartGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: diff,
              color: color,
              width: 12,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }
    // スケールに余裕を持たせる
    if (_maxDailyChange == 0) _maxDailyChange = 1000;
    _maxDailyChange *= 1.2;
  }
  // #endregion

  // #region UI Building
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('資産管理闘争'),
        backgroundColor: const Color(0xFF1B5E20), // 深い緑（軍事的）
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.blueGrey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildStruggleCard(),
            const SizedBox(height: 24),
            _buildChartCard(), // ここが戦況マップの核
            const SizedBox(height: 16),
            if (!_showDailyChange) _buildLegendCard(), // 資産推移の時だけ内訳表示
            const SizedBox(height: 24),
            _buildInputCard(),
          ],
        ),
      ),
    );
  }

  // 戦況分析カード（グラフ）
  Widget _buildChartCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _showDailyChange ? '戦果レポート (日次損益)' : '戦略マップ (資産推移)',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _showDailyChange ? '昨日の自分に勝ったか？' : '国力(富)の総量は増えているか？',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                // モード切替
                Row(
                  children: [
                    const Icon(Icons.show_chart, size: 16),
                    Switch(
                      value: _showDailyChange,
                      activeColor: Colors.redAccent,
                      onChanged: (value) {
                        setState(() {
                          _showDailyChange = value;
                          // 棒グラフモードになったら、折れ線の積み上げはデフォルトに戻す等の調整も可
                        });
                      },
                    ),
                    const Icon(Icons.bar_chart, size: 16),
                  ],
                ),
              ],
            ),
            // 資産推移モードの時のみ、合計/個別の切り替えを表示
            if (!_showDailyChange)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('個別', style: TextStyle(fontSize: 10)),
                  Switch(
                    value: _isStacked,
                    activeColor: Colors.green,
                    onChanged: (value) {
                      setState(() {
                        _isStacked = value;
                        _updateChartData();
                      });
                    },
                  ),
                  const Text('合計', style: TextStyle(fontSize: 10)),
                ],
              ),

            const SizedBox(height: 24),

            // グラフエリア
            SizedBox(
              height: 300,
              child: _lineChartBars.isEmpty && _barChartGroups.isEmpty
                  ? const Center(child: Text('戦況データなし。記録を開始せよ。'))
                  : _showDailyChange
                      ? _buildDailyChangeChart() // 棒グラフ (日次損益)
                      : _buildAssetTrendChart(), // 折れ線グラフ (資産推移)
            ),
          ],
        ),
      ),
    );
  }

  // 折れ線グラフ（資産推移）
  Widget _buildAssetTrendChart() {
    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: _getTooltipItems,
          ),
          handleBuiltInTouches: true,
        ),
        gridData: const FlGridData(show: true),
        titlesData: _buildChartTitles(),
        borderData:
            FlBorderData(show: true, border: Border.all(color: Colors.black12)),
        lineBarsData: _lineChartBars,
      ),
    );
  }

  // 棒グラフ（日次損益）
  Widget _buildDailyChangeChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _maxDailyChange,
        minY: -_maxDailyChange,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final dateIndex = group.x.toInt();
              final dateStr = dateIndex < _sortedDates.length
                  ? _sortedDates[dateIndex]
                  : '';
              final date = dateStr.isNotEmpty
                  ? DateFormat('MM/dd').format(DateTime.parse(dateStr))
                  : '';
              final val =
                  NumberFormat.simpleCurrency(locale: 'ja_JP', decimalDigits: 0)
                      .format(rod.toY);
              return BarTooltipItem(
                '$date\n$val',
                TextStyle(
                    color: rod.toY >= 0
                        ? Colors.lightGreenAccent
                        : Colors.redAccent,
                    fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: _buildChartTitles(), // 共通のタイトル設定を使用
        gridData: FlGridData(
          show: true,
          checkToShowHorizontalLine: (value) => value == 0, // 0ラインを強調
          getDrawingHorizontalLine: (value) {
            if (value == 0)
              return const FlLine(color: Colors.black54, strokeWidth: 1);
            return const FlLine(color: Colors.black12, strokeWidth: 1);
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: _barChartGroups,
      ),
    );
  }

  FlTitlesData _buildChartTitles() {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 50,
          getTitlesWidget: _leftTitleWidgets,
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          getTitlesWidget: _bottomTitleWidgets,
          interval: max(1, (_sortedDates.length / 5).floor().toDouble()),
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  // ▼ 富の攻防戦UI
  Widget _buildStruggleCard() {
    final currencyFormat =
        NumberFormat.simpleCurrency(locale: 'ja_JP', decimalDigits: 0);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey[900]!, Colors.blueGrey[800]!],
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '人生とは富の奪い合いである。',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '毎日1円を守るために必死で生き、1円を奪うために必死で生きなければならない。',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontStyle: FontStyle.italic),
            ),
            const Divider(color: Colors.white24, height: 24),
            _isLoadingStruggle
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStruggleScore(
                        title: '今日の防衛 (節約)',
                        amount: currencyFormat.format(_todayDefended),
                        icon: Icons.shield,
                        color: Colors.blueAccent,
                      ),
                      _buildStruggleScore(
                        title: '今日の奪取 (稼ぎ)',
                        amount: currencyFormat.format(_todayConquered),
                        icon: Icons.colorize,
                        color: Colors.orangeAccent,
                      ),
                    ],
                  ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showStruggleDialog('defend'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.shield_outlined),
                    label: const Text('1円を死守する'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showStruggleDialog('conquer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[900],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.colorize_outlined),
                    label: const Text('1円を奪取する'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStruggleScore(
      {required String title,
      required String amount,
      required IconData icon,
      required Color color}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(title,
            style: TextStyle(color: color.withOpacity(0.8), fontSize: 12)),
        Text(amount,
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildInputCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '現状確認 (残高更新)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              '現実を直視せよ。数値は嘘をつかない。',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ..._assetTypes.map((type) => _buildAssetInputRow(type)),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _showAddAssetDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('管理項目を追加'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveAssetData,
                icon: const Icon(Icons.save),
                label: const Text('戦況を更新する'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... (_buildAssetInputRow, _buildLastUpdatedText, _buildLegendCard, _showAddAssetDialog, _showRemoveAssetDialog, Helpers は変更なし) ...
  // コード長削減のため、以下は既存ロジックを維持してコピーしてください。
  // ただし、_buildLegendCard, _buildAssetInputRow, _buildLastUpdatedText, _showAddAssetDialog, _showRemoveAssetDialog,
  // _getIconForAsset, _bottomTitleWidgets, _leftTitleWidgets, _getTooltipItems は元のままで動作します。
  // ここでは完全性のため記述します。

  Widget _buildAssetInputRow(String type) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _controllers[type],
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: InputDecoration(
                    labelText: type,
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(_getIconForAsset(type)),
                  ),
                ),
                const SizedBox(height: 4),
                _buildLastUpdatedText(type),
              ],
            ),
          ),
          if (type != '現金')
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              onPressed: () => _showRemoveAssetDialog(type),
            ),
        ],
      ),
    );
  }

  Widget _buildLastUpdatedText(String type) {
    final lastDateStr = _lastUpdatedDates[type];
    if (lastDateStr == null)
      return const Text('  データなし',
          style: TextStyle(color: Colors.grey, fontSize: 12));
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (lastDateStr == todayStr)
      return const Text('  本日更新済み',
          style: TextStyle(
              color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold));
    final formattedDate =
        DateFormat('yyyy/MM/dd').format(DateTime.parse(lastDateStr));
    return Text('  最終更新: $formattedDate',
        style: const TextStyle(color: Colors.grey, fontSize: 12));
  }

  Widget _buildLegendCard() {
    if (_sortedDates.isEmpty) return const SizedBox.shrink();
    final latestDate = _sortedDates.last;
    final latestData = _assetData[latestDate] ?? {};
    final sortedAssets = _assetTypes.toList()
      ..sort((a, b) => (latestData[b] ?? 0).compareTo(latestData[a] ?? 0));

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('内訳 (戦力分析)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: sortedAssets.asMap().entries.map((entry) {
                final type = entry.value;
                final originalIndex = _assetTypes.indexOf(type);
                final color = _colors[originalIndex % _colors.length];
                final value = latestData[type] ?? 0;
                final formattedValue =
                    NumberFormat.simpleCurrency(locale: 'ja_JP').format(value);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text('$type: $formattedValue',
                        style: TextStyle(
                            fontSize: 13,
                            color: value < 0 ? Colors.red : Colors.black)),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAssetDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('資産項目を追加'),
        content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: '資産名')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル')),
          ElevatedButton(
              onPressed: () {
                _addAssetType(controller.text);
                Navigator.pop(context);
              },
              child: const Text('追加')),
        ],
      ),
    );
  }

  void _showRemoveAssetDialog(String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('「$type」を削除'),
        content: const Text('この項目を削除しますか？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル')),
          ElevatedButton(
              onPressed: () {
                _removeAssetType(type);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('削除')),
        ],
      ),
    );
  }

  IconData _getIconForAsset(String type) {
    if (type.contains('現金')) return Icons.wallet;
    if (type.contains('銀行')) return Icons.account_balance;
    if (type.contains('証券')) return Icons.trending_up;
    if (type.contains('カード')) return Icons.credit_card;
    return Icons.monetization_on;
  }

  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(fontSize: 10);
    String text = '';
    if (value.toInt() < _sortedDates.length) {
      text = DateFormat('MM/dd')
          .format(DateTime.parse(_sortedDates[value.toInt()]));
    }
    return SideTitleWidget(
        axisSide: meta.axisSide, child: Text(text, style: style));
  }

  Widget _leftTitleWidgets(double value, TitleMeta meta) {
    final format = NumberFormat.compact(locale: 'ja_JP');
    return SideTitleWidget(
        axisSide: meta.axisSide,
        space: 8,
        child:
            Text(format.format(value), style: const TextStyle(fontSize: 10)));
  }

  List<LineTooltipItem> _getTooltipItems(List<LineBarSpot> spots) {
    final dateIndex = spots.first.spotIndex;
    if (dateIndex >= _sortedDates.length) return [];
    final date = _sortedDates[dateIndex];
    final assetsOnDate = _assetData[date]!;
    double total = 0;
    assetsOnDate.forEach((_, value) => total += value);
    final formattedDate = DateFormat('yyyy/MM/dd').format(DateTime.parse(date));
    final formattedTotal =
        NumberFormat.simpleCurrency(locale: 'ja_JP').format(total);

    final tooltips = <LineTooltipItem>[
      LineTooltipItem('$formattedDate\n',
          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      if (_isStacked)
        LineTooltipItem(
            '総資産: $formattedTotal\n',
            const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
    ];
    final sortedAssets = assetsOnDate.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (var entry in sortedAssets) {
      final color = _colors[_assetTypes.indexOf(entry.key) % _colors.length];
      final formattedValue =
          NumberFormat.simpleCurrency(locale: 'ja_JP').format(entry.value);
      tooltips.add(LineTooltipItem('${entry.key}: $formattedValue',
          TextStyle(color: color, fontWeight: FontWeight.bold)));
    }
    return tooltips;
  }
}
