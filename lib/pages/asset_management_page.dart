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
  List<LineChartBarData> _lineChartBars = [];
  List<BarChartGroupData> _barChartGroups = [];
  double _maxDailyChange = 0;

  List<String> _sortedDates = [];
  Map<String, String?> _lastUpdatedDates = {};

  bool _isStacked = true;
  bool _showDailyChange = false;

  // 富の攻防戦用State
  int _todayDefended = 0;
  int _todayConquered = 0;
  int _todayInvested = 0;
  bool _isLoadingStruggle = false;

  // ▼ 追加・変更: 漸進主義（明細確認）用State
  bool _isSmbcMissionDoneToday = false; // 三井住友銀行の確認フラグ
  bool _isPaypayMissionDoneToday = false; // PayPayカードの確認フラグ
  DateTime _selectedGradualDate = DateTime.now();
  String _selectedSource = '[三井住友銀行大塚支店]'; // 明細元の選択用
  final List<String> _sourceOptions = ['[三井住友銀行大塚支店]', '[PayPayカード]'];

  final TextEditingController _gradualMemoController = TextEditingController();
  final TextEditingController _gradualAmountController =
      TextEditingController();

  // 戦歴（明細）リスト
  List<Map<String, dynamic>> _recentStruggles = [];

  // サブスクリプション管理用変数
  List<Map<String, dynamic>> _subscriptions = [];
  bool _isLoadingSubscriptions = false;

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
    _fetchRecentStruggles();
    _fetchSubscriptions();
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    _gradualMemoController.dispose();
    _gradualAmountController.dispose();
    super.dispose();
  }

  // #region Data Persistence (Assets)
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
      int invested = 0;

      for (var item in data) {
        final amount = item['amount'] as int;
        final type = item['action_type'];
        if (type == 'defend') {
          defended += amount;
        } else if (type == 'conquer') {
          conquered += amount;
        } else if (type == 'invest') {
          invested += amount;
        }
      }
      if (mounted) {
        setState(() {
          _todayDefended = defended;
          _todayConquered = conquered;
          _todayInvested = invested;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingStruggle = false);
    }
  }

  // ▼ 変更: PayPayカードの確認状況も取得する
  Future<void> _fetchRecentStruggles() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await _supabase
          .from('wealth_struggles')
          .select()
          .eq('user_id', userId)
          .order('occurred_at', ascending: false)
          .limit(30);

      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);

      bool smbcDone = false;
      bool paypayDone = false;

      for (var item in data) {
        final createdAtStr = item['created_at'] as String;
        final createdLocal = DateTime.parse(createdAtStr).toLocal();
        // 「今日登録したか」でミッション完了を判定
        if (DateFormat('yyyy-MM-dd').format(createdLocal) == todayStr) {
          if (item['action_type'] == 'expense') {
            final desc = item['description']?.toString() ?? '';
            if (desc.contains('[三井住友銀行大塚支店]')) smbcDone = true;
            if (desc.contains('[PayPayカード]')) paypayDone = true;
          }
        }
      }

      if (mounted) {
        setState(() {
          _recentStruggles = List<Map<String, dynamic>>.from(data);
          _isSmbcMissionDoneToday = smbcDone;
          _isPaypayMissionDoneToday = paypayDone;
        });
      }
    } catch (e) {
      debugPrint('Error fetching history: $e');
    }
  }

  void _showStruggleDialog(String actionType) {
    final isDefend = actionType == 'defend';
    final isInvest = actionType == 'invest';

    String title = '富の奪取 (稼ぎ)';
    Color color = Colors.orange[800]!;
    IconData icon = Icons.colorize;
    String desc = '1円稼いだ＝誰かの富を奪った。\n市場から富を奪取せよ。';

    if (isDefend) {
      title = '富の防衛 (節約)';
      color = Colors.blue[800]!;
      icon = Icons.shield;
      desc = '1円を節約した＝1円の富を守り切った。\n敵から富を死守せよ。';
    } else if (isInvest) {
      title = '未来へ投資 (本・体験)';
      color = Colors.purple[800]!;
      icon = Icons.auto_graph;
      desc = '数千円を惜しむな。\nその規律が5年後の景色を激変させる。';
    }

    final amountController = TextEditingController();
    final memoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title,
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(desc,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                  labelText: '戦況詳細',
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
            icon: Icon(icon),
            label: const Text('記録する'),
          ),
        ],
      ),
    );
  }

  Future<void> _recordStruggle(
      String actionType, int amount, String description,
      {DateTime? occurredAt}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('wealth_struggles').insert({
        'user_id': userId,
        'action_type': actionType,
        'amount': amount,
        'description': description.isEmpty ? null : description,
        'occurred_at': (occurredAt ?? DateTime.now()).toUtc().toIso8601String(),
      });
      await _fetchTodayStruggleData();
      await _fetchRecentStruggles();

      if (mounted) {
        String msg = '記録しました。';
        if (actionType == 'defend') msg = '¥$amount の富を死守しました。';
        if (actionType == 'conquer') msg = '¥$amount の富を奪取しました。';
        if (actionType == 'invest') msg = '¥$amount を未来へ投資しました。';
        if (actionType == 'expense') msg = '明細を1件把握し、前進しました。';

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.black87));
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }
  // #endregion

  // #region Subscriptions Logic
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
      if (mounted) {
        setState(() {
          _subscriptions = [];
          _isLoadingSubscriptions = false;
        });
      }
    }
  }

  Future<void> _addSubscription() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('サブスク(穴)を追加'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration:
                  const InputDecoration(labelText: 'サービス名 (例: Netflix)'),
            ),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: '月額料金 (円)'),
              keyboardType: TextInputType.number,
            ),
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
                await _supabase.from('subscriptions').insert({
                  'user_id': userId,
                  'service_name': name,
                  'price': price,
                });
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
  // #endregion

  // #region Logic Helpers (Chart & Assets)
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

    _barChartGroups = [];
    _maxDailyChange = 0;

    for (int i = 0; i < dailyTotals.length; i++) {
      double diff = 0;
      if (i > 0) {
        diff = dailyTotals[i] - dailyTotals[i - 1];
      }
      if (diff.abs() > _maxDailyChange) {
        _maxDailyChange = diff.abs();
      }
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
                  topLeft: Radius.circular(4), topRight: Radius.circular(4)),
            ),
          ],
        ),
      );
    }
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
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.blueGrey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildGradualismCard(), // ▼ 変更: PayPayカード対応
            const SizedBox(height: 24),
            _buildStruggleCard(),
            const SizedBox(height: 24),
            _buildChartCard(),
            const SizedBox(height: 16),
            if (!_showDailyChange) _buildLegendCard(),
            const SizedBox(height: 24),
            _buildSubscriptionCard(),
            const SizedBox(height: 24),
            _buildInputCard(),
            const SizedBox(height: 24),
            _buildHistoryCard(),
          ],
        ),
      ),
    );
  }

  // -------------------------
  // 各カードUIコンポーネント
  // -------------------------

  // ▼ 変更: 漸進主義ミッション（口座・カード選択機能付き）
  Widget _buildGradualismCard() {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.blueGrey[300]!, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_walk, color: Colors.blueGrey[800]),
                const SizedBox(width: 8),
                Text('漸進主義ミッション',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[900])),
              ],
            ),
            const SizedBox(height: 8),
            const Text('一歩でもいいから毎日前進する。\n銀行・カードの取引明細を確認し、1件ずつ記録せよ。',
                style: TextStyle(
                    fontSize: 12, color: Colors.black87, height: 1.4)),
            const SizedBox(height: 12),

            // 今日のミッション達成状況
            Row(
              children: [
                Icon(
                    _isSmbcMissionDoneToday
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: _isSmbcMissionDoneToday ? Colors.green : Colors.grey,
                    size: 16),
                const SizedBox(width: 4),
                Text('三井住友銀行',
                    style: TextStyle(
                        fontSize: 12,
                        color: _isSmbcMissionDoneToday
                            ? Colors.green[700]
                            : Colors.grey[700])),
                const SizedBox(width: 16),
                Icon(
                    _isPaypayMissionDoneToday
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color:
                        _isPaypayMissionDoneToday ? Colors.green : Colors.grey,
                    size: 16),
                const SizedBox(width: 4),
                Text('PayPayカード',
                    style: TextStyle(
                        fontSize: 12,
                        color: _isPaypayMissionDoneToday
                            ? Colors.green[700]
                            : Colors.grey[700])),
              ],
            ),
            const SizedBox(height: 16),

            if (_isSmbcMissionDoneToday && _isPaypayMissionDoneToday)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!)),
                child: const Row(
                  children: [
                    Icon(Icons.emoji_events, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(
                        child: Text('本日の明細確認は全て完了しました。財布の穴を監視する習慣が身についています。',
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 12))),
                  ],
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        // 明細元の選択
                        DropdownButtonFormField<String>(
                          value: _selectedSource,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          items: _sourceOptions.map((String source) {
                            return DropdownMenuItem<String>(
                              value: source,
                              child: Text(
                                  source
                                      .replaceAll('[', '')
                                      .replaceAll(']', ''),
                                  style: const TextStyle(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null)
                              setState(() => _selectedSource = newValue);
                          },
                        ),
                        const SizedBox(height: 8),
                        // 日付選択
                        InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _selectedGradualDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null)
                              setState(() => _selectedGradualDate = date);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[400]!),
                                borderRadius: BorderRadius.circular(4)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    DateFormat('yyyy/MM/dd')
                                        .format(_selectedGradualDate),
                                    style: const TextStyle(fontSize: 13)),
                                Icon(Icons.calendar_today,
                                    size: 16, color: Colors.grey[600]),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _gradualMemoController,
                          decoration: const InputDecoration(
                              labelText: '内容 (例: Amazon)',
                              border: OutlineInputBorder(),
                              isDense: true),
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _gradualAmountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: '金額 (円)',
                              border: OutlineInputBorder(),
                              isDense: true),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 196, // 入力フィールド4つ分に合わせて高さを調整
                      child: ElevatedButton(
                        onPressed: () async {
                          final memo = _gradualMemoController.text.trim();
                          final amountStr =
                              _gradualAmountController.text.replaceAll(',', '');
                          final amount = int.tryParse(amountStr);
                          if (amount != null && amount > 0 && memo.isNotEmpty) {
                            await _recordStruggle(
                                'expense', amount, '$_selectedSource $memo',
                                occurredAt: _selectedGradualDate);
                            _gradualMemoController.clear();
                            _gradualAmountController.clear();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('内容と金額(1円以上)を正しく入力してください')));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey[800],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8))),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check),
                            SizedBox(height: 4),
                            Text('記録して\n前進する',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStruggleCard() {
    final currencyFormat =
        NumberFormat.simpleCurrency(locale: 'ja_JP', decimalDigits: 0);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey[900]!, Colors.blueGrey[800]!]),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('人生とは富の奪い合いである。',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('毎日1円を守るために必死で生き、1円を奪うために必死で生きなければならない。',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontStyle: FontStyle.italic)),
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
                          color: Colors.blueAccent),
                      _buildStruggleScore(
                          title: '未来へ投資',
                          amount: currencyFormat.format(_todayInvested),
                          icon: Icons.auto_graph,
                          color: Colors.purpleAccent),
                      _buildStruggleScore(
                          title: '今日の奪取 (稼ぎ)',
                          amount: currencyFormat.format(_todayConquered),
                          icon: Icons.colorize,
                          color: Colors.orangeAccent),
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
                            padding: const EdgeInsets.symmetric(vertical: 12)),
                        icon: const Icon(Icons.shield_outlined),
                        label:
                            const Text('死守', style: TextStyle(fontSize: 12)))),
                const SizedBox(width: 8),
                Expanded(
                    child: ElevatedButton.icon(
                        onPressed: () => _showStruggleDialog('invest'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12)),
                        icon: const Icon(Icons.auto_graph),
                        label:
                            const Text('投資', style: TextStyle(fontSize: 12)))),
                const SizedBox(width: 8),
                Expanded(
                    child: ElevatedButton.icon(
                        onPressed: () => _showStruggleDialog('conquer'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[900],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12)),
                        icon: const Icon(Icons.colorize_outlined),
                        label:
                            const Text('奪取', style: TextStyle(fontSize: 12)))),
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
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(title,
            style: TextStyle(color: color.withOpacity(0.8), fontSize: 10)),
        Text(amount,
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

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
                  ? const Center(child: Text('戦況データなし。記録を開始せよ。'))
                  : _showDailyChange
                      ? _buildDailyChangeChart()
                      : _buildAssetTrendChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    int totalCost = 0;
    for (var sub in _subscriptions) {
      totalCost += (sub['price'] as num).toInt();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.credit_card_off, color: Colors.red[800]),
                        const SizedBox(width: 8),
                        Text('固定費削減室 (サブスク)',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red[900])),
                      ],
                    ),
                    const Text('毎月自動で奪われる富を監視せよ。',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('月額流出額',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(
                      '¥${NumberFormat('#,###').format(totalCost)}',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[800]),
                    ),
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
                      child: Center(child: Text('登録された穴(サブスク)はありません')))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _subscriptions.length,
                      itemBuilder: (context, index) {
                        final item = _subscriptions[index];
                        return ListTile(
                          leading:
                              const Icon(Icons.payment, color: Colors.grey),
                          title: Text(item['service_name'] ?? '',
                              style: const TextStyle(fontSize: 14)),
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
                                    _deleteSubscription(item['id']),
                              ),
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
              label: const Text('サブスク(穴)を追加'),
              style: TextButton.styleFrom(foregroundColor: Colors.red[800]),
            ),
          )
        ],
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
            const Text('現状確認 (残高更新)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('現実を直視せよ。数値は嘘をつかない。',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 16),
            ..._assetTypes.map((type) => _buildAssetInputRow(type)),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                    onPressed: _showAddAssetDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('管理項目を追加')),
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
                    padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ▼ 追加: 記録した明細の履歴リスト
  Widget _buildHistoryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.history),
                SizedBox(width: 8),
                Text('戦歴 (直近の明細)',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            if (_recentStruggles.isEmpty)
              const Text('記録がありません。', style: TextStyle(color: Colors.grey))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentStruggles.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _recentStruggles[index];
                  final type = item['action_type'];
                  final amount = item['amount'] as int;
                  final desc = item['description']?.toString() ?? '';
                  final occurredAtStr = item['occurred_at'] as String;
                  final occurredAt = DateTime.parse(occurredAtStr).toLocal();

                  IconData icon = Icons.help;
                  Color color = Colors.grey;
                  String typeLabel = '';

                  switch (type) {
                    case 'defend':
                      icon = Icons.shield;
                      color = Colors.blue[800]!;
                      typeLabel = '防衛';
                      break;
                    case 'invest':
                      icon = Icons.auto_graph;
                      color = Colors.purple[800]!;
                      typeLabel = '投資';
                      break;
                    case 'conquer':
                      icon = Icons.colorize;
                      color = Colors.orange[800]!;
                      typeLabel = '奪取';
                      break;
                    case 'expense':
                      icon = Icons.money_off;
                      color = Colors.red[800]!;
                      typeLabel = '支出';
                      break;
                  }

                  final displayDesc = desc.isNotEmpty ? desc : typeLabel;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                        backgroundColor: color.withOpacity(0.1),
                        child: Icon(icon, color: color, size: 20)),
                    title:
                        Text(displayDesc, style: const TextStyle(fontSize: 13)),
                    subtitle: Text(DateFormat('yyyy/MM/dd').format(occurredAt),
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                    trailing: Text('¥${NumberFormat('#,###').format(amount)}',
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // --- 以下ヘルパーUI (変更なし) ---
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
