import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'horse_provider_leaderboard_page.dart';
import 'horseracing_race_detail_page.dart';

enum RaceType {
  all('すべて'),
  jra('中央'),
  overseas('海外'),
  nar('地方');

  const RaceType(this.label);
  final String label;
}

enum ErrorType { network, serviceUnavailable, api, unknown }

ErrorType _parseErrorType(dynamic error) {
  final msg = error.toString().toLowerCase();
  if (msg.contains('network') ||
      msg.contains('timeout') ||
      msg.contains('socket') ||
      msg.contains('connection refused')) {
    return ErrorType.network;
  }
  // Supabase Edge Function 一時不可用 (cold start / quota / 5xx)
  if (msg.contains('503') ||
      msg.contains('temporarily unavailable') ||
      msg.contains('supabase_edge_runtime_error') ||
      msg.contains('boot_error') ||
      msg.contains('worker_limit')) {
    return ErrorType.serviceUnavailable;
  }
  if (msg.contains('statuscode') ||
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
  bool _isPredicting = false;
  String? _error;
  String? _predictionStatus;
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
        ErrorType.network => 'インターネット接続を確認のうえ、数秒後にもう一度お試しください。',
        ErrorType.serviceUnavailable =>
          'サーバーが一時的に混み合っています。\n少し待ってから「再試行」ボタンを押してください。',
        ErrorType.api => 'サーバー側で問題が発生しました。\n少し待ってから再試行してください。',
        ErrorType.unknown => 'データの取得に失敗しました。\n再試行しても解消しない場合はお問い合わせください。',
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

  Future<void> _runAiPredictions({Map<String, dynamic>? race}) async {
    final raceId = race?['id'] as String?;
    setState(() {
      _isPredicting = true;
      _predictionStatus = raceId == null
          ? '$_selectedDate の未予想レースをAI予想中です'
          : '${race?['venue'] ?? ''} ${race?['race_number'] ?? ''}RをAI予想中です';
    });
    try {
      final response = await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'horseracing.predict_all',
          'date': _selectedDate,
          'type': _selectedRaceType.name,
          'limit': raceId == null ? 80 : 1,
          if (raceId != null) 'race_id': raceId,
          if (raceId != null) 'force': true,
        },
      );
      final data = response.data;
      final count = data is Map ? (data['count'] as num?)?.toInt() ?? 0 : 0;
      final failureCount =
          data is Map ? (data['failure_count'] as num?)?.toInt() ?? 0 : 0;
      final remaining =
          data is Map ? (data['remaining'] as num?)?.toInt() ?? 0 : 0;
      if (mounted) {
        setState(() {
          _predictionStatus = count > 0
              ? 'AI予想を$count件生成しました。失敗$failureCount件 / 残り$remaining件'
              : '新規AI予想は生成されませんでした。暫定指数予想を確認してください。';
        });
      }
      await _loadAll();
    } catch (_) {
      if (mounted) {
        setState(() {
          _predictionStatus = 'AI予想の即時生成に失敗しました。暫定指数予想を表示しています。';
        });
      }
    } finally {
      if (mounted) setState(() => _isPredicting = false);
    }
  }

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

  Map<String, dynamic>? _firstMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty) {
      final first = value.first;
      if (first is Map<String, dynamic>) return first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return null;
  }

  List<Map<String, dynamic>> _entriesOf(Map<String, dynamic> race) {
    final entriesRaw = race['horse_entries'];
    if (entriesRaw is List) {
      return entriesRaw
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    }
    if (entriesRaw is Map) return [Map<String, dynamic>.from(entriesRaw)];
    return const [];
  }

  bool _hasPrediction(Map<String, dynamic> race) =>
      _firstMap(race['horse_predictions']) != null;

  int _postTimeMinutes(Map<String, dynamic> race) {
    final time = race['post_time'] as String?;
    if (time == null || !time.contains(':')) return 24 * 60 + 99;
    final parts = time.split(':');
    final hour = int.tryParse(parts.first) ?? 24;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return hour * 60 + minute;
  }

  Map<String, dynamic>? _nextRace() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final races = _todayRaces
        .where(
          (race) =>
              _selectedDate != today || _postTimeMinutes(race) >= nowMinutes,
        )
        .toList()
      ..sort((a, b) => _postTimeMinutes(a).compareTo(_postTimeMinutes(b)));
    return races.isEmpty ? null : races.first;
  }

  double _instantScore(Map<String, dynamic> entry) {
    var score = 50.0;
    final odds = (entry['win_odds'] as num?)?.toDouble();
    if (odds != null && odds > 0) {
      score += (32 / odds).clamp(0, 28);
      if (odds <= 3) score += 6;
      if (odds >= 30) score -= 8;
    }
    final popularity = (entry['popularity'] as num?)?.toInt();
    if (popularity != null) {
      score += (18 - popularity).clamp(-8, 18);
    }
    final prevFinish = (entry['prev_finish'] as num?)?.toInt();
    if (prevFinish != null) {
      if (prevFinish == 1) {
        score += 18;
      } else if (prevFinish <= 3) {
        score += 12;
      } else if (prevFinish <= 5) {
        score += 6;
      } else {
        score -= (prevFinish - 5).clamp(0, 8);
      }
    }
    final weightChange = (entry['horse_weight_change'] as num?)?.toInt();
    if (weightChange != null) {
      final absChange = weightChange.abs();
      if (absChange <= 6) {
        score += 3;
      } else if (absChange >= 14) {
        score -= 5;
      }
    }
    final horseNumber = (entry['horse_number'] as num?)?.toInt();
    if (horseNumber != null && horseNumber <= 3) score += 1.5;
    return score;
  }

  List<Map<String, dynamic>> _rankInstantForecast(
    List<Map<String, dynamic>> entries,
  ) {
    final ranked = List<Map<String, dynamic>>.from(entries)
      ..sort((a, b) => _instantScore(b).compareTo(_instantScore(a)));
    return ranked;
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Chip(
                label: Text(
                  _selectedDate,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                  ),
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
                        switch (_errorType) {
                          ErrorType.network => Icons.cloud_off,
                          ErrorType.serviceUnavailable => Icons.hourglass_empty,
                          ErrorType.api => Icons.error,
                          _ => Icons.warning,
                        },
                        size: 64,
                        color: _errorType == ErrorType.network ||
                                _errorType == ErrorType.serviceUnavailable
                            ? const Color(0xFFFF6B35)
                            : const Color(0xFFE53935),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        switch (_errorType) {
                          ErrorType.network => 'ネットワーク接続エラー',
                          ErrorType.serviceUnavailable => 'サーバー混雑中',
                          ErrorType.api => 'サーバーエラー',
                          _ => 'エラーが発生しました',
                        },
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            height: 1.5,
                          ),
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
        _buildTodayActionBar(),
        Expanded(
          child: _todayRaces.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.sports,
                        size: 64,
                        color: Color(0xFF9CA3AF),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$_selectedDate のレースデータなし',
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '毎朝 07:30 に自動取得されます',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'AI予想はバッチ処理 (毎時00分 UTC) で自動生成されます',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 11,
                          height: 1.5,
                        ),
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

  Widget _buildTodayActionBar() {
    final total = _todayRaces.length;
    final predicted = _todayRaces.where(_hasPrediction).length;
    final entriesReady =
        _todayRaces.where((race) => _entriesOf(race).length >= 3).length;
    final next = _nextRace();
    final nextLabel = next == null
        ? '次走なし'
        : '${next['venue'] ?? ''} ${next['race_number'] ?? '?'}R ${next['post_time'] ?? ''}';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFFFF6B35).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _summaryChip('レース', '$total件', Icons.event_available),
              _summaryChip('AI予想', '$predicted/$total', Icons.psychology),
              _summaryChip('出走馬あり', '$entriesReady件', Icons.list_alt),
              _summaryChip('次走', nextLabel, Icons.schedule),
              FilledButton.icon(
                onPressed: _isPredicting || total == 0
                    ? null
                    : () => _runAiPredictions(),
                icon: _isPredicting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 16),
                label: Text(_isPredicting ? 'AI予想中' : '今日のAI予想を今すぐ生成'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
          if (_predictionStatus != null) ...[
            const SizedBox(height: 8),
            Text(
              _predictionStatus!,
              style: const TextStyle(
                color: Color(0xFFFFB199),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFFF6B35), size: 14),
          const SizedBox(width: 6),
          Text(
            '$label ',
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  int _venueSortRank(String venue) {
    const priority = {
      '東京': 0,
      '京都': 1,
      'シャンティン': 2,
      'シャティン': 2,
      'Sha Tin': 2,
      '沙田': 2,
    };
    return priority[venue] ?? 100;
  }

  Widget _buildTodayRacesList() {
    final hasPredictions = _todayRaces.any(_hasPrediction);

    // Win版#112: netkeiba 風 開催地別カラム表示
    final Map<String, List<Map<String, dynamic>>> byVenue = {};
    for (final race in _todayRaces) {
      final v = (race['venue'] as String? ?? '不明').trim();
      byVenue.putIfAbsent(v, () => []).add(race);
    }
    for (final list in byVenue.values) {
      list.sort((a, b) {
        final na = (a['race_number'] as num?)?.toInt() ?? 99;
        final nb = (b['race_number'] as num?)?.toInt() ?? 99;
        return na.compareTo(nb);
      });
    }
    final venues = byVenue.keys.toList()
      ..sort((a, b) {
        final rank = _venueSortRank(a).compareTo(_venueSortRank(b));
        if (rank != 0) return rank;
        return a.compareTo(b);
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
                    style: TextStyle(
                      color: Color(0xFFFF6B35),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final cols = w >= 1100
                  ? 4
                  : w >= 820
                      ? 3
                      : w >= 540
                          ? 2
                          : 1;
              if (cols == 1) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [
                    for (final v in venues) ...[
                      _buildVenueHeader(v, byVenue[v]!.length),
                      ...byVenue[v]!.map(_buildRaceCard),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final v in venues)
                      SizedBox(
                        width: (w - 12 * (cols + 1)) / cols,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildVenueHeader(v, byVenue[v]!.length),
                            ...byVenue[v]!.map(_buildRaceCard),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVenueHeader(String venue, int raceCount) {
    const narVenues = {
      '金沢',
      '園田',
      '姫路',
      '水沢',
      '門別',
      '盛岡',
      '浦和',
      '船橋',
      '大井',
      '川崎',
      '笠松',
      '名古屋',
      '高知',
      '佐賀',
      '帯広',
      '不明',
    };
    const overseasVenues = {'シャンティン', 'シャティン', 'Sha Tin', '沙田'};
    final isOverseas = overseasVenues.contains(venue);
    final isJra = !isOverseas && !narVenues.contains(venue);
    final color = isOverseas
        ? const Color(0xFF059669)
        : isJra
            ? const Color(0xFF2563EB)
            : const Color(0xFF7C3AED);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isOverseas
                ? Icons.flight_takeoff
                : isJra
                    ? Icons.stadium
                    : Icons.location_on,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            venue,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isOverseas
                  ? '海外'
                  : isJra
                      ? 'JRA'
                      : '地方',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
          ),
          const Spacer(),
          Text(
            '$raceCount R',
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
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
    // Win版#111: Supabase PostgREST embed は 1:M=List / 1:1=Map で返る。
    //   horse_entries: 1:M (List)
    //   horse_predictions / horse_results: 1:1 (Map or null)
    // 過去 (PS版#119) は Map だった時期もあり、List 戻りバージョンと両方対応する。
    final entries = _entriesOf(race);
    final pred = _firstMap(race['horse_predictions']);
    final result = _firstMap(race['horse_results']);
    final hasResult = result != null;
    final isCorrect = result?['is_prediction_correct'] as bool?;
    final trifectaPaid = (result?['trifecta_paid'] as num?)?.toInt();

    Color statusColor;
    String statusLabel;
    if (hasResult) {
      statusColor =
          isCorrect == true ? const Color(0xFF4CAF50) : const Color(0xFFE53935);
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
                height: 1.5,
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
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${raceNumber}R',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  raceName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
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
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          trailing: Chip(
            label: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 11, // ここにカンマを追加します
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            backgroundColor: statusColor.withValues(alpha: 0.12),
            padding: EdgeInsets.zero,
          ),
          children: [
            if (pred != null)
              _buildPredictionSection(pred, result, entries)
            else
              _buildInstantForecastSection(race, entries),
            if (entries.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                '出走馬',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ...entries.take(10).map((e) {
                    final en = e;
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
                      prevColor = const Color(0xFF4CAF50);
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
                        borderRadius: BorderRadius.circular(8),
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
                              height: 1.5,
                            ),
                          ),
                          if (prevStr != null)
                            Text(
                              prevStr,
                              style: TextStyle(
                                color: prevColor,
                                fontSize: 10,
                                height: 1.5,
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
                        color: Color(0xFF9CA3AF),
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                ],
              ),
            ],
            if (result != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isCorrect == true
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFE53935))
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (isCorrect == true
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFE53935))
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
                          color: isCorrect == true
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFE53935),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isCorrect == true ? '3連単 的中!' : '外れ',
                          style: TextStyle(
                            color: isCorrect == true
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFE53935),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        if (trifectaPaid != null && isCorrect == true) ...[
                          const SizedBox(width: 8),
                          Text(
                            '配当 ¥${NumberFormat('#,###').format(trifectaPaid)}',
                            style: const TextStyle(
                              color: Color(0xFF4CAF50),
                              fontWeight: FontWeight.bold,
                              height: 1.5,
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
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.auto_awesome, size: 14),
                  label: Text(pred == null ? 'このレースをAI予想' : 'AI再予想'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6B35),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  onPressed: _isPredicting
                      ? null
                      : () => _runAiPredictions(race: race),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.table_chart_outlined, size: 14),
                  label: const Text('詳細マトリックス'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6366F1),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HorseracingRaceDetailPage(race: race),
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

  Widget _buildInstantForecastSection(
    Map<String, dynamic> race,
    List<Map<String, dynamic>> entries,
  ) {
    if (entries.length < 3) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF9CA3AF).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.psychology_outlined,
              color: Color(0xFF9CA3AF),
              size: 18,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'AI予想未生成。出走馬データが3頭未満のため暫定指数も作れません。',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final ranked = _rankInstantForecast(entries);
    final top3 = ranked.take(3).toList();
    final dataSignals = top3.fold<int>(0, (sum, entry) {
      return sum +
          (entry['win_odds'] != null ? 1 : 0) +
          (entry['popularity'] != null ? 1 : 0) +
          (entry['prev_finish'] != null ? 1 : 0) +
          (entry['horse_weight_change'] != null ? 1 : 0);
    });
    final confidence = (0.48 + dataSignals * 0.025).clamp(0.48, 0.78);
    final names = top3.map((entry) {
      final number = (entry['horse_number'] as num?)?.toInt();
      final name = entry['horse_name'] as String? ?? '?';
      return number == null ? name : '$number.$name';
    }).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0D9488).withValues(alpha: 0.10),
            const Color(0xFFFF6B35).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed, color: Color(0xFF0D9488), size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '暫定指数予想',
                  style: TextStyle(
                    color: Color(0xFF0D9488),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '目安 ${(confidence * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Color(0xFF0D9488),
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _placeLabel('1着候補', names[0], const Color(0xFFFFC107)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child:
                    Icon(Icons.arrow_forward, color: Colors.white38, size: 14),
              ),
              _placeLabel('2着候補', names[1], const Color(0xFF9CA3AF)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child:
                    Icon(Icons.arrow_forward, color: Colors.white38, size: 14),
              ),
              _placeLabel('3着候補', names[2], const Color(0xFFA1887F)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'AI生成待ちでも使えるよう、単勝オッズ・人気・前走着順・馬体重変化から即時計算しています。投票前に「このレースをAI予想」で上書き確認してください。',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionSection(
    Map<String, dynamic> pred,
    Map<String, dynamic>? result,
    List<Map<String, dynamic>> entries,
  ) {
    final entryNames = entries
        .map((entry) => (entry['horse_name'] as String? ?? '').trim())
        .where((name) => name.isNotEmpty)
        .toList();
    final validNames = entryNames.toSet();
    final rawPicks = [
      pred['first_pick'] as String? ?? '',
      pred['second_pick'] as String? ?? '',
      pred['third_pick'] as String? ?? '',
    ];
    final picks = <String>[];
    for (final raw in rawPicks) {
      final pick = raw.trim();
      if (validNames.contains(pick) && !picks.contains(pick)) picks.add(pick);
    }
    for (final name in entryNames) {
      if (picks.length >= 3) break;
      if (!picks.contains(name)) picks.add(name);
    }
    final first = picks.isNotEmpty ? picks[0] : '?';
    final second = picks.length > 1 ? picks[1] : '?';
    final third = picks.length > 2 ? picks[2] : '?';
    final confidence = (pred['confidence'] as num?)?.toDouble() ?? 0.5;
    final reasoning = pred['ai_reasoning'] as String?;
    final wasCorrected = rawPicks.any(
      (pick) => pick.trim().isNotEmpty && !validNames.contains(pick.trim()),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B35).withValues(alpha: 0.08),
            const Color(0xFF3D5AFE).withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFFFF6B35).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: Color(0xFFFF6B35), size: 16),
              const SizedBox(width: 8),
              const Text(
                '低リスクAI予想',
                style: TextStyle(
                  color: Color(0xFFFF6B35),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '信頼度 ${(confidence * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Color(0xFFFF6B35),
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (wasCorrected) ...[
            const Text(
              '出走馬リスト外の候補を除外して表示しています。',
              style: TextStyle(
                color: Color(0xFFFFC107),
                fontSize: 11,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              _placeLabel('1着', first, const Color(0xFFFFC107)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child:
                    Icon(Icons.arrow_forward, color: Colors.white38, size: 14),
              ),
              _placeLabel('2着', second, const Color(0xFF9CA3AF)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child:
                    Icon(Icons.arrow_forward, color: Colors.white38, size: 14),
              ),
              _placeLabel('3着', third, const Color(0xFFA1887F)),
            ],
          ),
          if (reasoning != null && reasoning.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              reasoning,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 11,
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          _buildBetTypeGuide(first, second, third),
        ],
      ),
    );
  }

  Widget _buildBetTypeGuide(String first, String second, String third) {
    final bets = [
      ('複勝', first, '最小リスク'),
      ('単勝', first, '軸'),
      ('ワイド', '$first-$second / $first-$third', '堅め'),
      ('馬連', '$first-$second', '中リスク'),
      ('枠連', '$first-$secondの枠', '中リスク'),
      ('馬単', '$first→$second', '高め'),
      ('3連複', '$first-$second-$third', '高め'),
      ('3連単', '$first→$second→$third', '少額'),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final bet in bets)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              '${bet.$1}: ${bet.$2} (${bet.$3})',
              style: const TextStyle(
                color: Color(0xFFE5E7EB),
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ),
      ],
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
              height: 1.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.5,
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
            Icon(Icons.history, size: 64, color: Color(0xFF9CA3AF)),
            SizedBox(height: 8),
            Text(
              '予想履歴がありません',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
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
            label: Text(
              '未結果',
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
              ),
            ),
          );
        } else if (isCorrect == true) {
          cardBg = const Color(0xFF4CAF50).withValues(alpha: 0.06);
          trailing = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF4CAF50),
                size: 20,
              ),
              if (trifectaPaid != null)
                Text(
                  '¥${NumberFormat('#,###').format(trifectaPaid)}',
                  style: const TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
            ],
          );
        } else {
          cardBg = const Color(0xFFE53935).withValues(alpha: 0.04);
          trailing =
              const Icon(Icons.cancel, color: Color(0xFFE53935), size: 20);
        }
        return Card(
          color: cardBg,
          margin: const EdgeInsets.only(bottom: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.6,
              ),
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
                    height: 1.5,
                  ),
                ),
                Text(
                  '${venue != null ? '$venue · ' : ''}'
                  '$raceDate · 信頼度${(confidence * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
                if (hasResult)
                  Text(
                    '実際: ${result['first_place'] ?? '?'} - '
                    '${result['second_place'] ?? '?'} - '
                    '${result['third_place'] ?? '?'}',
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 11,
                      height: 1.5,
                    ),
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
                    height: 1.5,
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
                    height: 1.5,
                  ),
                ),
                Text(
                  '$resultsCount件の結果 / $hits件的中',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.6,
                  ),
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
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  '的中回数',
                  '$hits回',
                  Icons.check_circle,
                  const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
              const SizedBox(width: 8),
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
              height: 1.5,
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
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    pair.$2,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.5,
                    ),
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
      padding: const EdgeInsets.all(16),
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
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Color _gradeColor(String grade) {
    if (grade.startsWith('G1')) return const Color(0xFFFFC107);
    if (grade.startsWith('G2')) return const Color(0xFFD1D5DB);
    if (grade.startsWith('G3')) return const Color(0xFFA1887F);
    if (grade == 'リステッド') return const Color(0xFF64B5F6);
    if (grade == 'オープン') return const Color(0xFFBA68C8);
    return const Color(0xFF4B5563);
  }
}
