import 'dart:math';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import 'landing_page.dart';
import 'note_editor_page.dart';
import 'gemini_university_page.dart';
import 'danshari_page.dart';
import 'real_world_danshari_page.dart';
import 'ai_secretary_page.dart';
import 'subscription_page.dart'; // 追加
import 'admin_analytics_page.dart';
import '../models/note.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Note> _notes = [];
  bool _isLoading = true;

  final int _dailyDanshariGoal = 5;
  int _todayDanshariCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadNotes(),
      _loadDailyProgress(),
    ]);
  }

  Future<void> _loadDailyProgress() async {
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

      if (mounted) {
        setState(() {
          _todayDanshariCount = count;
        });
      }
    } catch (e) {
      debugPrint('Progress load error: $e');
    }
  }

  Future<void> _loadNotes() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('notes')
          .select()
          .eq('user_id', userId)
          .eq('is_archived', false)
          .order('updated_at', ascending: false);

      if (mounted) {
        setState(() {
          _notes = (response as List).map((n) => Note.fromJson(n)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LandingPage()),
      );
    }
  }

  Map<String, String> _getRandomShareContent() {
    final patterns = [
      {
        'text': '私のゴミを判定するためだけに、Gemini 3.0含む『14種類のAI』を総動員するアプリを使ってます',
        'ref': 'home_pattern_a_tech_overkill'
      },
      {
        'text': 'AI CFOに固定費を監査してもらいました。無駄遣いがバレて叱責されています。',
        'ref': 'home_pattern_cfo'
      },
    ];
    final random = Random();
    return patterns[random.nextInt(patterns.length)];
  }

  Future<void> _shareApp() async {
    try {
      await supabase.rpc('increment_share_count');
    } catch (_) {}
    final content = _getRandomShareContent();
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      '${content['text']}\nhttps://my-web-app-b67f4.web.app/?ref=${content['ref']}',
      subject: '自分株式会社',
      sharePositionOrigin:
          box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    );
  }

  Future<void> _postToX() async {
    try {
      await supabase.rpc('increment_share_count');
    } catch (_) {}
    final content = _getRandomShareContent();
    final text = '${content['text']}\n\n無料でAI経営診断できます\n#マイメモ #Gemini #自分株式会社';
    final url = 'https://my-web-app-b67f4.web.app/?ref=${content['ref']}';
    final tweetUrl = Uri.parse(
        'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(text)}&url=${Uri.encodeComponent(url)}');
    if (await canLaunchUrl(tweetUrl)) {
      await launchUrl(tweetUrl, mode: LaunchMode.externalApplication);
    } else {
      _shareApp();
    }
  }

  void _showShareMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Xでポスト'),
                onTap: () {
                  Navigator.pop(context);
                  _postToX();
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('シェア'),
                onTap: () {
                  Navigator.pop(context);
                  _shareApp();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGoalMet = _todayDanshariCount >= _dailyDanshariGoal;
    final remaining = _dailyDanshariGoal - _todayDanshariCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('自分株式会社'),
        actions: [
          IconButton(
              icon: const Icon(Icons.share, color: Colors.indigo),
              onPressed: _showShareMenu),
          IconButton(icon: const Icon(Icons.logout), onPressed: _signOut),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.indigo),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.business, color: Colors.white, size: 40),
                  SizedBox(height: 10),
                  Text('経営管理',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('アプリ分析 (管理者用)'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminAnalyticsPage()));
              },
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: () async {
                      if (!isGoalMet) {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const DanshariPage()));
                        _loadData();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isGoalMet
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: isGoalMet ? Colors.green : Colors.red,
                            width: 2),
                      ),
                      child: Row(
                        children: [
                          Icon(isGoalMet ? Icons.bed : Icons.lock_clock,
                              size: 40,
                              color: isGoalMet ? Colors.green : Colors.red),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(isGoalMet ? '就寝許可証: 発行済み' : '就寝禁止: ロック中',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isGoalMet
                                            ? Colors.green.shade800
                                            : Colors.red.shade800)),
                                const SizedBox(height: 4),
                                Text(
                                    isGoalMet
                                        ? 'お疲れ様でした。良い夢を。'
                                        : 'あと $remaining 個 片付けるまで\n寝ることは許されません。',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: isGoalMet
                                            ? Colors.green.shade700
                                            : Colors.red.shade700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text('4大経営タスク',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  //  4つの目玉機能 (2列x2行)
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: _buildBigFeatureCard(
                            title: 'Gemini大学',
                            subtitle: 'AIを学ぶ',
                            icon: Icons.school,
                            color: Colors.indigo,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const GeminiUniversityPage())),
                          )),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _buildBigFeatureCard(
                            title: '断捨離\nクエスト',
                            subtitle: '残り $remaining 個',
                            icon: Icons.cleaning_services,
                            color: isGoalMet ? Colors.green : Colors.redAccent,
                            isHighlight: true,
                            onTap: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const DanshariPage()));
                              _loadData();
                            },
                          )),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                              child: _buildBigFeatureCard(
                            title: 'AI戦略\n秘書室',
                            subtitle: '社長の右腕',
                            icon: Icons.business_center,
                            color: Colors.blueGrey,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const AISecretaryPage())),
                          )),
                          const SizedBox(width: 12),
                          //  第4の機能: サブスク管理
                          Expanded(
                              child: _buildBigFeatureCard(
                            title: '固定費\n削減室',
                            subtitle: 'AI CFOの監査',
                            icon: Icons.attach_money,
                            color: Colors.teal,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const SubscriptionPage())),
                          )),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  Container(
                    width: double.infinity,
                    height: 80,
                    margin: const EdgeInsets.only(bottom: 24),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RealWorldDanshariPage()));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade50,
                        foregroundColor: Colors.indigo,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                                color: Colors.indigo.withOpacity(0.3))),
                      ),
                      icon: const Icon(Icons.camera_alt, size: 32),
                      label: const Text('現実のゴミも捨てる (AI判定)',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const Text('すべてのメモ',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  if (_notes.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text('メモはまだありません。',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey)))
                  else
                    ..._notes.map((note) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(note.title,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(note.content,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12)),
                            onTap: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          NoteEditorPage(note: note)));
                              _loadData();
                            },
                          ),
                        )),

                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const NoteEditorPage()));
          _loadData();
        },
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        child: const Icon(Icons.edit),
      ),
    );
  }

  Widget _buildBigFeatureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isHighlight = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: isHighlight ? color : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3))
          ],
          border: isHighlight
              ? null
              : Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: isHighlight ? Colors.white : color),
            const SizedBox(height: 8),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isHighlight ? Colors.white : Colors.black87)),
            const SizedBox(height: 4),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isHighlight ? Colors.white : Colors.grey)),
          ],
        ),
      ),
    );
  }
}
