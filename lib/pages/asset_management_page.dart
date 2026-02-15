import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Supabase追加
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class AssetManagementPage extends StatefulWidget {
  const AssetManagementPage({super.key});

  @override
  _AssetManagementPageState createState() => _AssetManagementPageState();
}

class _AssetManagementPageState extends State<AssetManagementPage> {
  final _supabase = Supabase.instance.client; // Supabaseクライアント

  Map<String, TextEditingController> _controllers = {};
  List<String> _assetTypes = ['現金'];
  Map<String, Map<String, double>> _assetData = {};
  List<LineChartBarData> _chartBars = [];
  List<String> _sortedDates = [];

  Map<String, String?> _lastUpdatedDates = {};

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
    _loadDataFromSupabase(); // 起動時にデータをロード
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  // #region Data Persistence (Supabase)

  // データを読み込み、資産項目と履歴データを構築する
  Future<void> _loadDataFromSupabase() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // 全データを取得し、日付順に並べる
      final data = await _supabase
          .from('cfo_assets')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      final Map<String, Map<String, double>> loadedData = {};
      final Set<String> loadedTypes = {'現金'}; // デフォルト

      for (var item in data) {
        final DateTime createdAt = DateTime.parse(item['created_at']).toLocal();
        final String dateKey = DateFormat('yyyy-MM-dd').format(createdAt);
        final String title = item['title'];
        final double amount = (item['amount'] as num).toDouble();

        loadedTypes.add(title);

        if (!loadedData.containsKey(dateKey)) {
          loadedData[dateKey] = {};
        }
        // 同じ日に複数データがある場合は最新（リストの後ろ）が上書きされる
        loadedData[dateKey]![title] = amount;
      }

      if (mounted) {
        setState(() {
          _assetTypes = loadedTypes.toList();
          _assetData = loadedData;
          _initControllers(); // 入力欄を更新
          _updateChartData();
          _updateLastUpdatedDates();
        });
      }
    } catch (e) {
      debugPrint('Error loading assets: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('データ読み込みエラー: $e')),
        );
      }
    }
  }

  // データを保存する（追記形式）
  Future<void> _saveAssetData() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final Map<String, double> todayData = {};
    bool hasData = false;

    // 入力があるものだけ抽出
    _controllers.forEach((assetType, controller) {
      if (controller.text.isNotEmpty) {
        final double amount = double.tryParse(controller.text) ?? 0.0;
        todayData[assetType] = amount;
        hasData = true;
      }
    });

    if (!hasData) return;

    try {
      // Supabaseにインサート (ログ形式で追記)
      for (var entry in todayData.entries) {
        await _supabase.from('cfo_assets').insert({
          'user_id': userId,
          'title': entry.key,
          'amount': entry.value,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      setState(() {
        if (!_assetData.containsKey(today)) {
          _assetData[today] = {};
        }
        _assetData[today]!.addAll(todayData);
        _updateChartData();
        _updateLastUpdatedDates();
      });

      // 入力欄をクリア
      _controllers.forEach((_, controller) => controller.clear());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('資産を登録しました。')),
        );
      }
    } catch (e) {
      debugPrint('Error saving assets: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存エラー: $e')),
        );
      }
    }
  }

  // 資産項目を削除する（Supabaseからも削除）
  Future<void> _removeAssetType(String name) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Supabaseから該当タイトルのデータを全て削除
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「$name」を削除しました')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting asset type: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除エラー: $e')),
        );
      }
    }
  }

  // #endregion

  // #region Logic Helpers
  void _initControllers() {
    // 既存のコントローラーを保持しつつ、足りないものを追加、不要なものを削除
    final newControllers = <String, TextEditingController>{};
    for (var type in _assetTypes) {
      if (_controllers.containsKey(type)) {
        newControllers[type] = _controllers[type]!;
      } else {
        newControllers[type] = TextEditingController();
      }
    }
    // 不要になったコントローラーを破棄
    _controllers.forEach((key, controller) {
      if (!newControllers.containsKey(key)) {
        controller.dispose();
      }
    });
    _controllers = newControllers;
  }

  void _addAssetType(String name) {
    if (name.isEmpty || _assetTypes.contains(name)) return;
    setState(() {
      _assetTypes.add(name);
      _initControllers();
      // Supabaseへの保存は、実際に金額を入れて「登録」ボタンを押したときに行われるため
      // ここではUI上のリストに追加するだけでOK
      _updateLastUpdatedDates();
    });
  }

  void _updateLastUpdatedDates() {
    _lastUpdatedDates = {};
    // 日付順にソートされたキーを取得
    final sortedDates = _assetData.keys.toList()..sort();

    for (var type in _assetTypes) {
      String? lastDate;
      // 最新の日付から遡って、その資産タイプのデータがある日を探す
      for (var date in sortedDates.reversed) {
        if (_assetData[date]?.containsKey(type) ?? false) {
          lastDate = date;
          break;
        }
      }
      _lastUpdatedDates[type] = lastDate;
    }
  }

  void _updateChartData() {
    _sortedDates = _assetData.keys.toList()..sort();
    if (_sortedDates.isEmpty) {
      _chartBars = [];
      return;
    }

    final Map<String, List<FlSpot>> spotsData = {
      for (var type in _assetTypes) type: [],
    };

    for (int i = 0; i < _sortedDates.length; i++) {
      final String date = _sortedDates[i];
      double cumulativeValue = 0;

      // 前日のデータを引き継ぐロジック（データの穴埋め）
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

          // データが空の場合は空リストを返す
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
              show: true,
              color: color.withOpacity(0.5),
            ),
          );
        })
        .whereType<LineChartBarData>() // nullを除外
        .toList()
        .reversed
        .toList();
  }
  // #endregion

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
            const Text(
              '今日の資産残高を登録',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _controllers[type],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
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
    if (lastDateStr == null) {
      return const Text(
        '  データなし',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      );
    }

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (lastDateStr == todayStr) {
      return const Text(
        '  本日更新済み',
        style: TextStyle(
          color: Colors.green,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    final formattedDate =
        DateFormat('yyyy/MM/dd').format(DateTime.parse(lastDateStr));
    return Text(
      '  最終更新: $formattedDate',
      style: const TextStyle(color: Colors.grey, fontSize: 12),
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
            const Text(
              '総資産推移',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
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
                              getTitlesWidget: _leftTitleWidgets,
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: _bottomTitleWidgets,
                              interval: max(
                                1,
                                (_sortedDates.length / 5).floor().toDouble(),
                              ),
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
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
            child: const Text('キャンセル'),
          ),
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
            child: const Text('キャンセル'),
          ),
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
      axisSide: meta.axisSide,
      child: Text(text, style: style),
    );
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
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
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
