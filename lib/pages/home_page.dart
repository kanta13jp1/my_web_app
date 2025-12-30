import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final ImagePicker _picker = ImagePicker();

  final List<MissionItem> _dailyMissions = [
    MissionItem(name: '洗い物'),
    MissionItem(name: '洗濯'),
    MissionItem(name: '自炊'),
    MissionItem(name: '入浴'),
    MissionItem(name: '掃除'),
    MissionItem(name: '片付け'),
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt('last_intervention_ts') ?? 0;
      final nowTs = DateTime.now().millisecondsSinceEpoch;
      if (nowTs - lastCheck < 3600000) return;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final boardData = {
        'userStats': {'total_points': _totalPoints},
        'recentNotes': _notes.take(5).toList()
      };
      final response = await supabase.functions.invoke('ai-assistant', body: {
        'action': 'proactive_intervention',
        'boardData': boardData,
        'currentTime': TimeOfDay.now().format(context)
      });
      if (response.status == 200 && response.data['success'] == true) {
        final result = response.data['result'];
        if (result['should_intervene'] == true) {
          await Future.delayed(const Duration(seconds: 3));
          if (mounted) _showInterventionDialog(result);
          await prefs.setInt('last_intervention_ts', nowTs);
        }
      }
    } catch (_) {}
  }

  void _showInterventionDialog(Map<String, dynamic> result) {
    final role = result['role'] ?? 'AI';
    final message = result['message'] ?? '';
    final actionLabel = result['action_label'] ?? '確認';
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
                backgroundColor: _navy,
                title: Text('$role からの提言',
                    style: const TextStyle(color: Colors.white)),
                content:
                    Text(message, style: const TextStyle(color: Colors.white)),
                actions: [
                  ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(actionLabel))
                ]));
  }

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
      final response = await supabase.functions.invoke('ai-assistant', body: {
        'action': 'verify_mission_proof',
        'missionName': _dailyMissions[index].name,
        'imageBase64': base64Image,
        'mimeType': 'image/jpeg'
      });
      final result = response.data['result'];
      setState(() {
        _dailyMissions[index].isAnalyzing = false;
        _dailyMissions[index].isVerified = result['verified'] == true;
        _dailyMissions[index].aiComment = result['comment'];
      });
    } catch (e) {
      setState(() => _dailyMissions[index].isAnalyzing = false);
    }
  }

  Future<void> _requestBedtimePermission() async {
    setState(() => _isMeeting = true);
    Map<String, bool> statusMap = {};
    for (var m in _dailyMissions) statusMap[m.name] = m.isVerified;
    try {
      final response = await supabase.functions.invoke('ai-assistant', body: {
        'action': 'check_bedtime_permission',
        'missionData': statusMap,
        'currentTime': TimeOfDay.now().format(context)
      });
      final result = response.data['result'];
      if (mounted)
        _showGatekeeperDialog(result, result['permission_granted'] == true,
            response.data['provider'] ?? 'AI');
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      if (mounted) setState(() => _isMeeting = false);
    }
  }

  void _showGatekeeperDialog(
      Map<String, dynamic> result, bool isGranted, String provider) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
                backgroundColor: _navy,
                title: Text(isGranted ? '承認' : '却下',
                    style: const TextStyle(color: Colors.white)),
                content: Text(result['message'] ?? '',
                    style: const TextStyle(color: Colors.white)),
                actions: [
                  ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('了解'))
                ]));
  }

  Future<void> _holdBoardMeeting({bool isMorning = false}) async {
    setState(() => _isMeeting = true);
    try {
      final boardData = {'recentNotes': _notes.take(5).toList()};
      final response = await supabase.functions.invoke('ai-assistant', body: {
        'action': 'hold_board_meeting',
        'boardData': boardData,
        'multi_response': true
      });
      final data = response.data;
      if (mounted) {
        if (data['is_multi'] == true && (data['results'] as List).length >= 2) {
          _showBattleResult(data['results']);
        } else {
          _showMeetingResult(data['is_multi'] == true
              ? data['results'][0]['result']
              : data['result']);
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isMeeting = false);
    }
  }

  void _showBattleResult(List<dynamic> results) {
    showDialog(
        context: context,
        builder: (context) => Dialog(
            backgroundColor: _navy,
            child: Row(children: [
              Expanded(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Text(results[0]['result']['discussion'].toString(),
                          style: const TextStyle(color: Colors.white70)))),
              const VerticalDivider(),
              Expanded(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Text(results[1]['result']['discussion'].toString(),
                          style: const TextStyle(color: Colors.white70))))
            ])));
  }

  void _showMeetingResult(Map<String, dynamic> result) {
    showDialog(
        context: context,
        builder: (context) =>
            AlertDialog(
                backgroundColor: _navy,
                title:
                    const Text('会議結果', style: TextStyle(color: Colors.white)),
                content: Text(result['discussion'] ?? '',
                    style: const TextStyle(color: Colors.white70)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('了解'))
                ]));
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted)
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LandingPage()));
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 320.0,
      pinned: true,
      backgroundColor: _navy,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
          background: Container(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_navy, const Color(0xFF1E293B)])),
              child: SafeArea(
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Capital',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                            Text('$_totalPoints Pt',
                                style: TextStyle(
                                    color: _gold,
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildKpiItem('Health', '$_healthScore'),
                                  _buildKpiItem('Fixed Cost', '$_fixedCost'),
                                  _buildKpiItem('Tasks', '$_taskCount')
                                ])
                          ]))))),
      title: const Text('自分株式会社'),
      actions: [
        IconButton(icon: const Icon(Icons.logout), onPressed: _signOut)
      ],
    );
  }

  Widget _buildKpiItem(String label, String value) {
    return Column(children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      Text(value,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))
    ]);
  }

  Widget _buildProgressRow(
      String label, int current, int goal, Color color, VoidCallback onTap) {
    return InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            Text('$current / $goal')
          ]),
          const SizedBox(height: 4),
          LinearProgressIndicator(
              value: (current / goal).clamp(0, 1).toDouble(),
              color: color,
              backgroundColor: color.withOpacity(0.1))
        ]));
  }

  Widget _buildDeptCard(String title, IconData icon, Color color, Widget page) {
    return InkWell(
        onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => page))
                .then((_) => _loadData()),
        child: Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 4)
                ]),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14))
            ])));
  }

  @override
  Widget build(BuildContext context) {
    final isAllMet = _todayDigitalCount >= _dailyDigitalGoal &&
        _todayRealCount >= _dailyRealGoal &&
        _dailyMissions.every((m) => m.isVerified);
    return Scaffold(
      backgroundColor: _bgGrey,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _navy))
          : CustomScrollView(slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('OPERATIONS',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.grey)),
                            const SizedBox(height: 8),
                            Card(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(children: [
                                      Row(children: [
                                        Icon(
                                            isAllMet
                                                ? Icons.verified
                                                : Icons.warning,
                                            color: isAllMet
                                                ? Colors.green
                                                : Colors.orange),
                                        const SizedBox(width: 8),
                                        Text(
                                            isAllMet
                                                ? '就寝許可: 発行済'
                                                : '就寝許可: 未発行',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold))
                                      ]),
                                      const Divider(height: 24),
                                      ..._dailyMissions.asMap().entries.map(
                                          (e) => ListTile(
                                              dense: true,
                                              title: Text(e.value.name),
                                              trailing: e.value.isVerified
                                                  ? const Icon(
                                                      Icons.check_circle,
                                                      color: Colors.green)
                                                  : IconButton(
                                                      icon: const Icon(
                                                          Icons.camera_alt),
                                                      onPressed: () =>
                                                          _verifyMission(
                                                              e.key)))),
                                      const SizedBox(height: 16),
                                      _buildProgressRow(
                                          'デジタル断捨離',
                                          _todayDigitalCount,
                                          _dailyDigitalGoal,
                                          Colors.blue,
                                          () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (_) =>
                                                          const DanshariPage()))
                                              .then((_) => _loadData())),
                                      const SizedBox(height: 12),
                                      _buildProgressRow(
                                          'リアル断捨離',
                                          _todayRealCount,
                                          _dailyRealGoal,
                                          Colors.orange,
                                          () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (_) =>
                                                          const RealWorldDanshariPage()))
                                              .then((_) => _loadData())),
                                      const SizedBox(height: 24),
                                      SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                              onPressed: _isMeeting
                                                  ? null
                                                  : _requestBedtimePermission,
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: _navy),
                                              child: const Text('就寝許可を申請する',
                                                  style: TextStyle(
                                                      color: Colors.white))))
                                    ]))),
                            const SizedBox(height: 16),
                            SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                    onPressed: () => _holdBoardMeeting(),
                                    icon: const Icon(Icons.groups),
                                    label: const Text('緊急役員会議'))),
                            const SizedBox(height: 24),
                            const Text('DEPARTMENTS',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.grey)),
                          ]))),
              SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      children: [
                        _buildDeptCard('CSO 戦略', Icons.psychology,
                            Colors.blueGrey, const AISecretaryPage()),
                        _buildDeptCard('CFO 財務', Icons.account_balance,
                            Colors.teal, const SubscriptionPage()),
                        _buildDeptCard('CKO 知財', Icons.folder, Colors.indigo,
                            const NoteEditorPage()),
                        _buildDeptCard('CHO 健康', Icons.restaurant, Colors.green,
                            const HealthPage()),
                        _buildDeptCard('CMO 広報', Icons.campaign, Colors.purple,
                            const CmoPage()),
                        _buildDeptCard('AIステータス', Icons.monitor_heart,
                            Colors.red, const AiStatusPage())
                      ])),
              const SliverToBoxAdapter(child: SizedBox(height: 100))
            ]),
    );
  }
}
