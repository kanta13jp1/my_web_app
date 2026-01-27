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

  // ユーザー情報
  String _myDistrict = ''; // 例: 東京1区
  bool _isLoadingProfile = true;

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

  // --- Profile Logic (修正版: user_idを使用) ---
  Future<void> _fetchUserProfile() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // user_id カラムを使って検索
      final data = await _supabase
          .from('user_profiles')
          .select('election_district')
          .eq('user_id', userId)
          .maybeSingle();

      if (data != null && data['election_district'] != null) {
        setState(() {
          _myDistrict = data['election_district'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    } finally {
      setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _updateDistrict(String district) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // user_id をキーにして更新 (upsert)
      await _supabase.from('user_profiles').upsert({
        'user_id': userId, // ここが重要：idではなくuser_id
        'election_district': district,
        'updated_at': DateTime.now().toIso8601String(),
      });

      setState(() => _myDistrict = district);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('選挙区を「$district」に設定しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存エラー: $e')),
        );
      }
    }
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

      // 選挙区情報があればプロンプトに追加
      String contextInfo = '';
      if (_myDistrict.isNotEmpty) {
        contextInfo = '投稿者の選挙区: $_myDistrict (この地域の特性も考慮してアドバイスしてください)';
      }

      final prompt = '''
      あなたは国民民主党の選挙戦略コンサルタントです。以下の戦略案を評価し、結果をテキストで返してください。
      
      【戦略案】
      ${_strategyController.text}
      
      【コンテキスト】
      $contextInfo
      党の重要政策: 「手取りを増やす」「103万円の壁撤廃」

      【出力フォーマット】
      Score: [0-100の数値]
      Feedback: [具体的で士気を高める100文字以内のアドバイス]
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';

      // 簡易パース
      int score = 50;
      String feedback = text;

      final scoreMatch = RegExp(r'Score:\s*(\d+)').firstMatch(text);
      if (scoreMatch != null) {
        score = int.parse(scoreMatch.group(1)!);
        feedback = text.replaceAll(scoreMatch.group(0)!, '').trim();
        feedback = feedback.replaceAll('Feedback:', '').trim();
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
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('提出完了！ AIスコア: $score点'),
            backgroundColor: score >= 80 ? Colors.red : Colors.indigo,
          ),
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
            const Text('あなたの選挙区を登録すると、AIが地域特性を考慮したアドバイスを行います。'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '選挙区名',
                hintText: '例: 東京1区、愛知2区',
                border: OutlineInputBorder(),
              ),
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
            child: const Text('保存'),
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
                icon: Icons.person_pin_circle,
                title: '1. 選挙区の登録',
                desc:
                    '画面右上のアイコンから「選挙区」を登録しましょう。AIがあなたの地域の特性（無党派層の多さや産業構造など）を推測し、より的確なアドバイスを行います。',
              ),
              _ManualItem(
                icon: Icons.poll,
                title: '2. シミュレーション',
                desc: 'スライダーを操作して、支持率や投票率が議席数にどう影響するか予測します。',
              ),
              _ManualItem(
                icon: Icons.lightbulb,
                title: '3. 戦略の投稿',
                desc:
                    '「手取りを増やす」ための具体的なアクションを投稿してください。AI参謀が即座に採点し、優れたアイデアは全ユーザーに共有されます。',
              ),
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
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('戦略を提案',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_myDistrict.isNotEmpty)
              Chip(
                label: Text('$_myDistrict の戦略として分析します'),
                avatar: const Icon(Icons.location_on, size: 16),
                backgroundColor: Colors.orange.shade100,
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _strategyController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '例: 駅前でのビラ配りで、現役世代に「103万円の壁」のメリットをスマホ画面で見せるキャンペーン...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _submitStrategy,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.psychology),
                label: const Text('AI分析して投稿'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
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
            onPressed: _showManualDialog,
          )
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
        children: [
          Card(
            color: Colors.white,
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('獲得予測議席', style: TextStyle(color: Colors.grey)),
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
                        color: score >= 80 ? Colors.red : Colors.black87,
                      )),
                ),
                title: Text(item['content'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome,
                            size: 12, color: Colors.amber),
                        const SizedBox(width: 4),
                        const Text('AI参謀:',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey)),
                      ],
                    ),
                    Text(item['ai_feedback'] ?? '分析中...',
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
