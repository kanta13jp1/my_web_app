import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../services/conveni_daily_report_payload.dart';

class ConveniStorePage extends StatefulWidget {
  const ConveniStorePage({super.key});

  @override
  State<ConveniStorePage> createState() => _ConveniStorePageState();
}

class _ConveniStorePageState extends State<ConveniStorePage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  bool _simulating = false;
  Map<String, dynamic>? _store;
  List<Map<String, dynamic>> _reports = [];

  static const Map<String, String> _seasonLabels = {
    'spring': '🌸 春',
    'summer': '☀️ 夏',
    'autumn': '🍁 秋',
    'winter': '❄️ 冬',
  };

  static const Map<String, String> _locationLabels = {
    'residential': '🏘 住宅街',
    'office': '🏢 オフィス街',
    'station': '🚉 駅前',
    'school': '🏫 学校周辺',
    'hospital': '🏥 病院周辺',
    'highway': '🛣 幹線道路',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final storeData = await _supabase
          .from('conveni_stores')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();

      List<Map<String, dynamic>> reports = [];
      if (storeData != null) {
        final reportData = await _supabase
            .from('conveni_daily_reports')
            .select()
            .eq('store_id', storeData['id'] as String)
            .order('game_day', ascending: false)
            .limit(7);
        reports = List<Map<String, dynamic>>.from(reportData as List);
      }

      if (mounted) {
        setState(() {
          _store = storeData != null
              ? Map<String, dynamic>.from(storeData as Map)
              : null;
          _reports = reports;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createStore() async {
    final nameCtrl = TextEditingController(text: 'マイコンビニ');
    String location = 'residential';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('コンビニを開業する'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '店舗名',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: location,
                decoration: const InputDecoration(
                  labelText: '立地',
                  border: OutlineInputBorder(),
                ),
                items: _locationLabels.entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setS(() => location = v!),
              ),
              const SizedBox(height: 12),
              const Text(
                '初期資金: ¥5,000,000',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF10B981),
                  height: 1.5,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () async {
                final userId = _supabase.auth.currentUser?.id;
                if (userId == null) return;
                await _supabase.from('conveni_stores').insert({
                  'user_id': userId,
                  'store_name': nameCtrl.text.trim().isEmpty
                      ? 'マイコンビニ'
                      : nameCtrl.text.trim(),
                  'location_type': location,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                await _load();
              },
              child: const Text('開業する'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _simulateDay() async {
    if (_store == null) return;
    setState(() => _simulating = true);
    try {
      final storeId = _store!['id'] as String;
      final currentDay = _store!['current_day'] as int? ?? 1;
      final cash = _store!['cash'] as int? ?? 5000000;
      final reputation = _store!['reputation'] as int? ?? 50;

      // Simple simulation: generate revenue and expenses
      final locationMultiplier = _getLocationMultiplier(
        _store!['location_type'] as String? ?? 'residential',
      );
      final baseRevenue = (15000 * locationMultiplier).toInt();
      final variance = (baseRevenue * 0.2).toInt();
      final revenue = baseRevenue -
          variance +
          (DateTime.now().millisecond % (variance * 2));
      final costOfGoods = (revenue * 0.6).toInt();
      final profit = revenue - costOfGoods;
      final newCash = cash + profit;
      final newReputation = (reputation + (profit > 0 ? 1 : -1)).clamp(0, 100);

      await _supabase.from('conveni_daily_reports').insert(
            buildConveniDailyReportPayload(
              storeId: storeId,
              gameDay: currentDay,
              revenue: revenue,
              costOfGoods: costOfGoods,
              profit: profit,
              customerCount: (revenue / 600).toInt(),
            ),
          );

      await _supabase.from('conveni_stores').update({
        'current_day': currentDay + 1,
        'cash': newCash,
        'total_revenue': (_store!['total_revenue'] as int? ?? 0) + revenue,
        'total_expense': (_store!['total_expense'] as int? ?? 0) + costOfGoods,
        'total_profit': (_store!['total_profit'] as int? ?? 0) + profit,
        'reputation': newReputation,
        'experience_points': (_store!['experience_points'] as int? ?? 0) + 10,
      }).eq('id', storeId);

      await _load();

      if (mounted) {
        final fmt = NumberFormat('#,###');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$currentDay日目完了 — 売上: ¥${fmt.format(revenue)} / 利益: ¥${fmt.format(profit)}',
            ),
            backgroundColor:
                profit >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('シミュレーション失敗: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _simulating = false);
    }
  }

  double _getLocationMultiplier(String location) {
    const multipliers = {
      'residential': 1.0,
      'office': 1.3,
      'station': 1.6,
      'school': 1.1,
      'hospital': 1.2,
      'highway': 1.4,
    };
    return multipliers[location] ?? 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('コンビニ経営シミュレーション'),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _store == null
              ? _buildNoStore(isDark)
              : _buildStore(isDark),
    );
  }

  Widget _buildNoStore(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '🏪',
            style: TextStyle(
              fontSize: 72,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'コンビニを開業しよう',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '仕入れ・価格・人員配置を管理して\n経営感覚を身につけよう',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _createStore,
            icon: const Icon(Icons.store),
            label: const Text('開業する (初期資金 ¥5,000,000)'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStore(bool isDark) {
    final store = _store!;
    final fmt = NumberFormat('#,###');
    final storeName = store['store_name'] as String? ?? 'マイコンビニ';
    final cash = store['cash'] as int? ?? 0;
    final reputation = store['reputation'] as int? ?? 50;
    final satisfaction = store['customer_satisfaction'] as int? ?? 50;
    final currentDay = store['current_day'] as int? ?? 1;
    final season = store['current_season'] as String? ?? 'spring';
    final location = store['location_type'] as String? ?? 'residential';
    final totalProfit = store['total_profit'] as int? ?? 0;
    final level = store['store_level'] as int? ?? 1;
    final xp = store['experience_points'] as int? ?? 0;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store header
          Card(
            color: const Color(0xFF6366F1),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '🏪',
                        style: TextStyle(
                          fontSize: 28,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              storeName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.5,
                              ),
                            ),
                            Text(
                              '${_locationLabels[location]} · ${_seasonLabels[season]} · $currentDay日目',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Lv.$level',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.5,
                            ),
                          ),
                          Text(
                            '$xp XP',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _statBox('💴 所持金', '¥${fmt.format(cash)}', Colors.white),
                      const SizedBox(width: 8),
                      _statBox(
                        '📈 累計利益',
                        '¥${fmt.format(totalProfit)}',
                        totalProfit >= 0
                            ? const Color(0xFFBEF264)
                            : const Color(0xFFFCA5A5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // KPI row
          Row(
            children: [
              Expanded(
                child: _kpiCard(
                  '評判',
                  reputation,
                  Icons.star,
                  const Color(0xFFF59E0B),
                  cardColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _kpiCard(
                  '顧客満足',
                  satisfaction,
                  Icons.sentiment_satisfied_alt,
                  const Color(0xFF10B981),
                  cardColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _kpiCard(
                  'スタッフ士気',
                  store['staff_morale'] as int? ?? 70,
                  Icons.people,
                  const Color(0xFF6366F1),
                  cardColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Simulate day button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _simulating ? null : _simulateDay,
              icon: _simulating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_simulating ? 'シミュレーション中...' : '1日進める'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Daily reports
          if (_reports.isNotEmpty) ...[
            Text(
              '直近の営業記録',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            ..._reports.map(
              (r) => _buildReportRow(r, fmt, isDark, cardColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: valueColor,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(
    String label,
    int value,
    IconData icon,
    Color color,
    Color cardColor,
  ) {
    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withAlpha(40)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.5,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: value / 100,
              backgroundColor: color.withAlpha(20),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportRow(
    Map<String, dynamic> report,
    NumberFormat fmt,
    bool isDark,
    Color cardColor,
  ) {
    final day = report['game_day'] as int? ?? 0;
    final revenue = report['revenue'] as int? ?? 0;
    final profit = report['profit'] as int? ?? 0;
    final customers = report['customer_count'] as int? ?? 0;
    final isProfit = profit >= 0;

    return Card(
      color: cardColor,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Text(
              '$day日目',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                height: 1.5,
              ),
            ),
            const Spacer(),
            Text(
              '👤 $customers人',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '売上 ¥${fmt.format(revenue)}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${isProfit ? '+' : ''}¥${fmt.format(profit)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isProfit
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
