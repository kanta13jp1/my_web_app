import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart'; // シェア機能用
import '../main.dart';
import 'landing_page.dart';
import 'note_editor_page.dart';
import 'gemini_university_page.dart';
import 'danshari_page.dart';
import 'real_world_danshari_page.dart';
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

  // すべてのメモを取得
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

  //  シェア機能の実装
  void _shareApp() {
    Share.share(
      'AIと一緒に断捨離！「Gemini大学」で学んで、リアル断捨離クエストで部屋も心もスッキリしませんか？\n\n#マイメモ #断捨離 #Gemini\nhttps://github.com/kanta13jp1/my_web_app',
      subject: '最強の断捨離アプリを見つけました',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('マイメモ'),
        actions: [
          // シェアボタン (AppBarに追加)
          IconButton(
            icon: const Icon(Icons.share, color: Colors.indigo),
            onPressed: _shareApp,
            tooltip: 'アプリをシェア',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'ログアウト',
          ),
        ],
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

                  //  2大機能カードエリア
                  Row(
                    children: [
                      // 1. Gemini大学
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
                      // 2. 断捨離クエスト
                      Expanded(
                        child: _buildBigFeatureCard(
                          title: '断捨離\nクエスト',
                          subtitle: '不要を捨てる',
                          icon: Icons.cleaning_services,
                          color: Colors.redAccent,
                          isHighlight: true, // 強調
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

                  //  リアル断捨離ボタン
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

                  // メモリスト
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

                  //  友達紹介カード（下部にも配置）
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade50, Colors.blue.shade50],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Row(
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
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text('このアプリをシェアして、断捨離仲間を見つけましょう。',
                                  style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _shareApp,
                          icon: const Icon(Icons.ios_share),
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  // リスト下の余白
                  const SizedBox(height: 80),
                ],
              ),
            ),

      // FAB
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
