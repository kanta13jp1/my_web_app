import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 競馬予想・分析ページ
/// horse-racing-predictor Edge Function と連携
/// netkeiba 競合 — レース管理・AI予想スコア・回収率統計
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
  String? _error;

  List<Map<String, dynamic>> _races = [];
  List<Map<String, dynamic>> _predictions = [];
  Map<String, dynamic>? _stats;

  // Register race form
  final _raceNameCtrl = TextEditingController();
  final _raceDateCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  String _selectedRaceType = '芝';
  String _selectedGrade = '未勝利';

  // Predict form
  String? _selectedRaceId;
  final _horseNameCtrl = TextEditingController();
  final _stakeCtrl = TextEditingController(text: '100');
  int _confidence = 50;
  String _betType = '単勝';

  static const _grades = [
    'G1', 'G2', 'G3', 'リステッド', 'オープン',
    '3勝', '2勝', '1勝', '未勝利', '新馬',
  ];
  static const _raceTypes = ['芝', 'ダート', '障害'];
  static const _betTypes = ['単勝', '複勝', '馬連', '馬単', '三連複', '三連単'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _raceNameCtrl.dispose();
    _raceDateCtrl.dispose();
    _venueCtrl.dispose();
    _horseNameCtrl.dispose();
    _stakeCtrl.dispose();
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
          body: {'action': 'horseracing.list_races'},
        ),
        _supabase.functions.invoke(
          'tools-hub',
          body: {'action': 'horseracing.list_predictions'},
        ),
        _supabase.functions.invoke(
          'tools-hub',
          body: {'action': 'horseracing.stats'},
        ),
      ]);

      final racesData = results[0].data;
      if (racesData is Map && racesData['races'] is List) {
        _races =
            (racesData['races'] as List).cast<Map<String, dynamic>>();
      } else {
        _races = [];
      }

      final predsData = results[1].data;
      if (predsData is Map && predsData['predictions'] is List) {
        _predictions =
            (predsData['predictions'] as List).cast<Map<String, dynamic>>();
      } else {
        _predictions = [];
      }

      final statsData = results[2].data;
      if (statsData is Map && statsData['stats'] is Map) {
        _stats = statsData['stats'] as Map<String, dynamic>;
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'データ取得失敗: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerRace() async {
    final name = _raceNameCtrl.text.trim();
    final date = _raceDateCtrl.text.trim();
    if (name.isEmpty || date.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('レース名と日程は必須です')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'horseracing.register_race',
          'name': name,
          'date': date,
          'venue': _venueCtrl.text.trim().isEmpty
              ? null
              : _venueCtrl.text.trim(),
          'race_type': _selectedRaceType,
          'grade': _selectedGrade,
        },
      );
      _raceNameCtrl.clear();
      _raceDateCtrl.clear();
      _venueCtrl.clear();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('レースを登録しました')),
        );
      }
      await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('登録失敗: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _predict() async {
    if (_selectedRaceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('レースを選択してください')),
      );
      return;
    }
    final horseName = _horseNameCtrl.text.trim();
    if (horseName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('馬名を入力してください')),
      );
      return;
    }
    final stakeText = _stakeCtrl.text.trim();
    final stake = int.tryParse(stakeText) ?? 100;
    setState(() => _isLoading = true);
    try {
      await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'horseracing.predict',
          'race_id': _selectedRaceId,
          'horse_name': horseName,
          'bet_type': _betType,
          'stake': stake,
          'confidence': _confidence,
        },
      );
      _horseNameCtrl.clear();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('予想を記録しました')),
        );
      }
      await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('記録失敗: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRegisterRaceDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('レース登録'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _raceNameCtrl,
                decoration: const InputDecoration(labelText: 'レース名 *'),
              ),
              TextField(
                controller: _raceDateCtrl,
                decoration:
                    const InputDecoration(labelText: '開催日 * (YYYY-MM-DD)'),
                keyboardType: TextInputType.datetime,
              ),
              TextField(
                controller: _venueCtrl,
                decoration:
                    const InputDecoration(labelText: '競馬場 (例: 東京)'),
              ),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (ctx2, setSt) => Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRaceType,
                      decoration: const InputDecoration(labelText: 'コース種別'),
                      items: _raceTypes
                          .map(
                            (t) =>
                                DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setSt(() => _selectedRaceType = v);
                          setState(() => _selectedRaceType = v);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedGrade,
                      decoration: const InputDecoration(labelText: 'グレード'),
                      items: _grades
                          .map(
                            (g) =>
                                DropdownMenuItem(value: g, child: Text(g)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setSt(() => _selectedGrade = v);
                          setState(() => _selectedGrade = v);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: _registerRace,
            child: const Text('登録'),
          ),
        ],
      ),
    );
  }

  void _showPredictDialog() {
    if (_races.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先にレースを登録してください')),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('予想を記録'),
        content: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (ctx2, setSt) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedRaceId,
                  hint: const Text('レースを選択'),
                  decoration: const InputDecoration(labelText: 'レース'),
                  items: _races
                      .map(
                        (r) => DropdownMenuItem(
                          value: r['race_id'] as String?,
                          child: Text(
                            r['name'] as String? ?? 'レース',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setSt(() => _selectedRaceId = v);
                    setState(() => _selectedRaceId = v);
                  },
                ),
                TextField(
                  controller: _horseNameCtrl,
                  decoration: const InputDecoration(labelText: '馬名 *'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _betType,
                  decoration: const InputDecoration(labelText: '券種'),
                  items: _betTypes
                      .map(
                        (b) => DropdownMenuItem(value: b, child: Text(b)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setSt(() => _betType = v);
                      setState(() => _betType = v);
                    }
                  },
                ),
                TextField(
                  controller: _stakeCtrl,
                  decoration: const InputDecoration(labelText: '投資額 (円)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                Text('自信度: $_confidence%'),
                Slider(
                  value: _confidence.toDouble(),
                  min: 10,
                  max: 100,
                  divisions: 9,
                  label: '$_confidence%',
                  onChanged: (v) {
                    setSt(() => _confidence = v.toInt());
                    setState(() => _confidence = v.toInt());
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: _predict,
            child: const Text('記録'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('競馬予想・分析'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.emoji_events), text: 'レース'),
            Tab(icon: Icon(Icons.analytics), text: '予想'),
            Tab(icon: Icon(Icons.bar_chart), text: '成績'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
            tooltip: '更新',
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'predict',
            onPressed: _showPredictDialog,
            tooltip: '予想を記録',
            child: const Icon(Icons.psychology),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'race',
            onPressed: _showRegisterRaceDialog,
            icon: const Icon(Icons.add),
            label: const Text('レース登録'),
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
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                      FilledButton(onPressed: _loadAll, child: const Text('再試行')),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRacesTab(),
                    _buildPredictionsTab(),
                    _buildStatsTab(),
                  ],
                ),
    );
  }

  Widget _buildRacesTab() {
    if (_races.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports, size: 64, color: Colors.grey),
            SizedBox(height: 8),
            Text('レースがまだありません'),
            SizedBox(height: 4),
            Text(
              'レース登録からAI予想を始めましょう',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _races.length,
      itemBuilder: (ctx, i) {
        final race = _races[i];
        final name = race['name'] as String? ?? 'レース';
        final date = race['date'] as String? ?? '';
        final venue = race['venue'] as String?;
        final raceType = race['race_type'] as String? ?? '芝';
        final grade = race['grade'] as String? ?? '';
        final distance = (race['distance'] as num?)?.toInt();
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _gradeColor(grade).withValues(alpha: 0.15),
              child: Text(
                grade.length > 2 ? grade.substring(0, 2) : grade,
                style: TextStyle(
                  color: _gradeColor(grade),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(name),
            subtitle: Text(
              [
                date,
                if (venue != null) venue,
                '$raceType${distance != null ? ' ${distance}m' : ''}',
              ].join(' · '),
            ),
            trailing: Chip(
              label: Text(grade),
              backgroundColor:
                  _gradeColor(grade).withValues(alpha: 0.15),
              labelStyle: TextStyle(color: _gradeColor(grade), fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPredictionsTab() {
    if (_predictions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.psychology_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 8),
            Text('予想記録がまだありません'),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _predictions.length,
      itemBuilder: (ctx, i) {
        final p = _predictions[i];
        final horse = p['horse_name'] as String? ?? '?';
        final betType = p['bet_type'] as String? ?? '単勝';
        final stake = (p['stake'] as num?)?.toInt() ?? 0;
        final confidence = (p['confidence'] as num?)?.toInt() ?? 0;
        final result = p['result'] as String? ?? 'pending';
        final payout = (p['payout'] as num?)?.toInt() ?? 0;
        final isWin = result == 'win';
        final isPending = result == 'pending';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isPending
                  ? Colors.grey.withValues(alpha: 0.15)
                  : isWin
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.red.withValues(alpha: 0.15),
              child: Icon(
                isPending
                    ? Icons.hourglass_empty
                    : isWin
                        ? Icons.check
                        : Icons.close,
                color: isPending
                    ? Colors.grey
                    : isWin
                        ? Colors.green
                        : Colors.red,
              ),
            ),
            title: Text(horse),
            subtitle: Text('$betType · ¥$stake · 自信度: $confidence%'),
            trailing: isPending
                ? const Chip(label: Text('未結果'))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isWin ? '+¥$payout' : '-¥$stake',
                        style: TextStyle(
                          color: isWin ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildStatsTab() {
    if (_stats == null) {
      return const Center(child: Text('成績データがありません'));
    }
    final totalBets = (_stats!['totalBets'] as num?)?.toInt() ?? 0;
    final wins = (_stats!['wins'] as num?)?.toInt() ?? 0;
    final winRate = (_stats!['winRate'] as num?)?.toInt() ?? 0;
    final roi = (_stats!['roi'] as num?)?.toInt() ?? 0;
    final totalStake = (_stats!['totalStake'] as num?)?.toInt() ?? 0;
    final totalReturn = (_stats!['totalReturn'] as num?)?.toInt() ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _statCard(
                  '総予想数',
                  '$totalBets回',
                  Icons.history,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  '的中数',
                  '$wins回',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  '的中率',
                  '$winRate%',
                  Icons.percent,
                  winRate >= 30 ? Colors.green : Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  '回収率',
                  '$roi%',
                  Icons.trending_up,
                  roi >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '収支サマリー',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _summaryRow('総投資額', '¥$totalStake', Colors.orange),
                  const Divider(),
                  _summaryRow('総回収額', '¥$totalReturn', Colors.blue),
                  const Divider(),
                  _summaryRow(
                    '損益',
                    '${totalReturn - totalStake >= 0 ? '+' : ''}¥${totalReturn - totalStake}',
                    totalReturn - totalStake >= 0 ? Colors.green : Colors.red,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Color _gradeColor(String grade) {
    if (grade.startsWith('G1')) return Colors.red;
    if (grade.startsWith('G2')) return Colors.orange;
    if (grade.startsWith('G3')) return Colors.purple;
    if (grade == 'オープン' || grade == 'リステッド') return Colors.blue;
    return Colors.grey;
  }
}
