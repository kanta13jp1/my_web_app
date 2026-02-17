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
  List<LineChartBarData> _chartBars = [];
  List<String> _sortedDates = [];
  Map<String, String?> _lastUpdatedDates = {};
  bool _isStacked = true;

  // ▼ 追加: 富の攻防戦用State
  int _todayDefended = 0; // 今日の防衛額（節約）
  int _todayConquered = 0; // 今日の奪取額（稼ぎ）
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
    _fetchTodayStruggleData(); // ▼ 追加: 今日の戦況を取得
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  // #region Data Persistence (Supabase)
  // ... (_loadDataFromSupabase, _saveAssetData, _removeAssetType は既存のまま省略なしで記述) ...
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
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('データ読み込みエラー: $e')));
    }
  }

  Future<void> _saveAssetData() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final Map<String, double> todayData = {};
    bool hasData = false;

    _controllers.forEach((assetType, controller) {
      // ▼ 変更: 入力が空でないなら、0でも保存対象にする
      if (controller.text.isNotEmpty) {
        final cleanText = controller.text.replaceAll(',', '');
        // tryParseで失敗した場合は0.0にするが、明示的に0が入力された場合も0.0になる
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
        if (!_assetData.containsKey(today)) {
          _assetData[today] = {};
        }
        // ▼ 変更: 既存データを上書きする形でマージ
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
        _assetData.forEach((date, assets) {
          assets.remove(name);
        });
        _initControllers();
        _updateChartData();
        _updateLastUpdatedDates();
      });
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('「$name」を削除しました')));
    } catch (e) {
      debugPrint('Error deleting asset type: $e');
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('削除エラー: $e')));
    }
  }
  // #endregion

  // ▼ 追加: 富の攻防戦ロジック
  // 今日の戦況を取得
  Future<void> _fetchTodayStruggleData() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _isLoadingStruggle = true);

    try {
      final now = DateTime.now();
      // 今日の開始と終了時刻（UTC基準で取得範囲を設定）
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
      debugPrint('Error fetching struggle data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingStruggle = false);
    }
  }

  // アクションを記録するダイアログ表示
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
                    ? '1円を節約したということは、1円の富を守り切ったということ。'
                    : '1円稼いだということは、誰かの富を奪ったということ。',
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
                  labelText: '内容 (例: コンビニ我慢、副業収入)',
                  prefixIcon: Icon(Icons.notes),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('撤退'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final amountStr = amountController.text.replaceAll(',', '');
              final amount = int.tryParse(amountStr);
              if (amount == null || amount <= 0) return;

              Navigator.pop(context);
              await _recordStruggle(actionType, amount, memoController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            icon: Icon(isDefend ? Icons.shield : Icons.colorize),
            label: Text(isDefend ? '死守する' : '奪取する'),
          ),
        ],
      ),
    );
  }

  // Supabaseにアクションを記録
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

      // データを再取得して表示を更新
      await _fetchTodayStruggleData();

      if (mounted) {
        final isDefend = actionType == 'defend';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(isDefend ? '¥$amount の富を死守しました。' : '¥$amount の富を奪取しました。'),
            backgroundColor: isDefend ? Colors.blue[800] : Colors.orange[800],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error recording struggle: $e');
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('記録エラー: $e')));
    }
  }
  // ▲ 追加ここまで

  // #region Logic Helpers
  // ... (_initControllers, _addAssetType, _updateLastUpdatedDates は既存のまま省略なしで記述) ...
  void _initControllers() {
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

  // グラフデータの計算ロジック
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
          // ▼ 重要: 「その日のデータが存在しない」場合のみ、前日のデータを引き継ぐ。
          // 0円であってもキーが存在すれば ("containsKey") それが優先されるべき。
          if (!_assetData[date]!.containsKey(type) &&
              _assetData[prevDate]!.containsKey(type)) {
            _assetData[date]![type] = _assetData[prevDate]![type]!;
          }
        }
      }

      for (var type in _assetTypes) {
        // ▼ ここでデータがない場合は0になるが、前段の穴埋め処理で埋まっているはず
        final double value = _assetData[date]?[type] ?? 0;

        if (_isStacked) {
          cumulativeValue += value;
          spotsData[type]!.add(FlSpot(i.toDouble(), cumulativeValue));
        } else {
          spotsData[type]!.add(FlSpot(i.toDouble(), value));
        }
      }
    }

    // ... (以下、チャートバー生成部分は変更なし) ...
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
            belowBarData: BarAreaData(
              show: _isStacked,
              color: color.withOpacity(0.5),
            ),
          );
        })
        .whereType<LineChartBarData>()
        .toList();

    if (_isStacked) {
      _chartBars = _chartBars.reversed.toList();
    }
  }
  // #endregion

  // #region UI Building
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // アプリバーの色を少しダークにして緊張感を出す
      appBar: AppBar(
        title: const Text('資産管理闘争'),
        backgroundColor: Colors.green[900],
        foregroundColor: Colors.white,
      ),
      // 背景色を少し暗くして雰囲気を出す
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildStruggleCard(), // ▼ 追加: 富の攻防戦カード（最上部に配置）
            const SizedBox(height: 24),
            _buildInputCard(), // 既存の入力カード
            const SizedBox(height: 24),
            _buildChartCard(), // 既存のグラフカード
            const SizedBox(height: 16),
            _buildLegendCard(), // 既存の凡例カード
          ],
        ),
      ),
    );
  }

  // ▼ 追加: 富の攻防戦UI
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
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 哲学メッセージ
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

            // 今日の戦果表示
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
                        icon: Icons.colorize, // 剣のようなアイコン
                        color: Colors.orangeAccent,
                      ),
                    ],
                  ),

            const SizedBox(height: 24),
            // アクションボタン
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
  // ▲ 追加ここまで

  // ... (_buildInputCard, _buildAssetInputRow, _buildLastUpdatedText, _buildChartCard, _buildLegendCard は既存のまま省略なしで記述) ...
  Widget _buildInputCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '今日の資産残高を登録 (静的記録)', // 少し表現を変更
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
                label: const Text('残高を記録する'),
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
                  // signed: true を追加してマイナス入力を許可
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '資産推移 (戦況報告)', // 少し表現を変更
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                // 表示モード切り替えスイッチ
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

  // 凡例（レジェンド）カード
  Widget _buildLegendCard() {
    if (_sortedDates.isEmpty) return const SizedBox.shrink();

    // 最新の日付のデータを取得
    final latestDate = _sortedDates.last;
    final latestData = _assetData[latestDate] ?? {};

    // 金額の大きい順にソート（マイナスも考慮）
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
              '現在の内訳 (戦力分析)', // 少し表現を変更
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
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
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$type: $formattedValue',
                      style: TextStyle(
                        fontSize: 13,
                        color: value < 0 ? Colors.red : Colors.black,
                      ),
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
  // #endregion
}
