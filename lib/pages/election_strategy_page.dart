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
  // Supabase & AI
  final _supabase = Supabase.instance.client;
  String? _apiKey;
  final TextEditingController _strategyController = TextEditingController();

  // UI State
  late TabController _tabController;
  bool _isSubmitting = false;

  // Simulation State
  double _supportRate = 15.0;
  double _youthTurnout = 40.0;
  double _swingCapture = 30.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('gemini_api_key');
    });
  }

  // --- AI Logic ---

  Future<void> _submitStrategy() async {
    if (_apiKey == null || _strategyController.text.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      // 1. Geminiによる分析
      final model = GenerativeModel(
        model: 'models/gemini-2.5-flash',
        apiKey: _apiKey!,
        generationConfig:
            GenerationConfig(responseMimeType: 'application/json'),
      );

      final prompt = '''
      あなたは国民民主党の選挙戦略コンサルタントです。
      以下のユーザーからの戦略案を評価し、JSON形式で出力してください。
      
      【戦略案】
      ${_strategyController.text}

      【評価基準】
      - 「手取りを増やす」「103万円の壁」などの党是との整合性
      - 実現可能性とインパクト
      - 若年層への訴求力

      【出力フォーマット (JSON)】
      {
        "score": 0〜100の整数,
        "feedback": "100文字以内の具体的な改善アドバイスまたは賞賛",
        "category": "SNS戦略" or "街頭活動" or "政策提言" or "その他"
      }
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      final analysisText = response.text ?? '{}';

      // JSONパース (簡易実装)
      // 注: 本番ではより堅牢なJSONパースを推奨
      int score = 50;
      String feedback = "分析できませんでした";

      try {
        // 余計な文字を取り除く（Markdownのコードブロックなど）
        final jsonString =
            analysisText.replaceAll('```json', '').replaceAll('```', '').trim();
        // DartのjsonDecodeを使うべきですが、ここでは簡易的に文字列操作で抽出する場合の例、または本来は下記のようにします
        // final data = jsonDecode(jsonString); score = data['score']; ...
        // 今回はデモ用なので、エラーハンドリングを緩くしています

        // 正規表現で簡易抽出
        final scoreMatch = RegExp(r'"score":\s*(\d+)').firstMatch(jsonString);
        final feedbackMatch =
            RegExp(r'"feedback":\s*"(.*?)"').firstMatch(jsonString);

        if (scoreMatch != null) score = int.parse(scoreMatch.group(1)!);
        if (feedbackMatch != null) feedback = feedbackMatch.group(1)!;
      } catch (e) {
        debugPrint('JSON Parse Error: $e');
      }

      // 2. Supabaseへ保存
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase.from('election_strategies').insert({
          'user_id': userId,
          'content': _strategyController.text,
          'ai_feedback': feedback,
          'impact_score': score,
        });
      }

      if (mounted) {
        _strategyController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('戦略を提出しました！ AIスコア: $score点'),
            backgroundColor: score >= 80 ? Colors.red : Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.grey),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // --- UI Building ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('2026 勝利戦略室'),
        backgroundColor: Colors.yellow.shade700,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: '戦略マニュアル',
            onPressed: () => _showManualDialog(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black87,
          indicatorColor: Colors.red,
          tabs: const [
            Tab(icon: Icon(Icons.poll), text: 'シミュレーション'),
            Tab(icon: Icon(Icons.lightbulb), text: '集合知・アイデア'),
          ],
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
        onPressed: () => _showAddStrategyDialog(context),
        backgroundColor: Colors.red,
        icon: const Icon(Icons.add_comment, color: Colors.white),
        label: const Text('戦略を提案', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // タブ1: シミュレーション
  Widget _buildSimulationTab() {
    int seats = (10 +
            (_supportRate * 3.5) +
            (_youthTurnout > 50 ? (_youthTurnout - 50) * 1.5 : 0) +
            (_swingCapture * 0.5))
        .round();
    if (seats > 465) seats = 465;
    bool isVictory = seats >= 233;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            elevation: 4,
            color: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text('2026 衆院選 獲得予測議席',
                      style: TextStyle(color: Colors.grey)),
                  Text(
                    '$seats',
                    style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: isVictory ? Colors.red : Colors.black87),
                  ),
                  const Text('/ 465',
                      style: TextStyle(fontSize: 24, color: Colors.grey)),
                  if (isVictory)
                    const Text('政権交代・過半数圏内！',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSlider('党支持率', _supportRate, 0, 50,
              (v) => setState(() => _supportRate = v), Colors.orange),
          _buildSlider('若年層投票率', _youthTurnout, 20, 80,
              (v) => setState(() => _youthTurnout = v), Colors.blue),
          _buildSlider('無党派層獲得率', _swingCapture, 0, 100,
              (v) => setState(() => _swingCapture = v), Colors.green),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max,
      ValueChanged<double> onChanged, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${value.toStringAsFixed(1)}%',
                style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        Slider(
            value: value,
            min: min,
            max: max,
            activeColor: color,
            onChanged: onChanged),
      ],
    );
  }

  // タブ2: 戦略フィード (Supabase)
  Widget _buildStrategyFeedTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from('election_strategies')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(20),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final strategies = snapshot.data!;

        if (strategies.isEmpty) {
          return const Center(child: Text('まだ戦略提案がありません。\n最初のアイデアを投稿しましょう！'));
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: strategies.length,
          itemBuilder: (context, index) {
            final item = strategies[index];
            final score = item['impact_score'] as int? ?? 0;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      score >= 80 ? Colors.red.shade100 : Colors.grey.shade200,
                  child: Text('$score',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: score >= 80 ? Colors.red : Colors.black87,
                      )),
                ),
                title: Text(item['content'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    const Text('AI参謀の分析:',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(item['ai_feedback'] ?? '分析中...',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ダイアログ: 戦略投稿
  void _showAddStrategyDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('勝利戦略を提案',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('「手取りを増やす」を実現するための具体的なアイデアを入力してください。AIが即座にインパクトを試算します。',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: _strategyController,
              decoration: const InputDecoration(
                hintText: '例: 学生ボランティアによるSNSショート動画の拡散キャンペーン...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () {
                        Navigator.pop(context);
                        _submitStrategy();
                      },
                icon: const Icon(Icons.send),
                label: const Text('AI分析にかけて提出'),
                style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ダイアログ: ユーザーマニュアル
  void _showManualDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.menu_book, color: Colors.indigo),
            SizedBox(width: 8),
            Text('戦略室・利用マニュアル'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildManualSection(
                '1. シミュレーション機能',
                '「支持率」「若年層投票率」などのパラメータを操作し、獲得議席数を予測します。過半数（233議席）を超えるための条件を探りましょう。',
                Icons.poll,
              ),
              _buildManualSection(
                '2. 集合知（アイデア投稿）',
                'あなたの考えた選挙戦略を投稿してください。Supabaseクラウドに保存され、全党員・サポーターと共有されます。',
                Icons.lightbulb,
              ),
              _buildManualSection(
                '3. AI参謀による分析',
                '投稿された戦略は、Gemini 2.5 Flash が即座に分析します。「インパクトスコア（0-100点）」と「フィードバック」が自動生成され、効果的な戦略が可視化されます。',
                Icons.psychology,
              ),
              const Divider(),
              const Text(
                '※このアプリは党公式ではありませんが、データを活用して勝利への道筋を具体化するためのツールです。',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('理解した'),
          ),
        ],
      ),
    );
  }

  Widget _buildManualSection(String title, String desc, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
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
