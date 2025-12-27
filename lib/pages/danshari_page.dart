import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class DanshariPage extends StatefulWidget {
  const DanshariPage({super.key});

  @override
  State<DanshariPage> createState() => _DanshariPageState();
}

class _DanshariPageState extends State<DanshariPage>
    with SingleTickerProviderStateMixin {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _staleMemos = [];
  bool _isLoading = true;
  bool _isAnalyzing = false; // AI解析中フラグ
  int _deletedCount = 0;
  int _earnedPoints = 0;

  // アニメーション用
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fetchStaleMemos();

    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    // 上にスライドして消える動き
    _slideAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(0, -1)).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // 古い順にメモを取得（「断捨離候補」）
  Future<void> _fetchStaleMemos() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 作成日が古い順に最大10件取得
      final response = await supabase
          .from('notes')
          .select()
          .eq('user_id', userId)
          .eq('is_archived', false) // アーカイブ済みは除外
          .order('created_at', ascending: true) // 最も古いものから
          .limit(10);

      if (mounted) {
        setState(() {
          _staleMemos = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    }
  }

  //  断捨離実行（削除してポイントゲット）
  Future<void> _executeDanshari() async {
    if (_staleMemos.isEmpty) return;

    final memo = _staleMemos.first;
    final memoId = memo['id'];

    // アニメーション開始
    await _animController.forward();

    try {
      // 1. DB更新（アーカイブ化）
      await supabase
          .from('notes')
          .update({'is_archived': true}).eq('id', memoId);

      // 2. ユーザーにポイント付与（作成よりも高い報酬！）
      final userId = supabase.auth.currentUser!.id;
      const pointsReward = 100; // 断捨離は高配当

      // 現在のポイント取得と更新（簡易実装）
      try {
        await supabase.rpc('increment_points',
            params: {'user_id': userId, 'points_to_add': pointsReward});
      } catch (_) {
        // RPCがない場合のフォールバック（手動更新）
        final stats = await supabase
            .from('user_stats')
            .select('total_points')
            .eq('user_id', userId)
            .single();
        final current = stats['total_points'] as int? ?? 0;
        await supabase.from('user_stats').update(
            {'total_points': current + pointsReward}).eq('user_id', userId);
      }

      if (mounted) {
        setState(() {
          _staleMemos.removeAt(0);
          _deletedCount++;
          _earnedPoints += pointsReward;
        });
        _animController.reset(); // アニメーションリセット
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('削除に失敗しました')),
        );
        _animController.reset();
      }
    }
  }

  //  残す（スキップ）
  void _keepMemo() {
    if (_staleMemos.isEmpty) return;
    setState(() {
      // リストの最後に回す
      final item = _staleMemos.removeAt(0);
      _staleMemos.add(item);
    });
  }

  //  AI判定機能
  Future<void> _analyzeCurrentNoteWithAI() async {
    if (_staleMemos.isEmpty) return;

    final currentMemo = _staleMemos.first;
    setState(() => _isAnalyzing = true);

    try {
      // Edge Function呼び出し
      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'analyze_note_text',
          'title': currentMemo['title'] ?? '',
          'content': currentMemo['content'] ?? '',
        },
      );

      if (response.status != 200) {
        throw Exception('Server error: ${response.status}');
      }

      final data = response.data;
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Unknown error');
      }

      if (mounted) {
        _showAnalysisResultDialog(data['result']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI解析エラー: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  // 解析結果表示ダイアログ
  void _showAnalysisResultDialog(String result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.psychology, color: Colors.indigo),
            SizedBox(width: 8),
            Text('鬼コーチの判定'),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            result,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _executeDanshari(); // アドバイスに従って捨てる
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white),
            icon: const Icon(Icons.delete_forever),
            label: const Text('アドバイスに従って捨てる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(' 断捨離クエスト'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: Row(
              children: [
                const Icon(Icons.stars, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  '+$_earnedPoints pt',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                      fontSize: 18),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _staleMemos.isEmpty
              ? _buildCompletionView()
              : _buildDanshariView(),
    );
  }

  // 断捨離完了画面
  Widget _buildCompletionView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 100, color: Colors.green),
          const SizedBox(height: 20),
          const Text(
            'All Clean!',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            '思考のノイズは消え去りました。\n今回の断捨離数: $_deletedCount 件',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), // trueを返してリロードさせる
            style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
            child: const Text('ホームに戻る'),
          ),
        ],
      ),
    );
  }

  // メインの断捨離画面
  Widget _buildDanshariView() {
    final memo = _staleMemos.first;
    final date = DateTime.parse(memo['created_at']);
    final dateStr = DateFormat('yyyy/MM/dd').format(date);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'このメモはまだ必要ですか？',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // メモカードエリア
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.history,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(dateStr,
                                style: const TextStyle(color: Colors.grey)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('断捨離候補',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.amber,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const Divider(height: 30),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              memo['content'] ?? (memo['title'] ?? '内容なし'),
                              style: const TextStyle(fontSize: 20, height: 1.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          //  AI判定ボタン (追加)
          Center(
            child: _isAnalyzing
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _analyzeCurrentNoteWithAI,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade50,
                      foregroundColor: Colors.indigo,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    icon: const Icon(Icons.psychology),
                    label: const Text('AI鬼コーチの判定を受ける',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
          ),

          const SizedBox(height: 20),

          // 操作ボタン
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _keepMemo,
                  icon: const Icon(Icons.refresh),
                  label: const Text('まだ残す'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _executeDanshari,
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('捨ててスッキリ (+100pt)'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
