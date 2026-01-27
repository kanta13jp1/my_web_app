import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _isSubmitting = false;

  // ユーザー情報 & 分析データ
  String _myDistrict = '';
  String _candidateInfo = '';
  String _victoryCondition = '';
  bool _isAnalyzingDistrict = false;

  // シミュレーション用パラメータ
  double _supportRate = 15.0;
  double _youthTurnout = 40.0;
  double _swingCapture = 30.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadApiKey();
    _fetchUserProfile();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('gemini_api_key');
    });
  }

  // --- Profile & District Analysis Logic ---

  Future<void> _fetchUserProfile() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _supabase
          .from('user_profiles')
          .select('election_district')
          .eq('user_id', userId)
          .maybeSingle();

      if (data != null && data['election_district'] != null) {
        setState(() {
          _myDistrict = data['election_district'];
        });
        // プロフィール取得時に、その選挙区の分析データも取得
        _fetchDistrictAnalysis(data['election_district']);
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
  }

  Future<void> _fetchDistrictAnalysis(String district) async {
    // まずSupabaseのキャッシュを確認
    try {
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
        // データがなければAI分析を実行（自動）
        _analyzeDistrict(district);
      }
    } catch (e) {
      debugPrint('Error fetching analytics: $e');
    }
  }

  Future<void> _analyzeDistrict(String district) async {
    if (_apiKey == null) return;
    setState(() => _isAnalyzingDistrict = true);

    try {
      final model = GenerativeModel(
        model: 'models/gemini-2.5-flash',
        apiKey: _apiKey!,
        generationConfig:
            GenerationConfig(responseMimeType: 'application/json'),
      );

      final prompt = '''
      あなたは選挙アナリストです。「$district」における国民民主党の状況を分析し、JSONで出力してください。
      候補者が不明な場合は「擁立調整中」や「（過去の候補者名）氏など」と推測を含めて記述してください。
      
      【出力フォーマット JSON】
      {
        "candidate": "候補者名と肩書き（例: 現職、新人、元職）",
        "condition": "この選挙区で勝利するために必要な具体的な条件（例: 無党派層の〇〇%獲得、野党共闘の有無、重点エリアなど）を150文字以内で"
      }
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '{}';

      // 簡易JSONパース
      String candidate = '情報なし';
      String condition = '分析できませんでした';

      // (正規表現で抽出)
      final candMatch = RegExp(r'"candidate":\s*"(.*?)"').firstMatch(text);
      final condMatch = RegExp(r'"condition":\s*"(.*?)"').firstMatch(text);

      if (candMatch != null) candidate = candMatch.group(1)!;
      if (condMatch != null) condition = condMatch.group(1)!;

      setState(() {
        _candidateInfo = candidate;
        _victoryCondition = condition;
      });

      // Supabaseにキャッシュ保存
      await _supabase.from('district_analytics').upsert({
        'district_name': district,
        'candidate_info': candidate,
        'victory_condition': condition,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('AI Analysis Error: $e');
    } finally {
      if (mounted) setState(() => _isAnalyzingDistrict = false);
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
      _fetchDistrictAnalysis(district); // 保存後に分析開始

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('選挙区を「$district」に設定しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存エラー: $e')));
      }
    }
  }

  // --- Strategy Submit Logic ---
  Future<void> _submitStrategy() async {
    if (_apiKey == null || _strategyController.text.isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      final model =
          GenerativeModel(model: 'models/gemini-2.5-flash', apiKey: _apiKey!);
      String contextInfo = _myDistrict.isNotEmpty ? '選挙区: $_myDistrict' : '';
      final prompt = '''
      選挙戦略コンサルとして評価してください。
      戦略: ${_strategyController.text}
      コンテキスト: $contextInfo
      出力: Score: [0-100] Feedback: [文章]
      ''';
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      int score = 50;
      String feedback = text;
      final scoreMatch = RegExp(r'Score:\s*(\d+)').firstMatch(text);
      if (scoreMatch != null) {
        score = int.parse(scoreMatch.group(1)!);
        feedback = text
            .replaceAll(scoreMatch.group(0)!, '')
            .trim()
            .replaceAll('Feedback:', '')
            .trim();
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // --- UI Components ---

  void _showDistrictDialog() {
    final controller = TextEditingController(text: _myDistrict);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('選挙区の設定'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('AIが地域特性を分析します。'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                  labelText: '選挙区名',
                  hintText: '例: 東京1区',
                  border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル')),
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

  void _showManualDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.menu_book),
          SizedBox(width: 8),
          Text('利用マニュアル')
        ]),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ManualItem(
                  icon: Icons.map,
                  title: '1. 選挙区分析',
                  desc: '右上のアイコンから選挙区を登録すると、AIが「候補者情報」と「勝利への条件」を自動分析して表示します。'),
              _ManualItem(
                  icon: Icons.poll,
                  title: '2. シミュレーション',
                  desc: '各種パラメータを操作し、目標議席数への到達度を予測します。'),
              _ManualItem(
                  icon: Icons.campaign,
                  title: '3. 戦略共有',
                  desc: 'あなたのアイデアを投稿してください。AIが採点し、他のサポーターと共有されます。'),
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
                    onPressed: _isSubmitting ? null : _submitStrategy,
                    icon: const Icon(Icons.psychology),
                    label: const Text('AI分析して投稿'))),
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
            tooltip: '選挙区設定',
            onPressed: _showDistrictDialog,
          ),
          IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'マニュアル',
              onPressed: _showManualDialog)
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          tabs: const [Tab(text: 'シミュレーション'), Tab(text: '集合知・アイデア')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSimulationTab(),
          _buildStrategyFeedTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: Colors.red,
        icon: const Icon(Icons.add_comment, color: Colors.white),
        label: const Text('戦略を投稿', style: TextStyle(color: Colors.white)),
      ),
    );
  }

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ▼ 選挙区分析カード (追加)
          if (_myDistrict.isNotEmpty)
            Card(
              color: Colors.indigo.shade50,
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.indigo.shade200)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.analytics, color: Colors.indigo),
                        const SizedBox(width: 8),
                        Text('$_myDistrict の分析レポート',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo)),
                        if (_isAnalyzingDistrict) ...[
                          const Spacer(),
                          const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                        ]
                      ],
                    ),
                    const Divider(),
                    const Text('予想候補者',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.grey)),
                    Text(
                        _candidateInfo.isNotEmpty
                            ? _candidateInfo
                            : '分析中または情報なし',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),
                    const Text('勝利への条件 (AI参謀)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.grey)),
                    Text(
                        _victoryCondition.isNotEmpty
                            ? _victoryCondition
                            : '分析中...',
                        style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),

          Card(
            color: Colors.white,
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('全国獲得予測議席', style: TextStyle(color: Colors.grey)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$seats',
                          style: const TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo)),
                      const Text(' / 465',
                          style: TextStyle(fontSize: 24, color: Colors.grey)),
                    ],
                  ),
                  if (seats >= 233)
                    const Text('政権交代・過半数圏内！',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
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

  Widget _slider(String label, double val, double min, double max,
      ValueChanged<double> onChanged, Color color) {
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('${val.toStringAsFixed(1)}%',
              style: TextStyle(fontWeight: FontWeight.bold, color: color))
        ]),
        Slider(
            value: val,
            min: min,
            max: max,
            activeColor: color,
            onChanged: onChanged),
      ],
    );
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
        if (items.isEmpty)
          return const Center(child: Text('まだ戦略がありません。最初の投稿者になりましょう！'));
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final score = item['impact_score'] as int? ?? 0;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      score >= 80 ? Colors.red.shade100 : Colors.grey.shade200,
                  child: Text('$score',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: score >= 80 ? Colors.red : Colors.black87)),
                ),
                title: Text(item['content'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(item['ai_feedback'] ?? '分析中...',
                    style: const TextStyle(fontSize: 13)),
              ),
            );
          },
        );
      },
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.indigo),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(fontSize: 13, height: 1.4)),
              ])),
        ],
      ),
    );
  }
}
