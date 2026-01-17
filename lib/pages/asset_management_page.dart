import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:math';

class AssetManagementPage extends StatefulWidget {
  const AssetManagementPage({super.key});

  @override
  _AssetManagementPageState createState() => _AssetManagementPageState();
}

class _AssetManagementPageState extends State<AssetManagementPage> {
  Map<String, TextEditingController> _controllers = {};
  List<String> _assetTypes = ['現金'];
  Map<String, Map<String, double>> _assetData = {};
  List<LineChartBarData> _chartBars = [];
  List<String> _sortedDates = [];

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
    _loadAssetTypes();
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  // #region Data Persistence
  Future<void> _loadAssetTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? assetTypes = prefs.getStringList('asset_types_v2');
    setState(() {
      _assetTypes = assetTypes ?? ['現金'];
      _initControllers();
      _loadAssetData();
    });
  }

  Future<void> _saveAssetTypes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('asset_types_v2', _assetTypes);
  }

  Future<void> _loadAssetData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? dataString = prefs.getString('asset_data_v2');
    if (dataString != null) {
      final Map<String, dynamic> decodedData = jsonDecode(dataString);
      setState(() {
        _assetData = decodedData.map((date, assets) {
          return MapEntry(
            date,
            (assets as Map<String, dynamic>)
                .map((k, v) => MapEntry(k, v.toDouble())),
          );
        });
        _updateChartData();
      });
    }
  }

  Future<void> _saveAssetData() async {
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final Map<String, double> todayData = {};
    bool hasData = false;
    _controllers.forEach((assetType, controller) {
      final double amount = double.tryParse(controller.text) ?? 0.0;
      if (controller.text.isNotEmpty) {
        todayData[assetType] = amount;
        hasData = true;
      }
    });

    if (!hasData) return;

    setState(() {
      // If there's no entry for today, create one
      if (!_assetData.containsKey(today)) {
        _assetData[today] = {};
      }
      // Update today's data with new values, keeping old ones if not entered
      _assetData[today]!.addAll(todayData);

      _updateChartData();
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('asset_data_v2', jsonEncode(_assetData));

    _controllers.forEach((_, controller) => controller.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('資産を登録しました。')),
    );
  }
  // #endregion

  void _initControllers() {
    _controllers.forEach((_, controller) => controller.dispose());
    _controllers = {
      for (var type in _assetTypes) type: TextEditingController(),
    };
  }

  void _addAssetType(String name) {
    if (name.isEmpty || _assetTypes.contains(name)) return;
    setState(() {
      _assetTypes.add(name);
      _initControllers();
      _saveAssetTypes();
    });
  }

  void _removeAssetType(String name) {
    setState(() {
      _assetTypes.remove(name);
      _controllers.remove(name)?.dispose();
      _assetData.forEach((date, assets) {
        assets.remove(name);
      });
      _initControllers();
      _saveAssetTypes();
      _updateChartData();
    });
  }

  void _updateChartData() {
    _sortedDates = _assetData.keys.toList()..sort();
    if (_sortedDates.isEmpty) {
      _chartBars = [];
      return;
    }

    final Map<String, List<FlSpot>> spotsData = {
      for (var type in _assetTypes) type: []
    };

    for (int i = 0; i < _sortedDates.length; i++) {
      final String date = _sortedDates[i];
      double cumulativeValue = 0;

      // Fill in missing values from the previous day
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
        cumulativeValue += _assetData[date]?[type] ?? 0;
        spotsData[type]!.add(FlSpot(i.toDouble(), cumulativeValue));
      }
    }

    _chartBars = _assetTypes
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final type = entry.value;
          final color = _colors[index % _colors.length];

          return LineChartBarData(
            spots: spotsData[type] ?? [],
            isCurved: false,
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withOpacity(0.5),
            ),
          );
        })
        .toList()
        .reversed
        .toList(); // Reversed for correct stacking order
  }

  // #region UI Building
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('資産管理'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildInputCard(),
            const SizedBox(height: 24),
            _buildChartCard(),
          ],
        ),
      ),
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
            const Text('今日の資産残高を登録',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ..._assetTypes.map((type) => _buildAssetInputRow(type)),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _showAddAssetDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('資産項目を追加'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveAssetData,
                icon: const Icon(Icons.save),
                label: const Text('登録'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
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

  Widget _buildAssetInputRow(String type) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controllers[type],
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: type,
                border: const OutlineInputBorder(),
                prefixIcon: Icon(_getIconForAsset(type)),
              ),
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

  Widget _buildChartCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('総資産推移',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _chartBars.isEmpty
                ? const Center(child: Text('登録データがありません。'))
                : SizedBox(
                    height: 300,
                    child: LineChart(
                      LineChartData(
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: _getTooltipItems,
                          ),
                          handleBuiltInTouches: true,
                        ),
                        gridData: const FlGridData(show: true),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 70,
                                  getTitlesWidget: _leftTitleWidgets)),
                          bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  getTitlesWidget: _bottomTitleWidgets,
                                  interval: max(
                                      1,
                                      (_sortedDates.length / 5)
                                          .floor()
                                          .toDouble()))),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: true),
                        lineBarsData: _chartBars,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
  // #endregion

  // #region Dialogs
  void _showAddAssetDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('資産項目を追加'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '資産名 (例: 銀行A)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () {
              _addAssetType(controller.text);
              Navigator.pop(context);
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  void _showRemoveAssetDialog(String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('「$type」を削除'),
        content: const Text('この資産項目と関連するすべてのデータを削除しますか？この操作は元に戻せません。'),
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
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
  // #endregion

  // #region Chart Helpers
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
      child: Text(format.format(value), style: const TextStyle(fontSize: 10)),
    );
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
      LineTooltipItem(
        '$formattedDate\n',
        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      LineTooltipItem(
        '総資産: $formattedTotal\n',
        const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    ];

    final sortedAssets = assetsOnDate.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (var entry in sortedAssets) {
      final color = _colors[_assetTypes.indexOf(entry.key) % _colors.length];
      final formattedValue =
          NumberFormat.simpleCurrency(locale: 'ja_JP').format(entry.value);
      tooltips.add(
        LineTooltipItem(
          '${entry.key}: $formattedValue',
          TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      );
    }

    return tooltips;
  }
  // #endregion
}
