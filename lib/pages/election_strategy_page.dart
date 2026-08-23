import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

class ElectionStrategyPage extends StatefulWidget {
  const ElectionStrategyPage({super.key});

  @override
  State<ElectionStrategyPage> createState() => _ElectionStrategyPageState();
}

class _ElectionStrategyPageState extends State<ElectionStrategyPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  // タブ: 戦況マップ / 予測 / 地上戦 / 戦略 / 素材
  @override
  List<String> get tabUrlSlugs => const <String>[
        'map',
        'forecast',
        'ground-game',
        'strategy',
        'assets',
      ];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  final TextEditingController _strategyController = TextEditingController();
  late TabController _tabController;
  bool _isBusy = false;

  // データ
  String _myDistrict = '';
  String _candidateInfo = '';
  String _victoryCondition = '';
  List<Map<String, dynamic>> _stationData = [];
  List<Map<String, dynamic>> _candidates = []; // 候補者データ

  // シミュレーション値
  double _supportRate = 6.0;
  double _youthTurnout = 35.0;
  double _swingCapture = 20.0;

  Map<String, dynamic>? _lastBatchLog;

  @override
  void initState() {
    super.initState();
    // タブ: 0:マップ, 1:予測, 2:地上戦, 3:戦略, 4:素材
    _tabController = TabController(length: 5, vsync: this);

    // タブ切り替え時にFABの表示を更新するためにリスナーを追加
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });

    _fetchUserProfile();
    _fetchCandidates();
    _fetchBatchLog(); // 初期化時にログも取得
  }

