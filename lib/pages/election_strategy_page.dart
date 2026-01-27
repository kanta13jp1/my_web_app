import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

class ElectionStrategyPage extends StatefulWidget {
  const ElectionStrategyPage({super.key});

  @override
  State<ElectionStrategyPage> createState() => _ElectionStrategyPageState();
}

class _ElectionStrategyPageState extends State<ElectionStrategyPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  String? _apiKey;
  final TextEditingController _strategyController = TextEditingController();
  late TabController _tabController;
  bool _isBusy = false;

  // データ
  String _myDistrict = '';
  String _candidateInfo = '';
  String _victoryCondition = '';
  List<Map<String, dynamic>> _stationData = []; // 駅データ

  // シミュレーション値
  double _supportRate = 6.0;
  double _youthTurnout = 35.0;
  double _swingCapture = 20.0;

  @override
  void initState() {
    super.initState();
    // タブを4つに増加 (予測, 地上戦, 戦略, 素材)
    _tabController = TabController(length: 4, vsync: this);
    _loadApiKey();
    _fetchUserProfile();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('gemini_api_key');
    });
  }

  Future<void> _fetchUserProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    final data = await _supabase
        .from('user_profiles')
        .select('election_district')
        .eq('user_id', userId)
        .maybeSingle();
    if (data != null && data['election_district'] != null) {
      setState(() => _myDistrict = data['election_district']);
      _fetchDistrictAnalysis(data['election_district']);
      _fetchLogistics(data['election_district']); // 物流データも取得
    }
  }

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

  // ★ 駅データの取得（キャッシュ or AI）
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

  // ★ AIによる駅データ分析
  Future<void> _analyzeLogistics(String district) async {
    if (_apiKey == null) return;
    setState(() => _isBusy = true);

    try {
      final model = GenerativeModel(
        model: 'models/gemini-2.5-flash',
        apiKey: _apiKey!,
        generationConfig:
            GenerationConfig(responseMimeType: 'application/json'),
      );

      final prompt = '''
      あなたは選挙参謀です。「$district」に含まれる主要な鉄道駅を最大10個リストアップし、
      1日あたりの推定乗降客数（概算）と共にJSONで出力してください。
      乗降客数が多い順にソートしてください。

      出力フォーマット:
      [
        {"name": "駅名", "passengers": 数値(人), "importance": "S/A/Bのランク"},
        ...
      ]
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      final jsonText = response.text ?? '[]';
      final List<dynamic> rawList = jsonDecode(jsonText);
      final List<Map<String, dynamic>> stations =
          rawList.map((e) => Map<String, dynamic>.from(e)).toList();

      setState(() => _stationData = stations);

      // キャッシュ保存
      await _supabase.from('district_logistics').upsert({
        'district_name': district,
        'station_data': stations,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('AI Logistics Error: $e');
    } finally {
      setState(() => _isBusy = false);
    }
  }

  // 既存メソッド群 (省略せず記述)
  Future<void> _analyzeDistrict(String district) async {
    if (_apiKey == null) return;
    setState(() => _isBusy = true);
    try {
      final model = GenerativeModel(
          model: 'models/gemini-2.5-flash',
          apiKey: _apiKey!,
          generationConfig:
              GenerationConfig(responseMimeType: 'application/json'));
      final prompt =
          'あなたは選挙アナリストです。「$district」の国民民主党の情勢(候補者、勝利条件)を分析しJSON({candidate, condition})で出力してください。';
      final response = await model.generateContent([Content.text(prompt)]);
      final json = jsonDecode(response.text ?? '{}');
      setState(() {
        _candidateInfo = json['candidate'] ?? '情報なし';
        _victoryCondition = json['condition'] ?? '分析不能';
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
      setState(() => _isBusy = false);
    }
  }

  Future<void> _updateDistrict(String district) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    await _supabase.from('user_profiles').upsert({
      'user_id': userId,
      'election_district': district,
      'updated_at': DateTime.now().toIso8601String()
    });
    setState(() => _myDistrict = district);
    _fetchDistrictAnalysis(district);
    _fetchLogistics(district); // 駅データも再取得
  }

  Future<void> _fetchLatestTrends() async {
    if (_apiKey == null) return;
    setState(() => _isBusy = true);
    try {
      final model = GenerativeModel(
          model: 'models/gemini-2.5-flash',
          apiKey: _apiKey!,
          generationConfig:
              GenerationConfig(responseMimeType: 'application/json'));
      final prompt =
          '2026年1月現在の最新世論調査に基づき、国民民主党の支持率(support_rate)、若年投票率(youth_turnout)、無党派獲得率(swing_potential)を推計しJSONで出力せよ。';
      final response = await model.generateContent([Content.text(prompt)]);
      final data = jsonDecode(response.text ?? '{}');
      setState(() {
        _supportRate = (data['support_rate'] as num).toDouble();
        _youthTurnout = (data['youth_turnout'] as num).toDouble();
        _swingCapture = (data['swing_potential'] as num).toDouble();
      });
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('最新トレンドを反映しました')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エラー: $e')));
    } finally {
      setState(() => _isBusy = false);
    }
  }

  Future<void> _submitStrategy() async {
    if (_apiKey == null || _strategyController.text.isEmpty) return;
    setState(() => _isBusy = true);
    try {
      final model =
          GenerativeModel(model: 'models/gemini-2.5-flash', apiKey: _apiKey!);
      final prompt = '''
      選挙コンサルとして以下の戦略を評価し、より有権者に響くキャッチコピーにリライトしてください。
      戦略: ${_strategyController.text}
      選挙区: $_myDistrict
      出力形式: Score: [0-100] Feedback: [評価] Rewrite: [改善案]
      ''';
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
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
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エラー: $e')));
    } finally {
      setState(() => _isBusy = false);
    }
  }

  Future<void> _pickAndAnalyzeImage() async {
    if (_apiKey == null) return;
    final picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (image == null) return;
    setState(() => _isBusy = true);
    try {
      final bytes = await image.readAsBytes();
      final model =
          GenerativeModel(model: 'models/gemini-1.5-flash', apiKey: _apiKey!);
      final prompt = TextPart('''
      選挙ポスター診断:
      1. インパクトと視認性
      2. 「手取りを増やす」のメッセージ性
      3. 印象評価
      出力: Score: [0-100] Advice: [詳細]
      ''');
      final content = Content.multi([prompt, DataPart('image/jpeg', bytes)]);
      final response = await model.generateContent([content]);
      final text = response.text ?? '';
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
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('診断スコア: $score点')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('画像分析エラー: $e')));
    } finally {
      setState(() => _isBusy = false);
    }
  }

  void _showDistrictDialog() {
    final controller = TextEditingController(text: _myDistrict);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('選挙区の設定'),
        content: TextField(
            controller: controller,
            decoration:
                const InputDecoration(labelText: '選挙区名', hintText: '例: 東京1区')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル')),
          FilledButton(
              onPressed: () {
                _updateDistrict(controller.text);
                Navigator.pop(context);
              },
              child: const Text('保存・分析')),
        ],
      ),
    );
  }

  void _showManualDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.menu_book, color: Colors.indigo),
          SizedBox(width: 8),
          Text('利用マニュアル')
        ]),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ManualItem(
                  icon: Icons.map, title: '1. 選挙区設定', desc: '右上のアイコンで選挙区を登録。'),
              _ManualItem(
                  icon: Icons.train,
                  title: '2. 地上戦ロジスティクス(New)',
                  desc:
                      '「地上戦」タブで、その選挙区の主要駅と乗降客数をAIがリストアップ。朝の駅立ち重点スポットがひと目で分かります。'),
              _ManualItem(
                  icon: Icons.auto_graph,
                  title: '3. トレンド分析',
                  desc: '「予測」タブで最新世論調査を反映。'),
              _ManualItem(
                  icon: Icons.image, title: '4. 素材診断', desc: 'ポスターを撮影してAI診断。'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('閉じる'))
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
            top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('戦略を提案',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
                controller: _strategyController,
                maxLines: 4,
                decoration: const InputDecoration(
                    hintText: '具体的なアクションを入力...', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                    onPressed: _isBusy ? null : _submitStrategy,
                    icon: const Icon(Icons.psychology),
                    label: const Text('AI分析・推敲して投稿'))),
            const SizedBox(height: 24),
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
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: Icon(
                  _myDistrict.isEmpty ? Icons.location_off : Icons.location_on),
              onPressed: _showDistrictDialog),
          IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: _showManualDialog)
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          isScrollable: true, // タブが多いのでスクロール許可
          tabs: const [
            Tab(icon: Icon(Icons.poll), text: '予測'),
            Tab(icon: Icon(Icons.train), text: '地上戦'), // 追加
            Tab(icon: Icon(Icons.lightbulb), text: '戦略'),
            Tab(icon: Icon(Icons.image), text: '素材'),
          ],
        ),
      ),
      body: _isBusy && !mounted
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSimulationTab(),
                _buildLogisticsTab(), // 追加
                _buildStrategyFeedTab(),
                _buildMaterialDiagnosticsTab(),
              ],
            ),
      floatingActionButton: _tabController.index == 2
          ? FloatingActionButton.extended(
              onPressed: _showAddDialog,
              backgroundColor: Colors.red,
              icon: const Icon(Icons.add_comment, color: Colors.white),
              label: const Text('戦略投稿'),
            )
          : null,
    );
  }

  // --- タブUI ---

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
              color: Colors.indigo.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$_myDistrict 分析レポート',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo)),
                      const Divider(),
                      Text('候補者: $_candidateInfo'),
                      Text('条件: $_victoryCondition',
                          style: const TextStyle(fontSize: 12)),
                    ]),
              ),
            ),
          const SizedBox(height: 16),
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Text('獲得予測議席', style: TextStyle(color: Colors.grey)),
                Text('$seats / 465',
                    style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo)),
                if (seats >= 233)
                  const Text('過半数獲得圏内！',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          if (_isBusy) const LinearProgressIndicator(),
          OutlinedButton.icon(
            onPressed: _isBusy ? null : _fetchLatestTrends,
            icon: const Icon(Icons.auto_graph),
            label: const Text('最新トレンドをAI分析して反映'),
          ),
          const SizedBox(height: 16),
          _slider('党支持率', _supportRate, 0, 60,
              (v) => setState(() => _supportRate = v), Colors.orange),
          _slider('若年層投票率', _youthTurnout, 20, 80,
              (v) => setState(() => _youthTurnout = v), Colors.blue),
          _slider('無党派層獲得', _swingCapture, 0, 100,
              (v) => setState(() => _swingCapture = v), Colors.green),
        ],
      ),
    );
  }

  // ★ 新規タブ: 地上戦ロジスティクス
  Widget _buildLogisticsTab() {
    if (_myDistrict.isEmpty) {
      return const Center(child: Text('まずは右上のアイコンから\n選挙区を設定してください。'));
    }

    if (_stationData.isEmpty && !_isBusy) {
      // データがない場合は手動トリガー
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
                  color: Colors.indigo),
            ),
          );
        }
        final station = _stationData[index - 1];
        final passengers = station['passengers'] as int? ?? 0;
        final rank = station['importance'] ?? 'B';
        final isS = rank == 'S';

        return Card(
          elevation: isS ? 4 : 1,
          color: isS ? Colors.red.shade50 : Colors.white,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isS ? Colors.red : Colors.blue,
              child: Text(rank,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            title: Text(station['name'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle:
                Text('推定乗降客数: ${(passengers / 10000).toStringAsFixed(1)}万人/日'),
            trailing: const Icon(Icons.campaign, color: Colors.grey),
          ),
        );
      },
    );
  }

  Widget _slider(String label, double val, double min, double max,
      ValueChanged<double> onChanged, Color color) {
    return Column(children: [
      Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label), Text('${val.toStringAsFixed(1)}%')]),
      Slider(
          value: val,
          min: min,
          max: max,
          activeColor: color,
          onChanged: onChanged),
    ]);
  }

  Widget _buildStrategyFeedTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from('election_strategies')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(50),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final items = snapshot.data!;
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
                        ? Colors.red.shade100
                        : Colors.grey.shade200,
                    child: Text('$score')),
                title: Text(item['content'] ?? ''),
                subtitle: Text(item['ai_feedback'] ?? ''),
              ),
            );
          },
        );
      },
    );
  }

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
                backgroundColor: Colors.teal),
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
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final items = snapshot.data!;
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final score = item['score'] as int? ?? 0;
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: Icon(Icons.image,
                          color: score >= 80 ? Colors.teal : Colors.grey),
                      title: Text('診断スコア: $score点'),
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
  const _ManualItem(
      {required this.icon, required this.title, required this.desc});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: Colors.indigo),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 13, height: 1.4)),
        ])),
      ]),
    );
  }
}
