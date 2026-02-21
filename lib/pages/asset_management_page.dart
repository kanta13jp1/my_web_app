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

  // --- 資産・負債（ストック）用変数 ---
  Map<String, TextEditingController> _controllers = {};
  List<String> _assetTypes = ['現金'];
  Map<String, Map<String, double>> _assetData = {};
  Map<String, String?> _lastUpdatedDates = {};

  // --- グラフデータ ---
  List<LineChartBarData> _lineChartBars = [];
  List<BarChartGroupData> _barChartGroups = [];
  double _maxDailyChange = 0;
  List<String> _sortedDates = [];
  bool _isStacked = true;
  bool _showDailyChange = false;

  // --- 収支（フロー）記録用変数 ---
  DateTime _selectedFlowDate = DateTime.now();
  String _selectedSource = '[三井住友銀行大塚支店]';
  String _selectedFlowType = '支出'; // 収入 or 支出
  final List<String> _sourceOptions = [
    '[三井住友銀行大塚支店]',
    '[PayPayカード]',
    '[横浜銀行]',
    '[現金]',
    '[その他]'
  ];
  final TextEditingController _flowMemoController = TextEditingController();
  final TextEditingController _flowAmountController = TextEditingController();
  List<Map<String, dynamic>> _recentFlows = []; // 今月の収支履歴

  // --- サブスク（固定費）用変数 ---
  List<Map<String, dynamic>> _subscriptions = [];
  bool _isLoadingSubscriptions = false;

  // --- 必須タスク用変数 ---
  List<Map<String, dynamic>> _mustTasks = [];
  bool _isLoadingTasks = false;

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
    _fetchRecentFlows();
    _fetchSubscriptions();
    _fetchMustTasks();
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    _flowMemoController.dispose();
    _flowAmountController.dispose();
    super.dispose();
  }

  // ==========================================
  // 1 & 2. 資産・負債の記録（ストック）
  // ==========================================
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

  Future<void> _saveSingleAssetData(String type) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final controller = _controllers[type];
    if (controller == null || controller.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$type の金額を入力してください')));
      return;
    }

    final cleanText = controller.text.replaceAll(',', '');
    final double amount = double.tryParse(cleanText) ?? 0.0;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      await _supabase.from('cfo_assets').insert({
        'user_id': userId,
        'title': type,
        'amount': amount,
        'created_at': DateTime.now().toIso8601String(),
      });

      setState(() {
        if (!_assetData.containsKey(today)) _assetData[today] = {};
        _assetData[today]![type] = amount;
        _updateChartData();
        _updateLastUpdatedDates();
      });
      controller.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ $type を記録しました'),
            backgroundColor: Colors.green[700]));
      }
    } catch (e) {
      debugPrint('Error saving $type: $e');
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
            .showSnackBar(const SnackBar(content: Text('資産・負債を一括記録しました。')));
    } catch (e) {
      debugPrint('Error saving assets: $e');
    }
  }

  void _showAddAssetDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('項目を追加'),
        content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: '資産・負債名 (例: 住宅ローン)')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty &&
                  !_assetTypes.contains(controller.text)) {
                setState(() {
                  _assetTypes.add(controller.text);
                  _initControllers();
                  _updateLastUpdatedDates();
                });
              }
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
        content: const Text('この項目を削除しますか？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () async {
              final userId = _supabase.auth.currentUser?.id;
              if (userId != null) {
                await _supabase
                    .from('cfo_assets')
                    .delete()
                    .eq('user_id', userId)
                    .eq('title', type);
                setState(() {
                  _assetTypes.remove(type);
                  _controllers.remove(type)?.dispose();
                  _assetData.forEach((date, assets) {
                    assets.remove(type);
                  });
                  _initControllers();
                  _updateChartData();
                  _updateLastUpdatedDates();
                });
              }
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. 固定費の記録（サブスク）
  // ==========================================
  Future<void> _fetchSubscriptions() async {
    setState(() => _isLoadingSubscriptions = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final data = await _supabase
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .order('price', ascending: false);
      if (mounted) {
        setState(() {
          _subscriptions = List<Map<String, dynamic>>.from(data);
          _isLoadingSubscriptions = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _subscriptions = [];
          _isLoadingSubscriptions = false;
        });
    }
  }

  Future<void> _addSubscription() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('固定費を追加'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration:
                    const InputDecoration(labelText: '名称 (例: 家賃, Netflix)')),
            TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: '月額 (円)'),
                keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final price = int.tryParse(priceController.text.trim()) ?? 0;
              if (name.isEmpty) return;
              final userId = _supabase.auth.currentUser?.id;
              if (userId != null) {
                await _supabase.from('subscriptions').insert(
                    {'user_id': userId, 'service_name': name, 'price': price});
                if (context.mounted) Navigator.pop(context);
                _fetchSubscriptions();
              }
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSubscription(String id) async {
    await _supabase.from('subscriptions').delete().eq('id', id);
    _fetchSubscriptions();
  }

  // ==========================================
  // 4. 今月の支出と収入の記録（フロー）
  // ==========================================
  Future<void> _fetchRecentFlows() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      // 当月の初日を計算
      final now = DateTime.now();
      final firstDayOfMonth =
          DateTime(now.year, now.month, 1).toUtc().toIso8601String();

      final data = await _supabase
          .from('wealth_struggles')
          .select()
          .eq('user_id', userId)
          .gte('occurred_at', firstDayOfMonth)
          .order('occurred_at', ascending: false);

      if (mounted) {
        setState(() {
          _recentFlows = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint('Error fetching flows: $e');
    }
  }

  Future<void> _recordFlow() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final memo = _flowMemoController.text.trim();
    final amountStr = _flowAmountController.text.replaceAll(',', '');
    final amount = int.tryParse(amountStr);

    if (amount == null || amount <= 0 || memo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('内容と金額(1円以上)を正しく入力してください')));
      return;
    }

    // 収入は conquer(奪取)、支出は expense(浪費) として記録
    final actionType = _selectedFlowType == '収入' ? 'conquer' : 'expense';

    try {
      await _supabase.from('wealth_struggles').insert({
        'user_id': userId,
        'action_type': actionType,
        'amount': amount,
        'description': '$_selectedSource $memo',
        'occurred_at': _selectedFlowDate.toUtc().toIso8601String(),
      });

      _flowMemoController.clear();
      _flowAmountController.clear();
      await _fetchRecentFlows();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('収支を記録しました'), backgroundColor: Colors.black87));
      }
    } catch (e) {
      debugPrint('Error recording flow: $e');
    }
  }

  // ==========================================
  // 5. 必須タスクの記録と把握
  // ==========================================
  Future<void> _fetchMustTasks() async {
    setState(() => _isLoadingTasks = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      // テーブルがない場合はエラーになるためcatchで空配列に
      final data = await _supabase
          .from('must_tasks')
          .select()
          .eq('user_id', userId)
          .order('deadline', ascending: true);

      if (mounted)
        setState(() {
          _mustTasks = List<Map<String, dynamic>>.from(data);
          _isLoadingTasks = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _mustTasks = [];
          _isLoadingTasks = false;
        });
    }
  }

  Future<void> _addMustTask() async {
    final titleController = TextEditingController();
    DateTime selectedDeadline = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('必須タスクを追加'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: titleController,
                  decoration:
                      const InputDecoration(labelText: 'タスク内容 (例: 確定申告)')),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDeadline,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (date != null)
                    setDialogState(() => selectedDeadline = date);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          '締切: ${DateFormat('yyyy/MM/dd').format(selectedDeadline)}'),
                      Icon(Icons.calendar_today,
                          size: 16, color: Colors.grey[600]),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル')),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                final userId = _supabase.auth.currentUser?.id;
                if (userId != null) {
                  try {
                    await _supabase.from('must_tasks').insert({
                      'user_id': userId,
                      'title': title,
                      'deadline': selectedDeadline.toUtc().toIso8601String(),
                      'is_completed': false,
                    });
                    if (context.mounted) Navigator.pop(context);
                    _fetchMustTasks();
                  } catch (e) {
                    debugPrint('Error adding task: $e');
                    // テーブルがない場合のフォールバック（画面上だけ追加）
                    setState(() {
                      _mustTasks.add({
                        'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
                        'title': title,
                        'deadline': selectedDeadline.toUtc().toIso8601String(),
                        'is_completed': false,
                      });
                    });
                    if (context.mounted) Navigator.pop(context);
                  }
                }
              },
              child: const Text('追加'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _toggleTaskStatus(String id, bool currentStatus) async {
    try {
      await _supabase
          .from('must_tasks')
          .update({'is_completed': !currentStatus}).eq('id', id);
      _fetchMustTasks();
    } catch (e) {
      // テーブルがない場合のモック処理
      setState(() {
        final index = _mustTasks.indexWhere((t) => t['id'] == id);
        if (index != -1) _mustTasks[index]['is_completed'] = !currentStatus;
      });
    }
  }

  // ==========================================
  // グラフ描画ロジック
  // ==========================================
  void _updateChartData() {
    _sortedDates = _assetData.keys.toList()..sort();
    if (_sortedDates.isEmpty) {
      _lineChartBars = [];
      _barChartGroups = [];
      return;
    }
    final Map<String, List<FlSpot>> spotsData = {
      for (var type in _assetTypes) type: [],
    };
    List<double> dailyTotals = [];

    for (int i = 0; i < _sortedDates.length; i++) {
      final String date = _sortedDates[i];
      double currentDayTotal = 0;
      double cumulativeValue = 0;

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
            belowBarData:
                BarAreaData(show: _isStacked, color: color.withOpacity(0.5)),
          );
        })
        .whereType<LineChartBarData>()
        .toList();

    if (_isStacked) _lineChartBars = _lineChartBars.reversed.toList();

    _barChartGroups = [];
    _maxDailyChange = 0;
    for (int i = 0; i < dailyTotals.length; i++) {
      double diff = 0;
      if (i > 0) diff = dailyTotals[i] - dailyTotals[i - 1];
      if (diff.abs() > _maxDailyChange) _maxDailyChange = diff.abs();
      final color = diff >= 0 ? Colors.green : Colors.red;
      _barChartGroups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
              toY: diff,
              color: color,
              width: 12,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4), topRight: Radius.circular(4)))
        ],
      ));
    }
    if (_maxDailyChange == 0) _maxDailyChange = 1000;
    _maxDailyChange *= 1.2;
  }

  // ==========================================
  // UI構築
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('資産管理闘争'),
          backgroundColor: const Color(0xFF1B5E20),
          foregroundColor: Colors.white),
      backgroundColor: Colors.blueGrey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAssetLiabilityCard(), // ①全資産 ②全負債
            const SizedBox(height: 24),
            _buildFlowCard(), // ④支出・収入の記録
            const SizedBox(height: 24),
            _buildSubscriptionCard(), // ③固定費
            const SizedBox(height: 24),
            _buildMustTasksCard(), // ⑤必須タスク
            const SizedBox(height: 24),
            _buildChartCard(), // グラフ
          ],
        ),
      ),
    );
  }

  // ①資産 ②負債 の入力カード
  Widget _buildAssetLiabilityCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.account_balance, color: Colors.green),
                SizedBox(width: 8),
                Text('①資産・②負債の全容把握',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Text('現金、銀行口座、クレカの未払い(マイナス入力)をすべて記録せよ。',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 16),
            ..._assetTypes.map((type) => _buildAssetInputRow(type)),
            const SizedBox(height: 8),
            Row(children: [
              TextButton.icon(
                  onPressed: _showAddAssetDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('項目を追加'))
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveAssetData,
                icon: const Icon(Icons.done_all),
                label: const Text('全体状況を保存'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
            const SizedBox(height: 16),
            _buildLegendCard(), // 内訳表示
          ],
        ),
      ),
    );
  }

  Widget _buildAssetInputRow(String type) {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final isUpdatedToday = _lastUpdatedDates[type] == todayStr;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controllers[type],
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              decoration: InputDecoration(
                labelText: type,
                hintText: '負債はマイナス(-)をつける',
                border: const OutlineInputBorder(),
                isDense: true,
                filled: isUpdatedToday,
                fillColor: isUpdatedToday ? Colors.green[50] : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _saveSingleAssetData(type),
            style: ElevatedButton.styleFrom(
              backgroundColor: isUpdatedToday ? Colors.grey : Colors.green[700],
              foregroundColor: Colors.white,
            ),
            child: Text(isUpdatedToday ? '済' : '記録'),
          ),
          if (type != '現金')
            IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                onPressed: () => _showRemoveAssetDialog(type)),
        ],
      ),
    );
  }

  Widget _buildLegendCard() {
    if (_sortedDates.isEmpty) return const SizedBox.shrink();
    final latestDate = _sortedDates.last;
    final latestData = _assetData[latestDate] ?? {};
    double totalAssets = 0;
    double totalLiabilities = 0;

    latestData.forEach((key, value) {
      if (value >= 0)
        totalAssets += value;
      else
        totalLiabilities += value;
    });

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('総資産:'),
            Text('¥${NumberFormat('#,###').format(totalAssets)}',
                style: const TextStyle(
                    color: Colors.green, fontWeight: FontWeight.bold))
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('総負債:'),
            Text('¥${NumberFormat('#,###').format(totalLiabilities)}',
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold))
          ]),
          const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('純資産:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
                '¥${NumberFormat('#,###').format(totalAssets + totalLiabilities)}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
          ]),
        ],
      ),
    );
  }

  // ④ 今月の支出と収入
  Widget _buildFlowCard() {
    int totalIncome = 0;
    int totalExpense = 0;

    for (var item in _recentFlows) {
      final amount = item['amount'] as int;
      if (item['action_type'] == 'conquer') totalIncome += amount; // 収入
      if (item['action_type'] == 'expense') totalExpense += amount; // 支出
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.blue),
                SizedBox(width: 8),
                Text('④今月の収支の記録',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Text('お金の流れをすべてリスト化する。',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 16),

            // 入力フォーム
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedFlowType,
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                    items: ['支出', '収入']
                        .map((String val) => DropdownMenuItem(
                            value: val,
                            child: Text(val,
                                style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedFlowType = val);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedFlowDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now());
                      if (date != null)
                        setState(() => _selectedFlowDate = date);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[400]!),
                          borderRadius: BorderRadius.circular(4)),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('MM/dd').format(_selectedFlowDate)),
                            Icon(Icons.calendar_today,
                                size: 16, color: Colors.grey[600])
                          ]),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedSource,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                    items: _sourceOptions
                        .map((String source) => DropdownMenuItem(
                            value: source,
                            child: Text(
                                source.replaceAll('[', '').replaceAll(']', ''),
                                style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSource = val);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                      controller: _flowMemoController,
                      decoration: const InputDecoration(
                          labelText: '内容',
                          border: OutlineInputBorder(),
                          isDense: true)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: TextField(
                        controller: _flowAmountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: '金額 (円)',
                            border: OutlineInputBorder(),
                            isDense: true))),
                const SizedBox(width: 8),
                ElevatedButton(
                    onPressed: _recordFlow,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('追加')),
              ],
            ),
            const SizedBox(height: 16),

            // 今月のサマリー
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(children: [
                    const Text('今月収入', style: TextStyle(fontSize: 10)),
                    Text('¥${NumberFormat('#,###').format(totalIncome)}',
                        style: TextStyle(
                            color: Colors.green[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 16))
                  ]),
                  Column(children: [
                    const Text('今月支出', style: TextStyle(fontSize: 10)),
                    Text('¥${NumberFormat('#,###').format(totalExpense)}',
                        style: TextStyle(
                            color: Colors.red[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 16))
                  ]),
                  Column(children: [
                    const Text('収支差額', style: TextStyle(fontSize: 10)),
                    Text(
                        '¥${NumberFormat('#,###').format(totalIncome - totalExpense)}',
                        style: TextStyle(
                            color: (totalIncome - totalExpense) >= 0
                                ? Colors.green[800]
                                : Colors.red[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 16))
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // リスト表示
            _recentFlows.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: Text('今月の記録はありません')))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _recentFlows.length,
                    itemBuilder: (context, index) {
                      final item = _recentFlows[index];
                      final isIncome = item['action_type'] == 'conquer';
                      final amount = item['amount'] as int;
                      final desc = item['description']?.toString() ?? '';
                      final date =
                          DateTime.parse(item['occurred_at']).toLocal();
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                            isIncome ? Icons.add_circle : Icons.remove_circle,
                            color: isIncome ? Colors.green : Colors.red,
                            size: 20),
                        title: Text(desc, style: const TextStyle(fontSize: 13)),
                        subtitle: Text(DateFormat('MM/dd').format(date),
                            style: const TextStyle(fontSize: 11)),
                        trailing: Text(
                            '${isIncome ? '+' : '-'}¥${NumberFormat('#,###').format(amount)}',
                            style: TextStyle(
                                color: isIncome ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold)),
                      );
                    },
                  )
          ],
        ),
      ),
    );
  }

  // ③ 固定費
  Widget _buildSubscriptionCard() {
    int totalCost = 0;
    for (var sub in _subscriptions) {
      totalCost += (sub['price'] as num).toInt();
    }
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.credit_card_off, color: Colors.red[800]),
                      const SizedBox(width: 8),
                      Text('③固定費をすべて把握',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[900]))
                    ]),
                    const Text('毎月自動で奪われる富を監視せよ。',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('月額合計',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('¥${NumberFormat('#,###').format(totalCost)}',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[800]))
                  ],
                )
              ],
            ),
          ),
          _isLoadingSubscriptions
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()))
              : _subscriptions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('登録された固定費はありません')))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _subscriptions.length,
                      itemBuilder: (context, index) {
                        final item = _subscriptions[index];
                        return ListTile(
                          dense: true,
                          leading:
                              const Icon(Icons.payment, color: Colors.grey),
                          title: Text(item['service_name'] ?? ''),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                  '¥${NumberFormat('#,###').format(item['price'])}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.grey, size: 20),
                                  onPressed: () =>
                                      _deleteSubscription(item['id'])),
                            ],
                          ),
                        );
                      },
                    ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextButton.icon(
                onPressed: _addSubscription,
                icon: const Icon(Icons.add),
                label: const Text('固定費を追加'),
                style: TextButton.styleFrom(foregroundColor: Colors.red[800])),
          )
        ],
      ),
    );
  }

  // ⑤ 必須タスク
  Widget _buildMustTasksCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.assignment_late, color: Colors.orange),
                SizedBox(width: 8),
                Text('⑤今月の必須タスク',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Text('今月中に必ず処理すべき事務手続き等を記録せよ。',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 16),
            _isLoadingTasks
                ? const Center(child: CircularProgressIndicator())
                : _mustTasks.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: Text('登録されたタスクはありません')))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _mustTasks.length,
                        itemBuilder: (context, index) {
                          final task = _mustTasks[index];
                          final isCompleted = task['is_completed'] == true;
                          final deadline =
                              DateTime.parse(task['deadline']).toLocal();
                          final isOverdue =
                              !isCompleted && deadline.isBefore(DateTime.now());

                          return CheckboxListTile(
                            value: isCompleted,
                            onChanged: (val) =>
                                _toggleTaskStatus(task['id'], isCompleted),
                            title: Text(task['title'],
                                style: TextStyle(
                                    decoration: isCompleted
                                        ? TextDecoration.lineThrough
                                        : null)),
                            subtitle: Text(
                                '締切: ${DateFormat('yyyy/MM/dd').format(deadline)}',
                                style: TextStyle(
                                    color:
                                        isOverdue ? Colors.red : Colors.grey)),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          );
                        },
                      ),
            TextButton.icon(
                onPressed: _addMustTask,
                icon: const Icon(Icons.add),
                label: const Text('タスクを追加'),
                style:
                    TextButton.styleFrom(foregroundColor: Colors.orange[800])),
          ],
        ),
      ),
    );
  }

  // --- グラフ (既存のまま維持) ---
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
                    Text(_showDailyChange ? '戦果レポート (日次損益)' : '戦略マップ (資産推移)',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(_showDailyChange ? '昨日の自分に勝ったか？' : '国力(富)の総量は増えているか？',
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.show_chart, size: 16),
                    Switch(
                        value: _showDailyChange,
                        activeColor: Colors.redAccent,
                        onChanged: (value) {
                          setState(() {
                            _showDailyChange = value;
                          });
                        }),
                    const Icon(Icons.bar_chart, size: 16),
                  ],
                ),
              ],
            ),
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
                      }),
                  const Text('合計', style: TextStyle(fontSize: 10)),
                ],
              ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: _lineChartBars.isEmpty && _barChartGroups.isEmpty
                  ? const Center(child: Text('戦況データなし。'))
                  : _showDailyChange
                      ? _buildDailyChangeChart()
                      : _buildAssetTrendChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetTrendChart() {
    return LineChart(LineChartData(
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
    ));
  }

  Widget _buildDailyChangeChart() {
    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: _maxDailyChange,
      minY: -_maxDailyChange,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final dateIndex = group.x.toInt();
            final dateStr =
                dateIndex < _sortedDates.length ? _sortedDates[dateIndex] : '';
            final date = dateStr.isNotEmpty
                ? DateFormat('MM/dd').format(DateTime.parse(dateStr))
                : '';
            final val =
                NumberFormat.simpleCurrency(locale: 'ja_JP', decimalDigits: 0)
                    .format(rod.toY);
            return BarTooltipItem(
              '$date\n$val',
              TextStyle(
                  color:
                      rod.toY >= 0 ? Colors.lightGreenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold),
            );
          },
        ),
      ),
      titlesData: _buildChartTitles(),
      gridData: FlGridData(
        show: true,
        checkToShowHorizontalLine: (value) => value == 0,
        getDrawingHorizontalLine: (value) {
          if (value == 0)
            return const FlLine(color: Colors.black54, strokeWidth: 1);
          return const FlLine(color: Colors.black12, strokeWidth: 1);
        },
      ),
      borderData: FlBorderData(show: false),
      barGroups: _barChartGroups,
    ));
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

  IconData _getIconForAsset(String type) {
    if (type.contains('現金')) return Icons.wallet;
    if (type.contains('銀行')) return Icons.account_balance;
    if (type.contains('証券')) return Icons.trending_up;
    if (type.contains('ローン') || type.contains('カード')) return Icons.credit_card;
    return Icons.monetization_on;
  }
}