// ★ 最新のバッチログを取得
  Future<void> _fetchBatchLog() async {
    try {
      final data = await _supabase
          .from('batch_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (mounted) {
        setState(() => _lastBatchLog = data);
      }
    } catch (e) {
      debugPrint('Log fetch error: $e');
    }
  }

  // Gemini calls are proxied through ai-assistant Edge Function (server-side key)
  Future<String> _callGeminiViaEdge(
    String prompt, {
    String model = 'gemini-2.5-flash',
    String? imageBase64,
    String? mimeType,
  }) async {
    if (_supabase.auth.currentUser == null) return '';
    final body = <String, dynamic>{
      'action': 'generate',
      'model': model,
      'content': prompt,
      'useMagi': false,
    };
    if (imageBase64 != null) body['imageBase64'] = imageBase64;
    if (mimeType != null) body['mimeType'] = mimeType;
    final response =
        await _supabase.functions.invoke('ai-assistant', body: body);
    final data = response.data;
    if (data is Map<String, dynamic> && data['success'] == true) {
      return (data['result'] as String?) ?? '';
    }
    final errMsg = (data is Map ? data['error'] : null) ?? 'AI処理に失敗しました';
    throw Exception(errMsg);
  }

  // --- Profile Logic ---
  Future<void> _fetchUserProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await _supabase
          .from('user_profiles')
          .select('election_district')
          .eq('user_id', userId)
          .maybeSingle();

      if (data != null && data['election_district'] != null) {
        setState(() => _myDistrict = data['election_district']);
        _fetchDistrictAnalysis(data['election_district']);
        _fetchLogistics(data['election_district']);
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
  }

  Future<void> _updateDistrict(String district) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('user_profiles').upsert({
        'user_id': userId,
        'election_district': district,
        'updated_at': DateTime.now().toIso8601String(),
      });
      setState(() => _myDistrict = district);
      _fetchDistrictAnalysis(district);
      _fetchLogistics(district);

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('選挙区を保存しました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存エラー: $e')));
      }
    }
  }

  // --- Map & Candidates Logic ---
  Future<void> _fetchCandidates() async {
    try {
      final data = await _supabase.from('candidates').select();
      if (!mounted) return;
      setState(() {
        _candidates = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('Error fetching candidates: $e');
    }
  }

  // ★ GitHub Actionsを手動トリガー (Edge Function経由)
  Future<void> _triggerBatchAnalysis() async {
    if (_supabase.auth.currentUser == null) return;
    setState(() => _isBusy = true);
    try {
      final response = await _supabase.functions
          .invoke('ai-hub', body: {'action': 'trigger.analyze'});

      if (mounted) {
        if (response.status == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('AI分析バッチを開始しました。完了まで数分かかります。'),
              backgroundColor: Color(0xFF009688),
              duration: Duration(seconds: 4),
            ),
          );
        } else {
          throw Exception('Status Code: ${response.status}');
        }
      }
      await Future.delayed(const Duration(seconds: 3)); // ログ書き込み待ち
      await _fetchBatchLog();
      await _fetchCandidates(); // マップデータも更新
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('起動エラー: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // --- Logistics Logic ---
  Future<void> _fetchLogistics(String district) async {
    try {
      final data = await _supabase
          .from('district_logistics')
          .select()
          .eq('district_name', district)
          .maybeSingle();
      if (data != null && data['station_data'] != null) {
        setState(() {
          _stationData = List<Map<String, dynamic>>.from(data['station_data']);
        });
      } else {
        _analyzeLogistics(district);
      }
    } catch (e) {
      debugPrint('Logistics Error: $e');
    }
  }

  Future<void> _analyzeLogistics(String district) async {
    setState(() => _isBusy = true);
    try {
      final prompt = '''
      あなたは選挙参謀です。「$district」に含まれる主要な鉄道駅を最大10個リストアップし、
      1日あたりの推定乗降客数（概算）と共にJSONで出力してください。
      乗降客数が多い順にソートしてください。
      出力形式: [{"name": "駅名", "passengers": 数値, "importance": "S/A/B"}]
      ''';
      final jsonText = await _callGeminiViaEdge(prompt);
      final List<dynamic> rawList = jsonDecode(jsonText);
      final List<Map<String, dynamic>> stations =
          rawList.map((e) => Map<String, dynamic>.from(e)).toList();

      setState(() => _stationData = stations);

      await _supabase.from('district_logistics').upsert({
        'district_name': district,
        'station_data': stations,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('AI Logistics Error: $e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // --- District Analysis Logic ---
  Future<void> _fetchDistrictAnalysis(String district) async {
    final data = await _supabase
        .from('district_analytics')
        .select()
        .eq('district_name', district)
        .maybeSingle();
    if (data != null) {
      setState(() {
        _candidateInfo = data['candidate_info'] ?? '';
        _victoryCondition = data['victory_condition'] ?? '';
      });
    } else {
      _analyzeDistrict(district);
    }
  }

  Future<void> _analyzeDistrict(String district) async {
    setState(() => _isBusy = true);
    try {
      final prompt =
          'あなたは選挙アナリストです。「$district」の国民民主党の情勢(候補者、勝利条件)を分析しJSON({candidate, condition})で出力してください。';
      final Map<String, dynamic> json =
          jsonDecode(await _callGeminiViaEdge(prompt)) as Map<String, dynamic>;
      setState(() {
        _candidateInfo = (json['candidate'] as String?)?.isNotEmpty == true
            ? json['candidate'] as String
            : '情報なし';
        _victoryCondition = (json['condition'] as String?)?.isNotEmpty == true
            ? json['condition'] as String
            : '分析不能';
      });
      await _supabase.from('district_analytics').upsert({
        'district_name': district,
        'candidate_info': _candidateInfo,
        'victory_condition': _victoryCondition,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // --- Trends Logic ---
  Future<void> _fetchLatestTrends() async {
    setState(() => _isBusy = true);
    try {
      const prompt =
          '2026年1月現在の最新世論調査に基づき、国民民主党の支持率(support_rate)、若年投票率(youth_turnout)、無党派獲得率(swing_potential)を推計しJSONで出力せよ。';
      final Map<String, dynamic> data =
          jsonDecode(await _callGeminiViaEdge(prompt)) as Map<String, dynamic>;
      setState(() {
        _supportRate = ((data['support_rate'] as num?) ?? 0).toDouble();
        _youthTurnout = ((data['youth_turnout'] as num?) ?? 0).toDouble();
        _swingCapture = ((data['swing_potential'] as num?) ?? 0).toDouble();
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('最新トレンドを反映しました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エラー: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // --- Strategy Logic ---
  Future<void> _submitStrategy() async {
    if (_strategyController.text.isEmpty) return;
    setState(() => _isBusy = true);
    try {
      final prompt = '''
      選挙コンサルとして以下の戦略を評価し、より有権者に響くキャッチコピーにリライトしてください。
      戦略: ${_strategyController.text}
      選挙区: $_myDistrict
      出力形式: Score: [0-100] Feedback: [評価] Rewrite: [改善案]
      ''';
      final text = await _callGeminiViaEdge(prompt);
      int score = 50;
      String feedback = text;
      final scoreMatch = RegExp(r'Score:\s*(\d+)').firstMatch(text);
      if (scoreMatch != null) {
        score = int.parse(scoreMatch.group(1)!);
        feedback = text.replaceAll(scoreMatch.group(0)!, '').trim();
      }
      await _supabase.from('election_strategies').insert({
        'user_id': _supabase.auth.currentUser!.id,
        'content': _strategyController.text,
        'ai_feedback': feedback,
        'impact_score': score,
      });
      if (mounted) {
        _strategyController.clear();
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('AIスコア: $score点')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エラー: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // --- Vision Logic ---
  Future<void> _pickAndAnalyzeImage() async {
    final picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (image == null) return;
    if (!mounted) return;
    setState(() => _isBusy = true);
    try {
      final bytes = await image.readAsBytes();
      const prompt = '''
      選挙ポスター診断:
      1. インパクトと視認性
      2. 「手取りを増やす」のメッセージ性
      3. 印象評価
      出力: Score: [0-100] Advice: [詳細]
      ''';
      final text = await _callGeminiViaEdge(
        prompt,
        imageBase64: base64Encode(bytes),
        mimeType: 'image/jpeg',
      );
      int score = 50;
      String advice = text;
      final scoreMatch = RegExp(r'Score:\s*(\d+)').firstMatch(text);
      if (scoreMatch != null) {
        score = int.parse(scoreMatch.group(1)!);
        advice = text
            .replaceAll(scoreMatch.group(0)!, '')
            .trim()
            .replaceAll('Advice:', '')
            .trim();
      }
      await _supabase.from('campaign_diagnostics').insert({
        'user_id': _supabase.auth.currentUser!.id,
        'material_type': 'poster',
        'ai_feedback': advice,
        'score': score,
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('診断スコア: $score点')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('画像分析エラー: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // --- UI Components ---

  void _showDistrictDialog() {
    final controller = TextEditingController(text: _myDistrict);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('選挙区の設定'),
        content: TextField(
          controller: controller,
          decoration:
              const InputDecoration(labelText: '選挙区名', hintText: '例: 東京1区'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              _updateDistrict(controller.text);
              Navigator.pop(context);
            },
            child: const Text('保存・分析'),
          ),
        ],
      ),
    );
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '戦略を提案',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _strategyController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '具体的なアクションを入力...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isBusy ? null : _submitStrategy,
                icon: const Icon(Icons.psychology),
                label: const Text('AI分析・推敲して投稿'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showManualDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.menu_book, color: Color(0xFF3D5AFE)),
            SizedBox(width: 8),
            Text('利用マニュアル'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ManualItem(
                icon: Icons.map,
                title: '1. 戦況マップ (New)',
                desc: '全国の候補者の優勢・劣勢を可視化。右下の脳アイコンでAI一斉分析バッチを実行できます。',
              ),
              _ManualItem(
                icon: Icons.train,
                title: '2. 地上戦ロジスティクス',
                desc: '主要駅データをAI分析し、Sランク(重点)駅を表示します。',
              ),
              _ManualItem(
                icon: Icons.auto_graph,
                title: '3. トレンド分析',
                desc: '最新の支持率データを反映し議席予測を行います。',
              ),
              _ManualItem(
                icon: Icons.lightbulb,
                title: '4. 戦略・素材',
                desc: '戦略投稿のAI推敲、ポスターの画像診断が可能です。',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  void _showCandidateDetail(Map<String, dynamic> cand) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${cand['district']} : ${cand['name']}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('当選確率: '),
                Text(
                  '${cand['win_probability']}%',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE53935),
                    height: 1.5,
                  ),
                ),
              ],
            ),
            const Divider(),
            const Text(
              'AI情勢分析 (Batch Updated):',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(cand['ai_analysis'] ?? '分析データなし'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('2026 勝利戦略室'),
        backgroundColor: const Color(0xFF3D5AFE),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _myDistrict.isEmpty ? Icons.location_off : Icons.location_on,
            ),
            onPressed: _showDistrictDialog,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showManualDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xB3FFFFFF),
          indicatorColor: const Color(0xFFFFC107),
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.map), text: '戦況マップ'),
            Tab(icon: Icon(Icons.poll), text: '予測'),
            Tab(icon: Icon(Icons.train), text: '地上戦'),
            Tab(icon: Icon(Icons.lightbulb), text: '戦略'),
            Tab(icon: Icon(Icons.image), text: '素材'),
          ],
        ),
      ),
      body: _isBusy && !mounted
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildMapTab(),
                _buildSimulationTab(),
                _buildLogisticsTab(),
                _buildStrategyFeedTab(),
                _buildMaterialDiagnosticsTab(),
              ],
            ),
      floatingActionButton: _tabController.index == 3
          ? FloatingActionButton.extended(
              onPressed: _showAddDialog,
              backgroundColor: const Color(0xFFE53935),
              icon: const Icon(Icons.add_comment, color: Colors.white),
              label: const Text('戦略投稿'),
            )
          : null,
    );
  }

  // --- Tab 1: Map ---
  Widget _buildMapTab() {
    return Stack(
      children: [
        FlutterMap(
          options: const MapOptions(
            initialCenter: LatLng(35.681236, 139.767125), // 東京中心
            initialZoom: 9.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.app',
            ),
            MarkerLayer(
              markers: _candidates.map((cand) {
                final prob = cand['win_probability'] as int? ?? 50;
                final color = prob >= 80
                    ? const Color(0xFFE53935)
                    : (prob >= 50
                        ? const Color(0xFFFF6B35)
                        : const Color(0xFF3D5AFE));
                return Marker(
                  point: LatLng(cand['latitude'], cand['longitude']),
                  width: 60,
                  height: 60,
                  child: GestureDetector(
                    onTap: () => _showCandidateDetail(cand),
                    child: Column(
                      children: [
                        Icon(Icons.location_on, color: color, size: 40),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${cand['win_probability']}%',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
// ▼▼▼ 追加: システム稼働状況パネル (左上) ▼▼▼
        Positioned(
          top: 16,
          left: 16,
          child: GestureDetector(
            onTap: _showLogDetail, // タップで詳細表示
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHigh
                    .withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Color(0x42000000), blurRadius: 4),
                ],
              ),
              child: Row(
                children: [
                  // ステータスに応じたアイコン
                  if (_isBusy)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (_lastBatchLog?['status'] == 'SUCCESS')
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF4CAF50),
                      size: 16,
                    )
                  else if (_lastBatchLog?['status'] == 'ERROR')
                    const Icon(Icons.error, color: Color(0xFFE53935), size: 16)
                  else
                    const Icon(
                      Icons.access_time,
                      color: Color(0xFF9CA3AF),
                      size: 16,
                    ),

                  const SizedBox(width: 8),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI戦略本部システム',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3D5AFE),
                          height: 1.5,
                        ),
                      ),
                      Text(
                        _isBusy
                            ? '分析実行中...'
                            : _formatLogDate(_lastBatchLog?['created_at']),
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // ▲▲▲ 追加ここまで ▲▲▲
        // 操作ボタン群
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // バッチ実行ボタン (AI)
              FloatingActionButton.small(
                heroTag: 'btn_analyze',
                backgroundColor: const Color(0xFF3D5AFE),
                onPressed: _isBusy ? null : _triggerBatchAnalysis,
                tooltip: '全選挙区のAI再分析を実行',
                child: _isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.psychology, color: Colors.white),
              ),
              const SizedBox(height: 12),
              // データ再取得ボタン
              FloatingActionButton.small(
                heroTag: 'btn_refresh',
                backgroundColor: Theme.of(context).colorScheme.surface,
                onPressed: _fetchCandidates,
                tooltip: '最新データを読み込み',
                child: const Icon(Icons.refresh, color: Color(0xFF3D5AFE)),
              ),
            ],
          ),
        ),

        // ステータス表示
        if (_isBusy)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'AI総本部: 情勢分析中...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

// 日付フォーマット用ヘルパー
  String _formatLogDate(String? isoString) {
    if (isoString == null) return 'データなし';
    try {
      final date = DateTime.parse(isoString).toLocal();
      // 簡易フォーマット (パッケージなしで実装)
      return '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')} 更新';
    } catch (e) {
      return '不明';
    }
  }

  // ログ詳細ダイアログ
  void _showLogDetail() {
    if (_lastBatchLog == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('バッチ実行結果'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _logRow('ステータス', _lastBatchLog!['status']),
            _logRow('実行日時', _formatLogDate(_lastBatchLog!['created_at'])),
            _logRow('処理件数', '${_lastBatchLog!['records_processed']} 件'),
            const SizedBox(height: 8),
            const Text(
              'メッセージ:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Text(
                _lastBatchLog!['message'] ?? '',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Widget _logRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Tab 2: Simulation ---
  Widget _buildSimulationTab() {
    int seats = (10 +
            (_supportRate * 3.5) +
            (_youthTurnout * 0.5) +
            (_swingCapture * 0.5))
        .toInt();
    if (seats > 465) seats = 465;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_myDistrict.isNotEmpty)
            Card(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1A1A2E)
                  : const Color(0xFFE8EAF6),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_myDistrict 分析レポート',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3D5AFE),
                        height: 1.5,
                      ),
                    ),
                    const Divider(),
                    Text('候補者: $_candidateInfo'),
                    const SizedBox(height: 8),
                    Text(
                      '条件: $_victoryCondition',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    '獲得予測議席',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      height: 1.5,
                    ),
                  ),
                  Text(
                    '$seats / 465',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3D5AFE),
                      height: 1.5,
                    ),
                  ),
                  if (seats >= 233)
                    const Text(
                      '過半数獲得圏内！',
                      style: TextStyle(
                        color: Color(0xFFE53935),
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isBusy ? null : _fetchLatestTrends,
            icon: const Icon(Icons.auto_graph),
            label: const Text('最新トレンドをAI分析して反映'),
          ),
          const SizedBox(height: 16),
          _slider(
            '党支持率',
            _supportRate,
            0,
            60,
            (v) => setState(() => _supportRate = v),
            const Color(0xFFFF6B35),
          ),
          _slider(
            '若年層投票率',
            _youthTurnout,
            20,
            80,
            (v) => setState(() => _youthTurnout = v),
            const Color(0xFF3D5AFE),
          ),
          _slider(
            '無党派層獲得',
            _swingCapture,
            0,
            100,
            (v) => setState(() => _swingCapture = v),
            const Color(0xFF4CAF50),
          ),
        ],
      ),
    );
  }

  Widget _slider(
    String label,
    double val,
    double min,
    double max,
    ValueChanged<double> onChanged,
    Color color,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            Text(
              '${val.toStringAsFixed(1)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                height: 1.5,
              ),
            ),
          ],
        ),
        Slider(
          value: val,
          min: min,
          max: max,
          activeColor: color,
          onChanged: onChanged,
        ),
      ],
    );
  }

  // --- Tab 3: Logistics ---
  Widget _buildLogisticsTab() {
    if (_myDistrict.isEmpty) {
      return const Center(child: Text('まずは右上のアイコンから\n選挙区を設定してください。'));
    }
    if (_stationData.isEmpty && !_isBusy) {
      return Center(
        child: FilledButton.icon(
          onPressed: () => _analyzeLogistics(_myDistrict),
          icon: const Icon(Icons.search),
          label: const Text('主要駅と乗降客数を分析'),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _stationData.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 16.0),
            child: Text(
              '重点駅リスト (AI推計)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3D5AFE),
                height: 1.5,
              ),
            ),
          );
        }
        final station = _stationData[index - 1];
        final passengers = station['passengers'] as int? ?? 0;
        final rank = station['importance'] ?? 'B';
        final isS = rank == 'S';
        return Card(
          elevation: isS ? 4 : 1,
          color: isS
              ? (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFE53935).withAlpha(40)
                  : const Color(0xFFFFEBEE))
              : Theme.of(context).colorScheme.surface,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  isS ? const Color(0xFFE53935) : const Color(0xFF3D5AFE),
              child: Text(
                rank,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
            ),
            title: Text(
              station['name'] ?? '',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            subtitle:
                Text('推定乗降客数: ${(passengers / 10000).toStringAsFixed(1)}万人/日'),
          ),
        );
      },
    );
  }

  // --- Tab 4: Strategy Feed ---
  Widget _buildStrategyFeedTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from('election_strategies')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(50),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) return const Center(child: Text('まだ戦略がありません'));
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final score = item['impact_score'] as int? ?? 0;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: score >= 80
                      ? const Color(0xFFFFCDD2)
                      : Theme.of(context).colorScheme.surfaceContainerHigh,
                  child: Text('$score'),
                ),
                title: Text(item['content'] ?? ''),
                subtitle: Text(item['ai_feedback'] ?? ''),
              ),
            );
          },
        );
      },
    );
  }

  // --- Tab 5: Material Diagnostics ---
  Widget _buildMaterialDiagnosticsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: FilledButton.icon(
            onPressed: _isBusy ? null : _pickAndAnalyzeImage,
            icon: const Icon(Icons.camera_alt),
            label: const Text('ポスター/チラシを撮影・診断'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: const Color(0xFF009688),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _supabase
                .from('campaign_diagnostics')
                .stream(primaryKey: ['id'])
                .order('created_at', ascending: false)
                .limit(20),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snapshot.data!;
              if (items.isEmpty) return const Center(child: Text('履歴がありません'));
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final score = item['score'] as int? ?? 0;
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: Icon(
                        Icons.image,
                        color: score >= 80
                            ? const Color(0xFF009688)
                            : const Color(0xFF9CA3AF),
                      ),
                      title: Text(
                        '診断スコア: $score点',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                      ),
                      subtitle: Text(item['ai_feedback'] ?? ''),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ManualItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _ManualItem({
    required this.icon,
    required this.title,
    required this.desc,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF3D5AFE)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
