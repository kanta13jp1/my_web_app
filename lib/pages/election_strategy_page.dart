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

  // シミュレーション用パラメータ
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

  // --- AI & Supabase Logic ---
  Future<void> _submitStrategy() async {
    if (_apiKey == null || _strategyController.text.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      // 1. Geminiで分析
      final model = GenerativeModel(
        model: 'models/gemini-2.5-flash',
        apiKey: _apiKey!,
      );

      final prompt = '''
      あなたは選挙戦略コンサルタントです。以下の戦略案を評価し、JSON形式に近いテキストで返してください。
      戦略: ${_strategyController.text}
      評価項目: インパクトスコア(0-100), 短いフィードバック
      出力形式: Score: [数値] Feedback: [文章]
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';

      // 簡易パース (本番では正規表現やJSONパースを推奨)
      int score = 50;
      String feedback = text;

      final scoreMatch = RegExp(r'Score:\s*(\d+)').firstMatch(text);
      if (scoreMatch != null) {
        score = int.parse(scoreMatch.group(1)!);
        feedback = text.replaceAll(scoreMatch.group(0)!, '').trim();
      }

      // 2. Supabaseへ保存
      await _supabase.from('election_strategies').insert({
        'user_id': _supabase.auth.currentUser!.id,
        'content': _strategyController.text,
        'ai_feedback': feedback,
        'impact_score': score,
      });

      if (mounted) {
        _strategyController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('戦略を提出しました！')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // --- Manual Dialog ---
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
              Text('1. シミュレーション',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('スライダーを動かして、支持率や投票率が議席数にどう影響するか予測します。'),
              SizedBox(height: 12),
              Text('2. アイデア投稿', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('あなたの考えた戦略を投稿してください。AIが即座に採点し、Supabaseに保存され共有されます。'),
              SizedBox(height: 12),
              Text('3. スコアリング', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Gemini 2.5 Flashが実現性とインパクトを分析し、0-100点で評価します。'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('2026 勝利戦略室'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'マニュアル',
            onPressed: _showManualDialog,
          )
        ],
        bottom: TabBar(
          controller: _tabController,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSimulationTab() {
    // 簡易計算ロジック
    int seats = (10 +
            (_supportRate * 3.5) +
            (_youthTurnout * 0.5) +
            (_swingCapture * 0.5))
        .toInt();
    if (seats > 465) seats = 465;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('獲得予測議席', style: TextStyle(color: Colors.grey)),
                  Text('$seats / 465',
                      style: const TextStyle(
                          fontSize: 48, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _slider('党支持率', _supportRate, 0, 60,
              (v) => setState(() => _supportRate = v)),
          _slider('若年層投票率', _youthTurnout, 20, 80,
              (v) => setState(() => _youthTurnout = v)),
          _slider('無党派層獲得', _swingCapture, 0, 100,
              (v) => setState(() => _swingCapture = v)),
        ],
      ),
    );
  }

  Widget _slider(String label, double val, double min, double max,
      ValueChanged<double> onChanged) {
    return Column(
      children: [
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(label), Text('${val.toStringAsFixed(1)}%')]),
        Slider(value: val, min: min, max: max, onChanged: onChanged),
      ],
    );
  }

  Widget _buildStrategyFeedTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from('election_strategies')
          .stream(primaryKey: ['id']).order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final items = snapshot.data!;
        if (items.isEmpty) return const Center(child: Text('まだ戦略がありません'));

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              leading: CircleAvatar(child: Text('${item['impact_score']}')),
              title: Text(item['content']),
              subtitle: Text(item['ai_feedback'] ?? ''),
            );
          },
        );
      },
    );
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('戦略を提案'),
        content: TextField(
            controller: _strategyController,
            maxLines: 3,
            decoration: const InputDecoration(hintText: '例: SNSでのショート動画拡散...')),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                _submitStrategy();
              },
              child: const Text('AI分析して投稿'))
        ],
      ),
    );
  }
}
