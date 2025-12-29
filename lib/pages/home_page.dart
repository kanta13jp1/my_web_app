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
import 'subscription_page.dart';
import 'health_page.dart';
import 'chro_page.dart';
import 'cmo_page.dart';
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
  bool _isMeeting = false; // 会議中フラグ
  final int _dailyDanshariGoal = 5;
  int _todayDanshariCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadNotes(), _loadDailyProgress()]);
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
      if (mounted) setState(() => _todayDanshariCount = count);
    } catch (e) {
      debugPrint('$e');
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
      if (mounted)
        setState(() {
          _notes = (response as List).map((n) => Note.fromJson(n)).toList();
          _isLoading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  //  役員会議を開催
  Future<void> _holdBoardMeeting() async {
    setState(() => _isMeeting = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 各部門のデータを取得
      final meals = await supabase
          .from('meal_logs')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(5);
      final notes = await supabase
          .from('notes')
          .select()
          .eq('user_id', userId)
          .eq('is_archived', false)
          .limit(5);
      final subs =
          await supabase.from('subscriptions').select().eq('user_id', userId);
      final stats = await supabase
          .from('user_stats')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      final boardData = {
        'recentMeals': meals,
        'recentNotes': notes,
        'subscriptions': subs,
        'userStats': stats
      };

      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {'action': 'hold_board_meeting', 'boardData': boardData},
      );

      if (response.status != 200) throw Exception('AI Error');
      final data = response.data;
      if (data['success'] != true) throw Exception(data['error']);

      if (mounted) _showMeetingResult(data['result']);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('会議エラー: $e')));
    } finally {
      setState(() => _isMeeting = false);
    }
  }

  void _showMeetingResult(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.meeting_room, color: Colors.indigo),
          SizedBox(width: 8),
          Text('緊急役員会議 議事録')
        ]),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(result['agenda'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(),
              Text('【議論】',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text(result['discussion'] ?? '',
                  style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('【決定事項 (Action Item)】',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.red)),
                    const SizedBox(height: 4),
                    Text(result['decision'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                  alignment: Alignment.centerRight,
                  child: Text('予想株価変動: ${result['stock_price_impact']}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green))),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる')),
          ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Share.share(
                    '【自分株式会社 緊急役員会議】\n決定事項: ${result['decision']}\n予想株価: ${result['stock_price_impact']}\n#自分株式会社',
                    subject: '役員会議');
              },
              child: const Text('全社通達 (シェア)')),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted)
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LandingPage()));
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
              icon: const Icon(Icons.campaign, color: Colors.purple),
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const CmoPage()))),
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
                            fontWeight: FontWeight.bold))
                  ]),
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
                }),
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
                  //  役員会議ボタン
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isMeeting ? null : _holdBoardMeeting,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                        elevation: 4,
                      ),
                      icon: _isMeeting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.groups),
                      label: const Text('緊急役員会議を開催する',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  // 就寝許可証
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
                              width: 2)),
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
                                            : Colors.red.shade700))
                              ])),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text('経営役員会',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildFeatureCard(
                          context,
                          'AI戦略室 (CSO)',
                          '秘書 & 参謀',
                          Icons.business_center,
                          Colors.blueGrey,
                          const AISecretaryPage()),
                      _buildFeatureCard(
                          context,
                          '断捨離クエスト',
                          '残り $remaining 個',
                          Icons.cleaning_services,
                          isGoalMet ? Colors.green : Colors.redAccent,
                          const DanshariPage(),
                          isHighlight: true),
                      _buildFeatureCard(
                          context,
                          '財務省 (CFO)',
                          '固定費監査',
                          Icons.attach_money,
                          Colors.teal,
                          const SubscriptionPage()),
                      _buildFeatureCard(
                          context,
                          '健康管理室 (CHO)',
                          'AI検食',
                          Icons.health_and_safety,
                          Colors.teal.shade800,
                          const HealthPage()),
                      _buildFeatureCard(context, '人事局 (CHRO)', '福利厚生',
                          Icons.diversity_3, Colors.pink, const ChroPage()),
                      _buildFeatureCard(context, '広報室 (CMO)', 'PR & 分析',
                          Icons.campaign, Colors.purple, const CmoPage()),
                      _buildFeatureCard(
                          context,
                          '知的財産本部 (CKO)',
                          'AIシンクタンク',
                          Icons.school,
                          Colors.indigo,
                          const GeminiUniversityPage()),
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
                                  color: Colors.indigo.withOpacity(0.3)))),
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
                            }))),
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
          child: const Icon(Icons.edit)),
    );
  }

  Widget _buildFeatureCard(BuildContext context, String title, String subtitle,
      IconData icon, Color color, Widget page,
      {bool isHighlight = false}) {
    final width = (MediaQuery.of(context).size.width - 48) / 2;
    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        _loadData();
      },
      child: Container(
        width: width,
        height: 140,
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
                : Border.all(color: color.withOpacity(0.3), width: 2)),
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 32, color: isHighlight ? Colors.white : color),
          const SizedBox(height: 8),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isHighlight ? Colors.white : Colors.black87)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isHighlight ? Colors.white : Colors.grey))
        ]),
      ),
    );
  }
}
