import 'package:flutter/material.dart';
import '../main.dart';

class ChroPage extends StatefulWidget {
  const ChroPage({super.key});

  @override
  State<ChroPage> createState() => _ChroPageState();
}

class _ChroPageState extends State<ChroPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _myPoints = 0;
  List<Map<String, dynamic>> _welfareItems = [];
  List<Map<String, dynamic>> _inventory = [];
  bool _isLoading = true;

  // メンタルケア用
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, String>> _chatHistory = [];
  bool _isChatting = false;

  // 評価用
  Map<String, dynamic>? _lastEvaluation;
  bool _isEvaluating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // ポイント取得
      final stats = await supabase
          .from('user_stats')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (stats != null) _myPoints = stats['total_points'] ?? 0;

      // ストアアイテム
      final items = await supabase.from('welfare_items').select().order('cost');
      _welfareItems = List<Map<String, dynamic>>.from(items);

      // インベントリ
      final inv = await supabase
          .from('user_inventory')
          .select('*, welfare_items(*)')
          .eq('user_id', userId)
          .eq('is_used', false);
      _inventory = List<Map<String, dynamic>>.from(inv);

      // 最新評価
      final evals = await supabase
          .from('monthly_evaluations')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1);
      if (evals.isNotEmpty) _lastEvaluation = evals.first;

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  // アイテム購入
  Future<void> _purchaseItem(Map<String, dynamic> item) async {
    final cost = item['cost'] as int;
    if (_myPoints < cost) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ポイントが不足しています')));
      return;
    }

    try {
      final userId = supabase.auth.currentUser!.id;
      // ポイント減算 (RPC使っても良いが簡易的にupdate)
      await supabase
          .from('user_stats')
          .update({'total_points': _myPoints - cost}).eq('user_id', userId);
      // インベントリ追加
      await supabase
          .from('user_inventory')
          .insert({'user_id': userId, 'item_id': item['id']});

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${item['name']}を購入しました！')));
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('購入エラー: $e')));
    }
  }

  // 月次評価実行
  Future<void> _runEvaluation() async {
    setState(() => _isEvaluating = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      // 統計データ再取得
      final stats = await supabase
          .from('user_stats')
          .select()
          .eq('user_id', userId)
          .single();

      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {'action': 'evaluate_performance', 'userStats': stats},
      );

      if (response.status != 200) throw Exception('AI Error');
      final data =
          response.data['result']; // {rank, report_content, bonus_message}

      // 保存
      await supabase.from('monthly_evaluations').insert({
        'user_id': userId,
        'target_month': DateTime.now().toString().substring(0, 7),
        'rank': data['rank'],
        'report_content': data['report_content'],
      });

      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('評価エラー: $e')));
    } finally {
      setState(() => _isEvaluating = false);
    }
  }

  // メンタルケアチャット送信
  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _chatHistory.add({'role': 'user', 'content': text});
      _isChatting = true;
      _chatController.clear();
    });

    try {
      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {'action': 'mental_chat', 'content': text},
      );

      if (response.status != 200) throw Exception('Error');
      final reply = response.data['result']; // String

      setState(() {
        _chatHistory.add({'role': 'ai', 'content': reply.toString()});
      });
    } catch (e) {
      setState(() {
        _chatHistory
            .add({'role': 'ai', 'content': '（優しく微笑んでいるが、通信エラーのようです...）'});
      });
    } finally {
      setState(() => _isChatting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(' 人事厚生局 (CHRO)'),
        backgroundColor: Colors.pink.shade400,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.pink.shade100,
          tabs: const [
            Tab(icon: Icon(Icons.store), text: '福利厚生'),
            Tab(icon: Icon(Icons.assessment), text: '株主総会'),
            Tab(icon: Icon(Icons.spa), text: 'メンタル室'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStoreTab(),
          _buildEvaluationTab(),
          _buildMentalCareTab(),
        ],
      ),
    );
  }

  Widget _buildStoreTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.pink.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '保有ポイント',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '$_myPoints pt',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink.shade700,
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            '所有アイテム',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        if (_inventory.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('アイテムを持っていません', style: TextStyle(color: Colors.grey)),
          ),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _inventory.length,
            itemBuilder: (context, index) {
              final item = _inventory[index]['welfare_items'];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.pink.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      IconData(
                        item['icon_code'] ?? 58746,
                        fontFamily: 'MaterialIcons',
                      ),
                      color: Colors.pink,
                    ),
                    Text(item['name'], style: const TextStyle(fontSize: 10)),
                  ],
                ),
              );
            },
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: _welfareItems.length,
            itemBuilder: (context, index) {
              final item = _welfareItems[index];
              final canBuy = _myPoints >= (item['cost'] as int);
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.pink.shade100,
                    child: Icon(
                      IconData(
                        item['icon_code'] ?? 58746,
                        fontFamily: 'MaterialIcons',
                      ),
                      color: Colors.pink,
                    ),
                  ),
                  title: Text(item['name']),
                  subtitle: Text(item['description']),
                  trailing: ElevatedButton(
                    onPressed: canBuy ? () => _purchaseItem(item) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('${item['cost']} pt'),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEvaluationTab() {
    if (_lastEvaluation == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assessment, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('今月の評価レポートがまだありません'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isEvaluating ? null : _runEvaluation,
              icon: _isEvaluating
                  ? const CircularProgressIndicator()
                  : const Icon(Icons.play_arrow),
              label: const Text('定例株主総会を開催する'),
            ),
          ],
        ),
      );
    }
    final ev = _lastEvaluation!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '定例株主総会 決議通知',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.pink, width: 4),
              ),
              child: Column(
                children: [
                  const Text('CEO RANK', style: TextStyle(color: Colors.grey)),
                  Text(
                    ev['rank'],
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: Colors.pink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            ev['report_content'] ?? '',
            style: const TextStyle(fontSize: 16, height: 1.6),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _isEvaluating ? null : _runEvaluation,
            child: const Text('最新の評価を取得する'),
          ),
        ],
      ),
    );
  }

  Widget _buildMentalCareTab() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _chatHistory.length,
            itemBuilder: (context, index) {
              final chat = _chatHistory[index];
              final isAi = chat['role'] == 'ai';
              return Align(
                alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isAi ? Colors.white : Colors.pink.shade100,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(chat['content']!),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: const InputDecoration(
                    hintText: '愚痴をこぼしてください...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                icon: _isChatting
                    ? const CircularProgressIndicator()
                    : const Icon(Icons.send, color: Colors.pink),
                onPressed: _isChatting ? null : _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
