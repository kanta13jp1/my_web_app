import 'dart:math';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
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
import 'ai_status_page.dart';
import '../models/note.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // KPI Data
  int _totalPoints = 0;
  int _taskCount = 0;
  int _healthScore = 0;
  int _fixedCost = 0;
  List<Note> _notes = [];

  // Danshari Progress
  int _todayDigitalCount = 0;
  int _todayRealCount = 0;
  int _dailyDigitalGoal = 5;
  int _dailyRealGoal = 1;

  bool _isLoading = true;
  bool _isMeeting = false;

  // Colors
  final Color _navy = const Color(0xFF0F172A);
  final Color _gold = const Color(0xFFD4AF37);
  final Color _bgGrey = const Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _runExecutiveChecks();
  }

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
      _fetchNotes(),
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt('last_intervention_ts') ?? 0;
      final nowTs = DateTime.now().millisecondsSinceEpoch;

      if (nowTs - lastCheck < 3600000) return;

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final meals = await supabase
          .from('meal_logs')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1);
      final notes = await supabase
          .from('notes')
          .select('id')
          .eq('user_id', userId)
          .eq('is_archived', false);
      final stats = await supabase
          .from('user_stats')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      dynamic paymentSources = [];
      try {
        final res = await supabase
            .from('payment_sources')
            .select()
            .eq('user_id', userId);
        paymentSources = res;
      } catch (_) {
        paymentSources = [];
      }

      final boardData = {
        'recentMeals': meals,
        'recentNotes': notes,
        'userStats': stats,
        'paymentSources': paymentSources
      };

      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'proactive_intervention',
          'boardData': boardData,
          'currentTime': TimeOfDay.now().format(context),
        },
      );

      if (response.status == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final result = data['result'];

          if (mounted && data['used_model'] != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('AI介入: ${data['provider']} (${data['used_model']})'),
                backgroundColor: Colors.blueGrey,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          }

          if (result['should_intervene'] == true) {
            await Future.delayed(const Duration(seconds: 3));
            if (mounted) _showInterventionDialog(result);
            await prefs.setInt('last_intervention_ts', nowTs);
          }
        }
      }
    } catch (e) {
      debugPrint('Intervention check failed: $e');
    }
  }

  void _showInterventionDialog(Map<String, dynamic> result) {
    final role = result['role'] ?? 'AI';
    final message = result['message'] ?? '';
    final actionLabel = result['action_label'] ?? '確認';

    Color roleColor = Colors.blueGrey;
    IconData roleIcon = Icons.notifications;

    final r = role.toString().toUpperCase();
    if (r.contains('CHO')) {
      roleColor = Colors.green;
      roleIcon = Icons.health_and_safety;
    } else if (r.contains('CSO')) {
      roleColor = Colors.blueGrey;
      roleIcon = Icons.psychology;
    } else if (r.contains('CFO') || r.contains('AUDIT')) {
      roleColor = Colors.teal;
      roleIcon = Icons.attach_money;
    } else if (r.contains('CHRO')) {
      roleColor = Colors.pink;
      roleIcon = Icons.diversity_3;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _navy,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: roleColor, width: 2)),
        title: Row(
          children: [
            CircleAvatar(
                backgroundColor: roleColor.withOpacity(0.2),
                child: Icon(roleIcon, color: roleColor)),
            const SizedBox(width: 12),
            Text('$role からの提言',
                style: TextStyle(
                    color: roleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ],
        ),
        content: Text(message,
            style: const TextStyle(
                color: Colors.white, fontSize: 16, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('あとで', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: roleColor, foregroundColor: Colors.white),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
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
          'multi_response': true
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

    final res1 = results[0]; // Provider A
    final res2 = results[1]; // Provider B

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

  //  復活させたログアウト機能
  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LandingPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDigitalMet = _todayDigitalCount >= _dailyDigitalGoal;
    final isRealMet = _todayRealCount >= _dailyRealGoal;
    final isAllMet = isDigitalMet && isRealMet;

    return Scaffold(
      backgroundColor: _bgGrey,
      drawer: _buildDrawer(),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _navy))
          : CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 60,
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                  color: _navy.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4))
                            ],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _isMeeting
                                ? null
                                : () => _holdBoardMeeting(isMorning: false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _navy,
                              foregroundColor: _gold,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            icon: _isMeeting
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        color: _gold, strokeWidth: 2))
                                : const Icon(Icons.compare_arrows, size: 28),
                            label: const Text('緊急役員会議 (Battle Mode)',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        Text('DEPARTMENTS',
                            style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.2)),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.6,
                    children: [
                      _buildDeptCard('戦略室 (CSO)', 'AI秘書', Icons.psychology,
                          Colors.blueGrey, const AISecretaryPage()),
                      _buildDeptCard('財務省 (CFO)', '月次決算', Icons.account_balance,
                          Colors.teal, const SubscriptionPage()),
                      _buildDeptCard('知財本部 (CKO)', 'AI大学', Icons.school,
                          Colors.indigo, const GeminiUniversityPage()),
                      _buildDeptCard('健康管理 (CHO)', 'AI検食', Icons.monitor_heart,
                          Colors.green.shade800, const HealthPage()),
                      _buildDeptCard('広報室 (CMO)', '分析 & PR', Icons.campaign,
                          Colors.purple, const CmoPage()),
                      _buildDeptCard('人事局 (CHRO)', '福利厚生', Icons.diversity_3,
                          Colors.pink, const ChroPage()),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        Text('OPERATIONS',
                            style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.2)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2))
                            ],
                            border: Border.all(
                                color: isAllMet
                                    ? Colors.green
                                    : Colors.red.withOpacity(0.3),
                                width: 2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                      isAllMet
                                          ? Icons.verified
                                          : Icons.warning_amber,
                                      color: isAllMet
                                          ? Colors.green
                                          : Colors.redAccent),
                                  const SizedBox(width: 8),
                                  Text(isAllMet ? '就寝許可証: 発行済' : '就寝許可証: 未発行',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: _navy)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildProgressRow('デジタル断捨離', _todayDigitalCount,
                                  _dailyDigitalGoal, Colors.blue, () async {
                                await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const DanshariPage()));
                                _loadData();
                              }),
                              const SizedBox(height: 12),
                              _buildProgressRow('リアル断捨離', _todayRealCount,
                                  _dailyRealGoal, Colors.orange, () {
                                Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const RealWorldDanshariPage()))
                                    .then((_) => _loadData());
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildOperationButton(
                                  'クイックメモ',
                                  Icons.edit_note,
                                  Colors.blue.shade800, () async {
                                await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const NoteEditorPage()));
                                _loadData();
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text('PROJECTS',
                            style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.2)),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                _notes.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Center(
                              child: Text(
                                  '現在進行中の案件はありません。\n「クイックメモ」から起案してください。',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey[400]))),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final note = _notes[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 4.0),
                              child: Card(
                                elevation: 0,
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                        color: Colors.grey.shade200)),
                                child: ListTile(
                                  title: Text(note.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  subtitle: Text(note.content,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                  trailing: const Icon(Icons.arrow_forward_ios,
                                      size: 12, color: Colors.grey),
                                  onTap: () async {
                                    await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                NoteEditorPage(note: note)));
                                    _loadData();
                                  },
                                ),
                              ),
                            );
                          },
                          childCount: _notes.length,
                        ),
                      ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
    );
  }

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
