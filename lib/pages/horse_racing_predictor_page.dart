import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'horse_provider_leaderboard_page.dart';
import 'horseracing_race_detail_page.dart';

enum RaceType {
  all('すべて'),
  jra('中央'),
  nar('地方');

  const RaceType(this.label);
  final String label;
}

enum ErrorType { network, api, unknown }

ErrorType _parseErrorType(dynamic error) {
  final msg = error.toString().toLowerCase();
  if (msg.contains('network') ||
      msg.contains('timeout') ||
      msg.contains('socket') ||
      msg.contains('connection refused')) {
    return ErrorType.network;
  } else if (msg.contains('statuscode') ||
      msg.contains('api') ||
      msg.contains('400') ||
      msg.contains('401') ||
      msg.contains('500')) {
    return ErrorType.api;
  }
  return ErrorType.unknown;
}

/// 競馬自動予想・分析ページ
/// JRA/NAR の出走表を自動取得し、Gemini AI が全レースの3連単を予想する。
/// netkeiba 競合 — 完全自動化パイプライン版
class HorseRacingPredictorPage extends StatefulWidget {
  const HorseRacingPredictorPage({super.key});

  @override
  State<HorseRacingPredictorPage> createState() =>
      _HorseRacingPredictorPageState();
}

class _HorseRacingPredictorPageState extends State<HorseRacingPredictorPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  // _isPredicting / _runAiPredictions は UI 契機の AI 予想実行を廃止したため削除
  // AI 予想は .github/workflows/horse-racing-update.yml (毎時 cron) で自動実行
  String? _error;
  ErrorType? _errorType;
  RaceType _selectedRaceType = RaceType.all;
  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  List<Map<String, dynamic>> _todayRaces = [];
  List<Map<String, dynamic>> _predictionHistory = [];
  Map<String, dynamic> _accuracyStats = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _supabase.functions.invoke(
          'tools-hub',
          body: {
            'action': 'horseracing.today',
            'date': _selectedDate,
            'type': _selectedRaceType.name,
          },
        ),
        _supabase.functions.invoke(
          'tools-hub',
          body: {'action': 'horseracing.predictions', 'limit': 30},
        ),
        _supabase.functions.invoke(
          'tools-hub',
          body: {'action': 'horseracing.accuracy'},
        ), // Trailing comma added here
      ]);
      final d0 = results[0].data;
      _todayRaces = (d0 is Map && d0['races'] is List)
          ? (d0['races'] as List).cast<Map<String, dynamic>>()
          : [];
      final d1 = results[1].data;
      _predictionHistory = (d1 is Map && d1['predictions'] is List)
          ? (d1['predictions'] as List).cast<Map<String, dynamic>>()
          : [];
      final d2 = results[2].data;
      _accuracyStats = (d2 is Map && d2['stats'] is Map)
          ? d2['stats'] as Map<String, dynamic>
          : {};
    } catch (e) {
      final errorType = _parseErrorType(e);
      final errorMsg = switch (errorType) {
        ErrorType.network => 'ネットワーク接続エラー: $e\n数秒後に再度お試しください。',
        ErrorType.api => 'データ取得に失敗しました: $e\nサーバーに問題がある可能性があります。',
        ErrorType.unknown => 'データ取得失敗: $e',
      };
      if (mounted) {
        setState(() {
          _error = errorMsg;
          _errorType = errorType;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // _runAiPredictions 削除: AI予想はバッチ (horse-racing-update.yml 毎時 cron) 専任
  // ユーザー要望 2026-04-18: UI 契機の予想実行を廃止

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_selectedDate) ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = DateFormat('yyyy-MM-dd').format(picked));
      _loadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Row(
          children: [
            const Text(
              '競馬AI予想',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Chip(
                label: Text(
                  _selectedDate,
                  style: const TextStyle(fontSize: 12),
                ),
                avatar: const Icon(Icons.calendar_today, size: 14),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF6B35),
          tabs: const [
            Tab(icon: Icon(Icons.today), text: '今日のレース'),
            Tab(icon: Icon(Icons.history), text: '予想履歴'),
            Tab(icon: Icon(Icons.bar_chart), text: '的中率'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined),
            tooltip: 'AIプロバイダー的中率',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const HorseProviderLeaderboardPage(),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Tooltip(
              message: 'AI予想はバッチ処理 (毎時自動) で生成されます',
              child: Icon(
                Icons.auto_awesome,
                color: Color(0xFFFF6B35),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
            tooltip: '更新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _errorType == ErrorType.network
                            ? Icons.cloud_off
                            : _errorType == ErrorType.api
                                ? Icons.error
                                : Icons.warning,
                        size: 64,
                        color: _errorType == ErrorType.network
                            ? Colors.orange
                            : Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorType == ErrorType.network
                            ? 'ネットワーク接続エラー'
                            : _errorType == ErrorType.api
                                ? 'サーバーエラー'
                                : 'エラーが発生しました',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(color: const Color(0xFF9CA3AF)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _loadAll,
                        icon: const Icon(Icons.refresh),
                        label: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTodayTab(),
                    _buildHistoryTab(),
                    _buildAccuracyTab(),
                  ],
                ),
    );
  }

  Widget _buildTodayTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: SegmentedButton<RaceType>(
            segments: RaceType.values
                .map(
                  (type) => ButtonSegment<RaceType>(
                    value: type,
                    label: Text(type.label),
                  ),
                )
                .toList(),
            selected: {_selectedRaceType},
            onSelectionChanged: (newSelection) {
              if (newSelection.isNotEmpty) {
                setState(() => _selectedRaceType = newSelection.first);
                _loadAll();
              }
            },
            style: SegmentedButton.styleFrom(
              backgroundColor: const Color(0xFF1E1E1E),
              foregroundColor: const Color(0xFF9CA3AF),
              selectedForegroundColor: Colors.white,
              selectedBackgroundColor: const Color(0xFFFF6B35),
            ),
          ),
        ),
        Expanded(
          child: _todayRaces.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sports,
                          size: 64, color: const Color(0xFF9CA3AF)),
                      const SizedBox(height: 12),
                      Text(
                        '$_selectedDate のレースデータなし',
                        style: const TextStyle(color: const Color(0xFF9CA3AF)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '毎朝 07:30 に自動取得されます',
                        style: TextStyle(
                            color: const Color(0xFF9CA3AF), fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'AI予想はバッチ処理 (毎時00分 UTC) で自動生成されます',
                        style: TextStyle(
                            color: const Color(0xFF9CA3AF), fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : _buildTodayRacesList(),
        ),
      ],
    );
  }

  Widget _buildTodayRacesList() {
    final hasPredictions = _todayRaces.any((r) {
      final p = r['horse_predictions'];
      return p != null && (p is List ? p.isNotEmpty : true);
    });
    return Column(
      children: [
        if (!hasPredictions)
          Container(
            color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Color(0xFFFF6B35),
                  size: 16,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI予想はバッチ処理 (毎時 cron) で自動生成されます。次回実行までお待ちください。',
                    style: TextStyle(color: Color(0xFFFF6B35), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemCount: _todayRaces.length,
            itemBuilder: (ctx, i) => _buildRaceCard(_todayRaces[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildRaceCard(Map<String, dynamic> race) {
    final raceName = race['race_name'] as String? ?? 'レース';
    final venue = race['venue'] as String?;
    final raceNumber = (race['race_number'] as num?)?.toInt();
    final courseType = race['course_type'] as String? ?? '芝';
    final distance = (race['distance'] as num?)?.toInt();
    final grade = race['grade'] as String? ?? '';
    final postTime = race['post_time'] as String?;
    final status = race['status'] as String? ?? 'scheduled';
    final entries = (race['horse_entries'] as List?) ?? [];
    final predictions = (race['horse_predictions'] as List?) ?? [];
    final results = (race['horse_results'] as List?) ?? [];
    final hasPrediction = predictions.isNotEmpty;
    final hasResult = results.isNotEmpty;
    final pred =
        hasPrediction ? predictions.first as Map<String, dynamic> : null;
    final result = hasResult ? results.first as Map<String, dynamic> : null;
    final isCorrect = result?['is_prediction_correct'] as bool?;
    final trifectaPaid = (result?['trifecta_paid'] as num?)?.toInt();

    Color statusColor;
    String statusLabel;
    if (hasResult) {
      statusColor = isCorrect == true ? Colors.green : Colors.red;
      statusLabel = isCorrect == true ? '的中' : '外れ';
    } else if (status == 'scheduled') {
      statusColor = const Color(0xFFFF6B35);
      statusLabel = postTime ?? '予定';
    } else {
      statusColor = const Color(0xFF9CA3AF);
      statusLabel = '終了';
    }

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _gradeColor(grade).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ), // ここにカンマを追加
            alignment: Alignment.center,
            child: Text(
              grade.length > 2 ? grade.substring(0, 2) : grade,
              style: TextStyle(
                color: _gradeColor(grade),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Row(
            children: [
              if (raceNumber != null)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${raceNumber}R',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  raceName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Text(
            [
              if (venue != null) venue,
              '$courseType${distance != null ? ' ${distance}m' : ''}',
              '${entries.length}頭',
            ].join(' · '),
            style: TextStyle(color: const Color(0xFF6B7280), fontSize: 12),
          ),
          trailing: Chip(
            label: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 11, // ここにカンマを追加します
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: statusColor.withValues(alpha: 0.12),
            padding: EdgeInsets.zero,
          ),
          children: [
            if (hasPrediction && pred != null)
              _buildPredictionSection(pred, result)
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF9CA3AF).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.psychology_outlined,
                      color: const Color(0xFF9CA3AF),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'AI予想未生成',
                      style: TextStyle(
                          color: const Color(0xFF9CA3AF), fontSize: 13),
                    ),
                  ],
                ),
              ),
            if (entries.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                '出走馬',
                style: TextStyle(
                  color: const Color(0xFF9CA3AF),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ...entries.take(10).map((e) {
                    final en = e as Map<String, dynamic>;
                    final n = (en['horse_number'] as num?)?.toInt();
                    final nm = en['horse_name'] as String? ?? '?';
                    final od = (en['win_odds'] as num?)?.toStringAsFixed(1);
                    final ageSex = en['age_sex'] as String?;
                    final hw = (en['horse_weight'] as num?)?.toInt();
                    final hwc = (en['horse_weight_change'] as num?)?.toInt();
                    final prevFinish = (en['prev_finish'] as num?)?.toInt();
                    final prevRace = en['prev_race_name'] as String?;
                    final prevDays = (en['prev_days_ago'] as num?)?.toInt();

                    Color prevColor = const Color(0xFF9CA3AF);
                    if (prevFinish == 1) {
                      prevColor = const Color(0xFFFFD700);
                    } else if (prevFinish != null && prevFinish <= 3) {
                      prevColor = Colors.green;
                    } else if (prevFinish != null && prevFinish <= 5) {
                      prevColor = Colors.white70;
                    }

                    final weightStr = hw != null
                        ? '$hw kg${hwc != null ? '(${hwc >= 0 ? '+' : ''}$hwc)' : ''}'
                        : null;
                    final prevStr = prevFinish != null
                        ? '前走$prevFinish着${prevRace != null ? ' / $prevRace' : ''}${prevDays != null ? ' / $prevDays日前' : ''}'
                        : null;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${n != null ? '$n.' : ''}$nm'
                            '${ageSex != null ? '  $ageSex' : ''}'
                            '${weightStr != null ? '  $weightStr' : ''}'
                            '${od != null ? '  $od倍' : ''}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                          if (prevStr != null)
                            Text(
                              prevStr,
                              style: TextStyle(
                                color: prevColor,
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  if (entries.length > 10)
                    Text(
                      'ほか ${entries.length - 10}頭',
                      style: const TextStyle(
                        color: const Color(0xFF9CA3AF),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ],
            if (hasResult && result != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isCorrect == true ? Colors.green : Colors.red)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (isCorrect == true ? Colors.green : Colors.red)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCorrect == true ? Icons.check_circle : Icons.cancel,
                          color: isCorrect == true ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isCorrect == true ? '3連単 的中!' : '外れ',
                          style: TextStyle(
                            color:
                                isCorrect == true ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (trifectaPaid != null && isCorrect == true) ...[
                          const SizedBox(width: 8),
                          Text(
                            '配当 ¥${NumberFormat('#,###').format(trifectaPaid)}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '実際: ${result['first_place'] ?? '?'} - '
                      '${result['second_place'] ?? '?'} - '
                      '${result['third_place'] ?? '?'}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.table_chart_outlined, size: 14),
                label: const Text('詳細マトリックス'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HorseracingRaceDetailPage(race: race),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionSection(
    Map<String, dynamic> pred,
    Map<String, dynamic>? result,
  ) {
    final first = pred['first_pick'] as String? ?? '?';
    final second = pred['second_pick'] as String? ?? '?';
    final third = pred['third_pick'] as String? ?? '?';
    final confidence = (pred['confidence'] as num?)?.toDouble() ?? 0.5;
    final reasoning = pred['ai_reasoning'] as String?;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B35).withValues(alpha: 0.08),
            const Color(0xFF3D5AFE).withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: const Color(0xFFFF6B35).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: Color(0xFFFF6B35), size: 16),
              const SizedBox(width: 6),
              const Text(
                'AI 3連単予想',
                style: TextStyle(
                  color: Color(0xFFFF6B35),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '信頼度 ${(confidence * 100).toStringAsFixed(0)}%',
                  style:
                      const TextStyle(color: Color(0xFFFF6B35), fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _placeLabel('1着', first, const Color(0xFFFFC107)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child:
                    Icon(Icons.arrow_forward, color: Colors.white38, size: 14),
              ),
              _placeLabel('2着', second, const Color(0xFF9CA3AF)!),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child:
                    Icon(Icons.arrow_forward, color: Colors.white38, size: 14),
              ),
              _placeLabel('3着', third, Colors.brown[300]!),
            ],
          ),
          if (reasoning != null && reasoning.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              reasoning,
              style: TextStyle(color: const Color(0xFF6B7280), fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _placeLabel(String place, String name, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            place,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_predictionHistory.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 64, color: const Color(0xFF9CA3AF)),
            SizedBox(height: 8),
            Text('予想履歴がありません',
                style: TextStyle(color: const Color(0xFF9CA3AF))),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _predictionHistory.length,
      itemBuilder: (ctx, i) {
        final p = _predictionHistory[i];
        final race = p['horse_races'] as Map<String, dynamic>?;
        final result = p['horse_results'] as Map<String, dynamic>?;
        final raceName = race?['race_name'] as String? ?? 'レース';
        final raceDate = race?['race_date'] as String? ?? '';
        final venue = race?['venue'] as String?;
        final first = p['first_pick'] as String? ?? '?';
        final second = p['second_pick'] as String? ?? '?';
        final third = p['third_pick'] as String? ?? '?';
        final confidence = (p['confidence'] as num?)?.toDouble() ?? 0.5;
        final isCorrect = result?['is_prediction_correct'] as bool?;
        final trifectaPaid = (result?['trifecta_paid'] as num?)?.toInt();
        final hasResult = result != null;
        Color cardBg;
        Widget trailing;
        if (!hasResult) {
          cardBg = const Color(0xFF1E1E1E);
          trailing = const Chip(
            label: Text('未結果', style: TextStyle(fontSize: 11)),
          );
        } else if (isCorrect == true) {
          cardBg = Colors.green.withValues(alpha: 0.06);
          trailing = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
              if (trifectaPaid != null)
                Text(
                  '¥${NumberFormat('#,###').format(trifectaPaid)}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          );
        } else {
          cardBg = Colors.red.withValues(alpha: 0.04);
          trailing = const Icon(Icons.cancel, color: Colors.red, size: 20);
        }
        return Card(
          color: cardBg,
          margin: const EdgeInsets.only(bottom: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFFF6B35).withValues(alpha: 0.12),
              child: const Icon(
                Icons.psychology,
                color: Color(0xFFFF6B35),
                size: 18,
              ),
            ),
            title: Text(
              raceName,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$first - $second - $third',
                  style: const TextStyle(
                    color: Color(0xFFFF6B35),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${venue != null ? '$venue · ' : ''}'
                  '$raceDate · 信頼度${(confidence * 100).toStringAsFixed(0)}%',
                  style:
                      TextStyle(color: const Color(0xFF6B7280), fontSize: 11),
                ),
                if (hasResult)
                  Text(
                    '実際: ${result['first_place'] ?? '?'} - '
                    '${result['second_place'] ?? '?'} - '
                    '${result['third_place'] ?? '?'}',
                    style:
                        TextStyle(color: const Color(0xFF4B5563), fontSize: 11),
                  ),
              ],
            ),
            trailing: trailing,
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildAccuracyTab() {
    final total = (_accuracyStats['total_predictions'] as num?)?.toInt() ?? 0;
    final resultsCount =
        (_accuracyStats['total_results'] as num?)?.toInt() ?? 0;
    final hits = (_accuracyStats['correct_count'] as num?)?.toInt() ?? 0;
    final hitRate = (_accuracyStats['hit_rate_pct'] as num?)?.toDouble() ?? 0;
    final totalPayout = (_accuracyStats['total_payout'] as num?)?.toInt() ?? 0;
    final maxPayout = (_accuracyStats['max_payout'] as num?)?.toInt() ?? 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFFFF8C5A)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text(
                  'AI 3連単 的中率',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  resultsCount > 0
                      ? '${hitRate.toStringAsFixed(1)}%'
                      : '集計中...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$resultsCount件の結果 / $hits件的中',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  '総予想数',
                  '$total件',
                  Icons.psychology,
                  const Color(0xFF3D5AFE),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard(
                  '的中回数',
                  '$hits回',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  '最高配当',
                  maxPayout > 0
                      ? '¥${NumberFormat('#,###').format(maxPayout)}'
                      : '-',
                  Icons.emoji_events,
                  const Color(0xFFFFC107),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard(
                  '累計払戻',
                  totalPayout > 0
                      ? '¥${NumberFormat('#,###').format(totalPayout)}'
                      : '-',
                  Icons.payments,
                  const Color(0xFF009688),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'システム概要',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ..._systemInfoRows(),
        ],
      ),
    );
  }

  List<Widget> _systemInfoRows() {
    return [
      ('データソース', 'netkeiba.com (JRA/NAR)'),
      ('AIモデル', 'Gemini 2.5 Flash'),
      ('予想方式', '3連単 (1着-2着-3着の順序予想)'),
      ('取得タイミング', '毎朝 07:30 JST 自動実行'),
      ('結果取得', '毎日 17:30 / 21:00 JST 自動実行'),
    ]
        .map<Widget>(
          (pair) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    pair.$1,
                    style:
                        TextStyle(color: const Color(0xFF6B7280), fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    pair.$2,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(color: const Color(0xFF9CA3AF), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _gradeColor(String grade) {
    if (grade.startsWith('G1')) return const Color(0xFFFFC107);
    if (grade.startsWith('G2')) return const Color(0xFFD1D5DB)!;
    if (grade.startsWith('G3')) return Colors.brown[300]!;
    if (grade == 'リステッド') return Colors.blue[300]!;
    if (grade == 'オープン') return Colors.purple[300]!;
    return const Color(0xFF4B5563)!;
  }
}
