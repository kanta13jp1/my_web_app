import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

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
  bool _isAnalyzing = false;
  int _earnedPoints = 0;

  final int _dailyGoal = 5;
  int _todayCount = 0;

  // 判定に使用されたモデル名を保持
  String? _usedModel;

  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fetchData();

    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
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

  Future<void> _fetchData() async {
    await Future.wait([
      _fetchStaleMemos(),
      _fetchDailyProgress(),
    ]);
  }

  Future<void> _fetchDailyProgress() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final now = DateTime.now();
      final todayStart =
          DateTime(now.year, now.month, now.day).toIso8601String();

      final count = await supabase
          .from('notes')
          .count()
          .eq('user_id', userId)
          .eq('is_archived', true)
          .gte('updated_at', todayStart);

      if (mounted) setState(() => _todayCount = count);
    } catch (_) {}
  }

  Future<void> _fetchStaleMemos() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('notes')
          .select()
          .eq('user_id', userId)
          .eq('is_archived', false)
          .order('created_at', ascending: true)
          .limit(10);

      if (mounted) {
        setState(() {
          _staleMemos = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _executeDanshari() async {
    if (_staleMemos.isEmpty) return;

    final memo = _staleMemos.first;
    final memoId = memo['id'];

    await _animController.forward();

    try {
      await supabase.from('notes').update({
        'is_archived': true,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', memoId);

      final userId = supabase.auth.currentUser!.id;
      const pointsReward = 100;

      try {
        await supabase.rpc('increment_points',
            params: {'user_id': userId, 'points_to_add': pointsReward});
      } catch (_) {}

      if (mounted) {
        setState(() {
          _staleMemos.removeAt(0);
          _earnedPoints += pointsReward;
          _todayCount++;
          _usedModel = null; // リセット
        });
        _animController.reset();
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

  void _keepMemo() {
    if (_staleMemos.isEmpty) return;
    setState(() {
      final item = _staleMemos.removeAt(0);
      _staleMemos.add(item);
      _usedModel = null;
    });
  }

  Future<void> _analyzeCurrentNoteWithAI() async {
    if (_staleMemos.isEmpty) return;

    final currentMemo = _staleMemos.first;
    setState(() {
      _isAnalyzing = true;
      _usedModel = null;
    });

    try {
      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'analyze_note_text',
          'title': currentMemo['title'] ?? '',
          'content': currentMemo['content'] ?? '',
        },
      );

      if (response.status != 200)
        throw Exception('Server error: ${response.status}');
      final data = response.data;
      if (data['success'] != true)
        throw Exception(data['error'] ?? 'Unknown error');

      if (mounted) {
        setState(() {
          _usedModel = data['used_model']; // モデル名を保存
        });
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

  void _shareResult(String result) {
    final shortResult = result.split('\n').take(5).join('\n');
    final box = context.findRenderObject() as RenderBox?;

    final modelInfo =
        _usedModel != null ? "(担当AI: $_usedModel)" : "(担当AI: Gemini 14モデル総力戦)";

    Share.share(
      '溜め込んだメモを14種類のAIモデルに判定してもらいました...\n\n$modelInfo\n$shortResult\n...\n\n#マイメモ #デジタル断捨離 #Gemini\nhttps://my-web-app-b67f4.web.app/?ref=share_text_result',
      subject: 'AI断捨離コーチの診断結果',
      sharePositionOrigin:
          box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    );
  }

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              //  モデル名の表示バッジ
              if (_usedModel != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '担当AI: $_usedModel',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              Text(
                result,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              _shareResult(result);
            },
            icon: const Icon(Icons.share),
            label: const Text('結果をシェア'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _executeDanshari();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white),
            icon: const Icon(Icons.delete_forever),
            label: const Text('捨てる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _todayCount / _dailyGoal;
    final isMet = _todayCount >= _dailyGoal;

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
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        isMet
                            ? ' 今日のノルマ達成！'
                            : '今日のノルマ: 残り ${_dailyGoal - _todayCount} 件',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isMet ? Colors.green : Colors.redAccent)),
                    Text('$_todayCount / $_dailyGoal'),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress > 1 ? 1 : progress,
                    backgroundColor: Colors.grey.shade200,
                    color: isMet ? Colors.green : Colors.redAccent,
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _staleMemos.isEmpty
                    ? _buildCompletionView()
                    : _buildDanshariView(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 100, color: Colors.green),
          const SizedBox(height: 20),
          const Text('All Clean!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('今日の分はもうありません。\n素晴らしい！',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
            child: const Text('ホームに戻る'),
          ),
        ],
      ),
    );
  }

  Widget _buildDanshariView() {
    final memo = _staleMemos.first;
    final date = DateTime.parse(memo['created_at']);
    final dateStr = DateFormat('yyyy/MM/dd').format(date);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('このメモはまだ必要ですか？',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
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
                                  borderRadius: BorderRadius.circular(8)),
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _keepMemo,
                  icon: const Icon(Icons.refresh),
                  label: const Text('まだ残す'),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: Colors.grey),
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
                      elevation: 4),
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
