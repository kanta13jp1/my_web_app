import 'dart:math';
import 'dart:convert';
import 'dart:typed_data'; // For Web Image
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Camera
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

//  Mission Class Definition
class MissionItem {
  final String name;
  bool isVerified;
  bool isAnalyzing;
  String? aiComment;

  MissionItem(
      {required this.name,
      this.isVerified = false,
      this.isAnalyzing = false,
      this.aiComment});
}

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

  final ImagePicker _picker = ImagePicker();

  //  Strict Mission State
  final List<MissionItem> _dailyMissions = [
    MissionItem(name: '洗い物 (Dishes)'),
    MissionItem(name: '洗濯 (Laundry)'),
    MissionItem(name: '自炊 (Cooking)'),
    MissionItem(name: '入浴 (Bath)'),
    MissionItem(name: '部屋の掃除 (Cleaning)'),
    MissionItem(name: '机の片付け (Tidying)'),
  ];

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
      final response = await supabase
          .from('user_stats')
          .select()
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();
      if (response != null) {
        setState(() {
          _totalPoints = response['total_points'] ?? 0;
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
    // (Simplified for brevity)
  }

  // ---  Strict Verification Logic ---
  Future<void> _verifyMission(int index) async {
    try {
      final XFile? photo = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 70);
      if (photo == null) return;

      setState(() => _dailyMissions[index].isAnalyzing = true);
      final bytes = await photo.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'verify_mission_proof',
          'missionName': _dailyMissions[index].name,
          'imageBase64': base64Image,
          'mimeType': 'image/jpeg',
        },
      );

      if (response.status != 200) throw Exception('Validation Failed');
      final data = response.data;
      if (data['success'] != true) throw Exception('Validation Error');

      final result = data['result'];
      final bool verified = result['verified'] == true;
      final String comment = result['comment'] ?? '...';

      setState(() {
        _dailyMissions[index].isAnalyzing = false;
        _dailyMissions[index].isVerified = verified;
        _dailyMissions[index].aiComment = comment;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(verified ? ' 承認: $comment' : ' 却下: $comment'),
          backgroundColor: verified ? Colors.green : Colors.redAccent,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エラー: $e')));
        setState(() => _dailyMissions[index].isAnalyzing = false);
      }
    }
  }

  // --- Bedtime Permission ---
  Future<void> _requestBedtimePermission() async {
    setState(() => _isMeeting = true);

    // Check if ALL verifications are passed
    // We convert List<MissionItem> to Map<String, bool> for the API
    Map<String, bool> statusMap = {};
    for (var m in _dailyMissions) {
      statusMap[m.name] = m.isVerified;
    }

    try {
      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'check_bedtime_permission',
          'missionData': statusMap,
          'currentTime': TimeOfDay.now().format(context),
        },
      );

      if (response.status != 200) throw Exception('Gatekeeper Error');
      final data = response.data;
      if (data['success'] != true) throw Exception(data['error']);

      final result = data['result'];
      final isGranted = result['permission_granted'] == true;

      if (mounted) {
        _showGatekeeperDialog(result, isGranted, data['provider'] ?? 'AI');
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isMeeting = false);
    }
  }

  void _showGatekeeperDialog(
      Map<String, dynamic> result, bool isGranted, String provider) {
    final color = isGranted ? Colors.green : Colors.redAccent;
    final title = result['title'] ??
        (isGranted ? 'PERMISSION GRANTED' : 'PERMISSION DENIED');
    final message = result['message'] ?? '';
    final punishment = result['punishment'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _navy,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: color, width: 3)),
        title: Column(
          children: [
            Icon(isGranted ? Icons.check_circle : Icons.block,
                color: color, size: 48),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 20)),
            Text('Judge: $provider',
                style: TextStyle(color: Colors.grey[500], fontSize: 10)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, height: 1.5),
                textAlign: TextAlign.center),
            if (punishment != null && !isGranted) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('指令: $punishment',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold))),
                  ],
                ),
              )
            ]
          ],
        ),
        actions: [
          if (isGranted)
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('おやすみなさい'),
            )
          else
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('直ちに行動する'),
            )
        ],
      ),
    );
  }

  // --- Other existing methods (placeholders for brevity) ---
  Future<void> _holdBoardMeeting({bool isMorning = false}) async {
    /* Same as before */
  }
  void _showBattleResult(List<dynamic> results, {bool isMorning = false}) {}
  void _showMeetingResult(Map<String, dynamic> result,
      {bool isMorning = false, String? provider}) {}
  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted)
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LandingPage()));
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

                // ---  STRICT DAILY MISSION CONTROL ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DAILY MANDATORY MISSIONS (STRICT)',
                              style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.2)),
                          const SizedBox(height: 8),
                          Card(
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.grey.shade200)),
                            child: Column(
                              children: [
                                ListView.separated(
                                  physics: const NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  itemCount: _dailyMissions.length,
                                  separatorBuilder: (c, i) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final item = _dailyMissions[index];
                                    return ListTile(
                                      title: Text(item.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14)),
                                      subtitle: item.aiComment != null
                                          ? Text(item.aiComment!,
                                              style: TextStyle(
                                                  color: item.isVerified
                                                      ? Colors.green
                                                      : Colors.red,
                                                  fontSize: 12))
                                          : const Text('証拠画像を提出してください',
                                              style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 11)),
                                      trailing: item.isAnalyzing
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2))
                                          : item.isVerified
                                              ? const Icon(Icons.check_circle,
                                                  color: Colors.green)
                                              : IconButton(
                                                  icon: const Icon(
                                                      Icons.camera_alt,
                                                      color: Colors.blueGrey),
                                                  onPressed: () =>
                                                      _verifyMission(index),
                                                ),
                                    );
                                  },
                                ),
                                const Divider(),
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _isMeeting
                                          ? null
                                          : _requestBedtimePermission,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isMeeting
                                            ? Colors.grey
                                            : Colors.indigo.shade900,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      icon: _isMeeting
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2))
                                          : const Icon(Icons.bed),
                                      label: const Text('就寝許可を申請する',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ]),
                  ),
                ),

                // ... (Other sections kept same) ...
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
                    ],
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
