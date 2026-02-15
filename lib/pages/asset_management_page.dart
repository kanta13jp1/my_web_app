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

  Map<String, TextEditingController> _controllers = {};
  List<String> _assetTypes = ['現金'];
  Map<String, Map<String, double>> _assetData = {};
  List<LineChartBarData> _chartBars = [];
  List<String> _sortedDates = [];
  Map<String, String?> _lastUpdatedDates = {};

  // ▼ 追加: グラフの表示モード管理用フラグ
  bool _isStacked = true; // true: 積み上げ(合計), false: 個別

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
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  // ... (Supabaseのロード・保存・削除ロジックは変更なしのため省略。そのまま使ってください) ...
  // _loadDataFromSupabase, _saveAssetData, _removeAssetType は元のまま

  // #region Data Persistence (Supabase)
  // (元のコードの _loadDataFromSupabase などをここに貼ってください)
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
      debugPrint('Error: $e');
    }
  }

  Future<void> _saveAssetData() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final Map<String, double> todayData = {};
    bool hasData = false;

    // 入力があるものだけ抽出
    _controllers.forEach((assetType, controller) {
      if (controller.text.isNotEmpty) {
        // ▼ 修正: カンマを取り除いてからパースする
        final cleanText = controller.text.replaceAll(',', '');
        final double amount = double.tryParse(cleanText) ?? 0.0;

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
        _assetData.forEach((date, assets) => assets.remove(name));
        _initControllers();
        _updateChartData();
        _updateLastUpdatedDates();
      });
    } catch (e) {
      debugPrint('$e');
    }
  }
  // #endregion

  // ... (_initControllers, _addAssetType, _updateLastUpdatedDates は元のまま) ...
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

  // ▼ 変更: グラフデータの計算ロジックを修正
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

      // 前日のデータ埋め合わせ
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

        // ★重要: モードによって計算を変える
        if (_isStacked) {
          // 積み上げモード: 足し合わせていく
          cumulativeValue += value;
          spotsData[type]!.add(FlSpot(i.toDouble(), cumulativeValue));
        } else {
          // 個別モード: そのままの値を使う
          spotsData[type]!.add(FlSpot(i.toDouble(), value));
        }
      }
    }

    // チャートデータの作成
    _chartBars = _assetTypes
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
            // 個別モードのときは塗りつぶしを薄く、または無しにする
            belowBarData: BarAreaData(
              show: _isStacked, // 積み上げの時だけ塗りつぶす
              color: color.withOpacity(0.5),
            ),
          );
        })
        .whereType<LineChartBarData>()
        .toList();

    // 積み上げの場合は、描画順序を逆にして「小さいものが手前」に来るようにしないと隠れる場合があるが
    // LineChartでは記述順に描画される。
    // _isStackedの場合はリストを逆順にする(合計が一番後ろ=一番上に描画されると塗りつぶしで隠れるため)
    if (_isStacked) {
      _chartBars = _chartBars.reversed.toList();
    }
  }

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
            _buildChartCard(), // グラフカード
            const SizedBox(height: 16),
            _buildLegendCard(), // ▼ 追加: 凡例（残高リスト）
          ],
        ),
      ),
    );
  }

  // ... (_buildInputCard, _buildAssetInputRow, _buildLastUpdatedText は元のまま) ...
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
                  // ▼ 修正: signed: true を追加してマイナス入力を許可
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

  Widget _buildChartCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '資産推移',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                // ▼ 追加: 表示モード切り替えスイッチ
                Row(
                  children: [
                    const Text('個別', style: TextStyle(fontSize: 12)),
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
                    const Text('合計', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
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
                              reservedSize: 60, // 少し広げる
                              getTitlesWidget: _leftTitleWidgets,
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: _bottomTitleWidgets,
                              interval: max(1,
                                  (_sortedDates.length / 5).floor().toDouble()),
                            ),
                          ),
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

  // ▼ 追加: 凡例（レジェンド）カード
  Widget _buildLegendCard() {
    if (_sortedDates.isEmpty) return const SizedBox.shrink();

    // 最新の日付のデータを取得
    final latestDate = _sortedDates.last;
    final latestData = _assetData[latestDate] ?? {};

    // 金額の大きい順にソート
    final sortedAssets = _assetTypes.toList()
      ..sort((a, b) => (latestData[b] ?? 0).compareTo(latestData[a] ?? 0));

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '現在の内訳',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: sortedAssets.asMap().entries.map((entry) {
                final type = entry.value;
                // 元の色リストとの対応を維持するため、_assetTypes内でのインデックスを使う
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
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$type: $formattedValue',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ... (_showAddAssetDialog, _showRemoveAssetDialog, _getIconForAsset, _bottomTitleWidgets, _leftTitleWidgets は元のまま) ...
  // (省略)

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
      if (_isStacked) // 合計モードの時だけ総資産を表示
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
}
