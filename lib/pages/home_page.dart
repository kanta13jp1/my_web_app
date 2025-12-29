// ... (Imports same as before) ...
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
// ... other imports
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
import 'ai_status_page.dart';
import '../models/note.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ... (State variables same as before) ...
  int _totalPoints = 0;
  int _taskCount = 0;
  int _healthScore = 0;
  int _fixedCost = 0;
  List<Note> _notes = [];
  int _todayDigitalCount = 0;
  int _todayRealCount = 0;
  int _dailyDigitalGoal = 5;
  int _dailyRealGoal = 1;
  bool _isLoading = true;
  bool _isMeeting = false;
  final Color _navy = const Color(0xFF0F172A);
  final Color _gold = const Color(0xFFD4AF37);
  final Color _bgGrey = const Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _runExecutiveChecks();
  }

  // ... (Load Data methods same as before) ...
  Future<void> _runExecutiveChecks() async {
    await _loadData();
    _calculateDynamicGoals();
    await _checkMorningBriefing();
    await _checkProactiveIntervention();
  }

  void _calculateDynamicGoals() {
    setState(() {
      _dailyDigitalGoal = 5 + (_taskCount / 20).floor();
      _dailyRealGoal = 1 + (_totalPoints / 3000).floor();
    });
  }

  Future<void> _loadData() async {
    await Future.wait([
      _fetchUserStats(),
      _fetchHealthStats(),
      _fetchFixedCosts(),
      _fetchDanshariProgress(),
      _fetchNotes()
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchNotes() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final response = await supabase
          .from('notes')
          .select()
          .eq('user_id', userId)
          .eq('is_archived', false)
          .order('updated_at', ascending: false);
      setState(() {
        _notes = (response as List).map((n) => Note.fromJson(n)).toList();
      });
    } catch (_) {}
  }

  Future<void> _fetchUserStats() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final stats = await supabase
          .from('user_stats')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (stats != null) {
        setState(() {
          _totalPoints = stats['total_points'] ?? 0;
        });
        final countRes = await supabase
            .from('notes')
            .count()
            .eq('user_id', userId)
            .eq('is_archived', false);
        setState(() => _taskCount = countRes);
      }
    } catch (_) {}
  }

  Future<void> _fetchHealthStats() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final meals = await supabase
          .from('meal_logs')
          .select('performance_score')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(5);
      if (meals.isNotEmpty) {
        final avg = meals
                .map((m) => m['performance_score'] as int)
                .reduce((a, b) => a + b) /
            meals.length;
        setState(() => _healthScore = avg.round());
      }
    } catch (_) {}
  }

  Future<void> _fetchFixedCosts() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final subs = await supabase
          .from('subscriptions')
          .select('price, billing_cycle')
          .eq('user_id', userId);
      double total = 0;
      for (var s in subs) {
        double price = (s['price'] as num).toDouble();
        if (s['billing_cycle'] == 'yearly') price /= 12;
        total += price;
      }
      setState(() => _fixedCost = total.round());
    } catch (_) {}
  }

  Future<void> _fetchDanshariProgress() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final now = DateTime.now();
      final todayStart =
          DateTime(now.year, now.month, now.day).toIso8601String();
      final realCount = await supabase
          .from('notes')
          .count()
          .eq('user_id', userId)
          .eq('is_archived', true)
          .ilike('title', '断捨離:%')
          .gte('created_at', todayStart);
      final totalArchivedCount = await supabase
          .from('notes')
          .count()
          .eq('user_id', userId)
          .eq('is_archived', true)
          .gte('updated_at', todayStart);
      setState(() {
        _todayRealCount = realCount;
        _todayDigitalCount = (totalArchivedCount - realCount) < 0
            ? 0
            : (totalArchivedCount - realCount);
      });
    } catch (_) {}
  }

  Future<void> _checkMorningBriefing() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDate = prefs.getString('last_briefing_date');
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      if (lastDate != todayStr) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        _holdBoardMeeting(isMorning: true);
        await prefs.setString('last_briefing_date', todayStr);
      }
    } catch (_) {}
  }

  Future<void> _checkProactiveIntervention() async {
    // ... (Same proactive logic) ...
  }

  // ---  Modified Hold Board Meeting (Battle Mode) ---
  Future<void> _holdBoardMeeting({bool isMorning = false}) async {
    setState(() => _isMeeting = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final meals = await supabase.from('meal_logs').select().limit(5);
      final notes = await supabase
          .from('notes')
          .select()
          .eq('is_archived', false)
          .limit(5);
      final stats = await supabase.from('user_stats').select().maybeSingle();

      final boardData = {
        'recentMeals': meals,
        'recentNotes': notes,
        'userStats': stats
      };

      // Request Multi Response for Battle Mode
      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'hold_board_meeting',
          'boardData': boardData,
          'context': isMorning ? 'morning_briefing' : 'emergency',
          'multi_response': true //  Enable Battle Mode
        },
      );

      if (response.status != 200) throw Exception('AI Error');
      final data = response.data;
      if (data['success'] != true) throw Exception(data['error']);

      if (mounted) {
        if (data['is_multi'] == true) {
          // Multi-Model Result
          _showBattleResult(data['results'], isMorning: isMorning);
        } else {
          // Single Result Fallback
          _showMeetingResult(data['result'],
              isMorning: isMorning, provider: data['provider']);
        }
      }
    } catch (e) {
      if (!isMorning)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('会議エラー: $e')));
    } finally {
      if (mounted) setState(() => _isMeeting = false);
    }
  }

  // ---  Battle Result UI (Left vs Right) ---
  void _showBattleResult(List<dynamic> results, {bool isMorning = false}) {
    if (results.length < 2) {
      _showMeetingResult(results[0]['result'],
          isMorning: isMorning, provider: results[0]['provider']);
      return;
    }

    final res1 = results[0]; // Provider A (e.g. Anthropic)
    final res2 = results[1]; // Provider B (e.g. Gemini)

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _navy,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(children: [
                Icon(Icons.compare_arrows, color: _gold),
                const SizedBox(width: 8),
                Text(isMorning ? 'モーニングセカンドオピニオン' : '戦略会議：多角的視点',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18))
              ]),
            ),
            Expanded(
              child: Row(
                children: [
                  // Left Side (Result 1)
                  Expanded(
                      child: _buildBattleColumn(res1, Colors.blue.shade100)),
                  Container(width: 1, color: Colors.white24),
                  // Right Side (Result 2)
                  Expanded(
                      child: _buildBattleColumn(res2, Colors.orange.shade100)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _gold, foregroundColor: Colors.black),
                  child: const Text('議論を終了')),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBattleColumn(dynamic resData, Color headerColor) {
    final result = resData['result'];
    final provider = resData['provider'];
    final model = resData['model'] ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: headerColor, borderRadius: BorderRadius.circular(4)),
            child: Text('$provider ($model)',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.black87)),
          ),
          const SizedBox(height: 12),
          Text(result['decision'] ?? result['agenda'] ?? 'No decision',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const Divider(color: Colors.white12),
          Expanded(
            child: SingleChildScrollView(
              child: Text(result['discussion'] ?? '',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13, height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }

  // Standard Single Result (Legacy)
  void _showMeetingResult(Map<String, dynamic> result,
      {bool isMorning = false, String? provider}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _navy,
        title: Text(isMorning ? 'Morning Briefing' : 'Board Meeting',
            style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (provider != null)
                Text('議長: $provider',
                    style: TextStyle(color: _gold, fontSize: 12)),
              const SizedBox(height: 8),
              Text(result['decision'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white)),
              const SizedBox(height: 8),
              Text(result['discussion'] ?? '',
                  style: const TextStyle(fontSize: 14, color: Colors.white70)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('了解'))
        ],
      ),
    );
  }

  // ... (Existing Drawer, AppBar, etc.) ...
  // Please ensure the build() method and other widgets are kept as they were in the previous clean version.
  // Due to length, I am focusing on the _holdBoardMeeting and _showBattleResult integration.

  @override
  Widget build(BuildContext context) {
    // ... (Keep the previous build method content) ...
    return Scaffold(
        backgroundColor: _bgGrey,
        drawer: _buildDrawer(),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: [
                          Container(
                              width: double.infinity,
                              height: 60,
                              margin: const EdgeInsets.only(bottom: 24),
                              child: ElevatedButton.icon(
                                  onPressed: _isMeeting
                                      ? null
                                      : () =>
                                          _holdBoardMeeting(isMorning: false),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: _navy,
                                      foregroundColor: _gold,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16))),
                                  icon: _isMeeting
                                      ? const CircularProgressIndicator()
                                      : const Icon(Icons.compare_arrows,
                                          size: 28),
                                  label: const Text('緊急役員会議 (Battle Mode)',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)))),
                          // ... (Rest of UI) ...
                        ]))),
                // ... (Rest of UI) ...
              ]));
  }

  // ... (Keep helper widgets like _buildDrawer, _buildSliverAppBar, etc.) ...
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 320.0,
      floating: false,
      pinned: true,
      backgroundColor: _navy,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_navy, const Color(0xFF1E293B)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(
                  top: 60.0, left: 20, right: 20, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Capital (Assets)',
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          letterSpacing: 1.0)),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('$_totalPoints',
                            style: TextStyle(
                                color: _gold,
                                fontSize: 56,
                                fontWeight: FontWeight.bold,
                                height: 1.0)),
                        const SizedBox(width: 8),
                        const Text('Pt',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 24)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildKpiItem(Icons.health_and_safety, 'Health',
                            '$_healthScore', 'Score'),
                        _buildVerticalDivider(),
                        _buildKpiItem(Icons.account_balance_wallet,
                            'Fixed Cost', '$_fixedCost', '/mo'),
                        _buildVerticalDivider(),
                        _buildKpiItem(Icons.check_circle, 'Tasks',
                            '$_taskCount', 'Active'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        title:
            const Text('自分株式会社', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      actions: [
        IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const CmoPage()))),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(width: 1, height: 30, color: Colors.white24);
  }

  Widget _buildKpiItem(IconData icon, String label, String value, String unit) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(color: Colors.white54, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
          ),
          if (unit.isNotEmpty)
            Text(unit,
                style: const TextStyle(color: Colors.white30, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildDeptCard(
      String title, String subtitle, IconData icon, Color color, Widget page) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        _loadData();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.grey[800])),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: color,
        elevation: 1,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.transparent)),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildProgressRow(
      String label, int current, int goal, Color color, VoidCallback onTap) {
    final progress = (goal == 0) ? 1.0 : (current / goal).clamp(0.0, 1.0);
    final isMet = current >= goal;
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold)),
              Text('$current / $goal',
                  style: TextStyle(
                      fontSize: 13, color: isMet ? color : Colors.grey)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withOpacity(0.1),
              color: color,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: _navy),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.business, color: _gold, size: 40),
                const SizedBox(height: 10),
                const Text('自分株式会社',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                const Text('Management Console',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.analytics, color: Colors.blueGrey),
            title: const Text('アプリ分析 (Admin)'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminAnalyticsPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.monitor_heart, color: Colors.teal),
            title: const Text('AI稼働モニター'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AiStatusPage()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('サインアウト'),
            onTap: _signOut,
          ),
        ],
      ),
    );
  }
}
