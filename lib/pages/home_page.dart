import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
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

  @override
  void initState() {
    super.initState();
    _loadNotes();
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

  // ---------------------------------------------------
  //  シェア機能群 (マーケティング強化版)
  // ---------------------------------------------------

  // 1. 汎用シェア
  Future<void> _shareApp() async {
    try {
      await supabase.rpc('increment_share_count');
    } catch (e) {
      debugPrint('Share analytics error: $e');
    }

    await Share.share(
      '私の部屋、AI鬼コーチに「ゴミ屋敷」判定されました\nあなたもAIに判定してもらいませんか？\n\n#マイメモ #断捨離 #Gemini\nhttps://my-web-app-b67f4.web.app/?ref=share_general',
      subject: 'AI断捨離アプリで判定中',
    );
  }

  // 2. X (Twitter) 直接投稿
  Future<void> _postToX() async {
    try {
      await supabase.rpc('increment_share_count');
    } catch (e) {
      debugPrint('Share analytics error: $e');
    }

    //  工夫: ユーザーがクリックしたくなるような「煽り」や「結果」を入れる
    const text =
        'AI鬼コーチに部屋の写真を判定してもらったら、衝撃のアドバイスが...\n\n無料でAI断捨離診断できます\n#マイメモ #Gemini #断捨離';

    //  追跡: ?ref=x_share を追加して、どこから来たか計測する
    const url = 'https://my-web-app-b67f4.web.app/?ref=x_share';

    final tweetUrl = Uri.parse(
        'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(text)}&url=${Uri.encodeComponent(url)}');

    if (await canLaunchUrl(tweetUrl)) {
      await launchUrl(tweetUrl, mode: LaunchMode.externalApplication);
    } else {
      _shareApp();
    }
  }

  // 3. シェアメニュー
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('マイメモ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.indigo),
            onPressed: _showShareMenu,
            tooltip: 'アプリをシェア',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'ログアウト',
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
                          subtitle: '不要を捨てる',
                          icon: Icons.cleaning_services,
                          color: Colors.redAccent,
                          isHighlight: true,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const DanshariPage()),
                            );
                            _loadNotes();
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
                              _loadNotes();
                            },
                          ),
                        )),

                  const SizedBox(height: 24),

                  //  友達紹介カード
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
                            // Xでポストボタン
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
                            // その他のシェアボタン
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
          _loadNotes();
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
                color: isHighlight ? Colors.white70 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
