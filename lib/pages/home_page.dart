import 'dart:math';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _isMeeting = false;
  final int _dailyDanshariGoal = 5;
  int _todayDanshariCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkMorningBriefing(); //  モーニングブリーフィングのチェック
  }

  Future<void> _loadData() async {
    await Future.wait([_loadNotes(), _loadDailyProgress()]);
  }

  Future<void> _checkMorningBriefing() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDate = prefs.getString('last_briefing_date');
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);

      // 今日まだブリーフィングしていなければ実行
      if (lastDate != todayStr) {
        // UI描画後に実行するために少し待つ
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;

        // 自動実行
        _holdBoardMeeting(isMorning: true);

        // 記録更新
        await prefs.setString('last_briefing_date', todayStr);
      }
    } catch (e) {
      debugPrint('Briefing check error: $e');
    }
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

  //  役員会議 / モーニングブリーフィング
  Future<void> _holdBoardMeeting({bool isMorning = false}) async {
    setState(() => _isMeeting = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

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
        body: {
          'action': 'hold_board_meeting',
          'boardData': boardData,
          'context': isMorning ? 'morning_briefing' : 'emergency' //  文脈を指定
        },
      );

      if (response.status != 200) throw Exception('AI Error');
      final data = response.data;
      if (data['success'] != true) throw Exception(data['error']);

      if (mounted) _showMeetingResult(data['result'], isMorning: isMorning);
    } catch (e) {
      if (!isMorning)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('会議エラー: $e')));
    } finally {
      if (mounted) setState(() => _isMeeting = false);
    }
  }

  void _showMeetingResult(Map<String, dynamic> result,
      {bool isMorning = false}) {
    showDialog(
      context: context,
      barrierDismissible: !isMorning, // 朝礼は確認必須感
      builder: (context) => AlertDialog(
        title: Row(children: [
          Icon(isMorning ? Icons.wb_sunny : Icons.meeting_room,
              color: isMorning ? Colors.orange : Colors.indigo),
          const SizedBox(width: 8),
          Text(isMorning ? 'モーニングブリーフィング' : '緊急役員会議 議事録')
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
              Text(isMorning ? '【昨日の分析】' : '【議論】',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text(result['discussion'] ?? '',
                  style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color:
                        isMorning ? Colors.orange.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isMorning
                            ? Colors.orange.shade200
                            : Colors.red.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isMorning ? '【本日のミッション】' : '【決定事項 (Action Item)】',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isMorning
                                ? Colors.orange.shade900
                                : Colors.red)),
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
              onPressed: () => Navigator.pop(context), child: const Text('了解')),
          ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _shareAppWithContent(result['decision'] ?? '人生経営中');
              },
              child: const Text('共有する')),
        ],
      ),
    );
  }

  //  URL付きシェア機能（共通化）
  Future<void> _shareAppWithContent(String content) async {
    try {
      await supabase.rpc('increment_share_count');
    } catch (_) {}
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
        '$content\n\n ダウンロード: https://my-web-app-b67f4.web.app/\n#自分株式会社',
        sharePositionOrigin:
            box != null ? box.localToGlobal(Offset.zero) & box.size : null);
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
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isMeeting
                          ? null
                          : () => _holdBoardMeeting(isMorning: false),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                          elevation: 4),
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
                      child: Row(children: [
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
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('経営役員会',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Wrap(spacing: 12, runSpacing: 12, children: [
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
                  ]),
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
