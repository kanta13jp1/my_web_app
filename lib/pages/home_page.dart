import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import 'landing_page.dart';
import 'note_editor_page.dart';
import 'gemini_university_page.dart';
import 'danshari_page.dart';
import 'real_world_danshari_page.dart';
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

      // 修正: count() は int を直接返す
      final count = await supabase
          .from('notes')
          .count(CountOption.exact)
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

  Future<void> _shareApp() async {
    try {
      await supabase.rpc('increment_share_count');
    } catch (_) {}
    await Share.share(
      '私の部屋、AI鬼コーチに「ゴミ屋敷」判定されました\nhttps://my-web-app-b67f4.web.app/?ref=share_general',
      subject: 'AI断捨離アプリで判定中',
    );
  }

  Future<void> _postToX() async {
    try {
      await supabase.rpc('increment_share_count');
    } catch (_) {}
    const text =
        'AI鬼コーチに部屋の写真を判定してもらったら、衝撃のアドバイスが...\n\n無料でAI断捨離診断できます\n#マイメモ #Gemini #断捨離';
    const url = 'https://my-web-app-b67f4.web.app/?ref=x_share';
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
                title: const Text('Xでポスト (おすすめ)'),
                subtitle: const Text('AIの判定結果をみんなに教える'),
                onTap: () {
                  Navigator.pop(context);
                  _postToX();
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('その他のアプリでシェア'),
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
        title: const Text('マイメモ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.indigo),
            onPressed: _showShareMenu,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
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
                  Icon(Icons.settings, color: Colors.white, size: 40),
                  SizedBox(height: 10),
                  Text('設定管理',
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
                  MaterialPageRoute(builder: (_) => const AdminAnalyticsPage()),
                );
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
                              builder: (_) => const DanshariPage()),
                        );
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
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isGoalMet ? Colors.green : Colors.red)
                                  .withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ]),
                      child: Row(
                        children: [
                          Icon(isGoalMet ? Colors.bed : Colors.lock_clock,
                              size: 40,
                              color: isGoalMet ? Colors.green : Colors.red),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isGoalMet ? '就寝許可証: 発行済み' : '就寝禁止: ロック中',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isGoalMet
                                          ? Colors.green.shade800
                                          : Colors.red.shade800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isGoalMet
                                      ? 'お疲れ様でした。良い夢を。'
                                      : 'あと $remaining 個 片付けるまで\n寝ることは許されません。',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: isGoalMet
                                          ? Colors.green.shade700
                                          : Colors.red.shade700),
                                ),
                              ],
                            ),
                          ),
                          if (!isGoalMet)
                            const Icon(Icons.arrow_forward_ios,
                                size: 16, color: Colors.red),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '最重要タスク',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
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
                                builder: (_) => const GeminiUniversityPage()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildBigFeatureCard(
                          title: '断捨離\nクエスト',
                          subtitle: isGoalMet ? '完了済み' : '残り $remaining 個',
                          icon: Icons.cleaning_services,
                          color: isGoalMet ? Colors.green : Colors.redAccent,
                          isHighlight: true,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const DanshariPage()),
                            );
                            _loadData();
                          },
                        ),
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
                              builder: (_) => const RealWorldDanshariPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade50,
                        foregroundColor: Colors.indigo,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side:
                              BorderSide(color: Colors.indigo.withOpacity(0.3)),
                        ),
                      ),
                      icon: const Icon(Icons.camera_alt, size: 32),
                      label: const Text(
                        '現実のゴミも捨てる (AI判定)',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const Text(
                    'すべてのメモ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_notes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text('メモはまだありません。',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ..._notes.map((note) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(note.title,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              note.content,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => NoteEditorPage(note: note)),
                              );
                              _loadData();
                            },
                          ),
                        )),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade50, Colors.blue.shade50],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.diversity_3,
                                size: 40, color: Colors.indigo),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    '仲間を増やそう！',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                  Text('AI鬼コーチの判定をシェアして盛り上がろう。',
                                      style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _postToX,
                                icon: const Icon(Icons.close, size: 18),
                                label: const Text('Xでポスト'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _shareApp,
                                icon: const Icon(Icons.share),
                                label: const Text('その他'),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NoteEditorPage()),
          );
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
        height: 180,
        decoration: BoxDecoration(
          color: isHighlight ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: isHighlight
              ? null
              : Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: isHighlight ? Colors.white : color,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isHighlight ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isHighlight ? Colors.white : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
