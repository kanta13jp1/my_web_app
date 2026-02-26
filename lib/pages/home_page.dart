// home_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// Services
import '../services/theme_service.dart';

// Pages
import 'note_editor_page.dart';
import 'note_list_page.dart';
import 'ai_status_page.dart';
import 'danshari_page.dart';
import 'gemini_university_v2_page.dart';
import 'emergency_meeting_page.dart';
import 'real_world_danshari_page.dart';
import 'landing_page.dart';
import 'cfo_office_page.dart';
import 'cho_office_page.dart';
import 'cmo_office_page.dart';
import 'chro_office_page.dart';
import 'morning_briefing_page.dart';
import 'election_strategy_page.dart';
import 'mind_map_page.dart';
import 'settings_page.dart';
import 'stock_tasks_page.dart';
import 'mindless_task_page.dart';
import 'wardrobe_page.dart'; // 先頭のimport群に追加

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ✅ 改善ポイント:
  // build() のたびに _fetchTotalAssets() が走るのを防ぐため Future をキャッシュする
  late Future<String> _totalAssetsFuture;
  late Future<_HomeOpsSnapshot> _opsSnapshotFuture;

  @override
  void initState() {
    super.initState();
    _totalAssetsFuture = _fetchTotalAssets();
    _opsSnapshotFuture = _loadOpsSnapshot();
  }

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LandingPage()),
      );
    }
  }

  // ✅ Pull-to-Refresh 用（必要なときだけKPIを再取得）
  Future<void> _refreshKpis() async {
    setState(() {
      _totalAssetsFuture = _fetchTotalAssets();
      _opsSnapshotFuture = _loadOpsSnapshot();
    });
    await _totalAssetsFuture;
    await _opsSnapshotFuture;
  }

  String get _todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  String get _morningBriefingDoneKey => 'home_morning_briefing_done_$_todayKey';

  String get _balanceCheckDoneKey => 'home_balance_check_done_$_todayKey';

  Future<int> _fetchPendingCriticalTaskCount() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return 0;

    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      final dynamic rowsRaw = await Supabase.instance.client
          .from('mindless_tasks')
          .select('content,is_completed')
          .eq('user_id', userId)
          .eq('task_date', dateStr);
      final rows = rowsRaw is List ? rowsRaw : const <dynamic>[];

      return rows.whereType<Map<String, dynamic>>().where((row) {
        final raw = row['content'] as String? ?? '';
        final content = raw.replaceFirst(RegExp(r'^\[(A|B|C)\]\s*'), '');
        final isCriticalTask = content.startsWith('必須: ');
        final isCompleted = row['is_completed'] == true;
        return isCriticalTask && !isCompleted;
      }).length;
    } catch (e) {
      debugPrint('Error fetching critical task count: $e');
      return 0;
    }
  }

  Future<_HomeOpsSnapshot> _loadOpsSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingCriticalTaskCount = await _fetchPendingCriticalTaskCount();

    return _HomeOpsSnapshot(
      morningBriefingDone: prefs.getBool(_morningBriefingDoneKey) ?? false,
      balanceCheckDone: prefs.getBool(_balanceCheckDoneKey) ?? false,
      pendingCriticalTaskCount: pendingCriticalTaskCount,
    );
  }

  Future<void> _markMorningBriefingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_morningBriefingDoneKey, true);
  }

  Future<void> _markBalanceCheckDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_balanceCheckDoneKey, true);
  }

  _HomeActionCommand _resolveNextAction(_HomeOpsSnapshot snapshot) {
    final hour = DateTime.now().hour;
    if (!snapshot.morningBriefingDone && hour < 12) {
      return const _HomeActionCommand(
        type: _HomeActionType.morningBriefing,
        title: 'モーニング・ブリーフィングを先に実施',
        detail: '朝の優先順位を確定してから他メニューへ進む。',
        icon: Icons.wb_sunny,
        color: Colors.amber,
      );
    }

    if (!snapshot.balanceCheckDone) {
      return const _HomeActionCommand(
        type: _HomeActionType.balanceCheck,
        title: '今日の口座残高を確認',
        detail: 'まず資金状態を把握して、日次の打ち手を決める。',
        icon: Icons.account_balance_wallet,
        color: Colors.green,
      );
    }

    if (snapshot.pendingCriticalTaskCount > 0) {
      return _HomeActionCommand(
        type: _HomeActionType.criticalTasks,
        title: '必須タスクを先に完了',
        detail: '思考停止ログの必須タスクが${snapshot.pendingCriticalTaskCount}件残っています。',
        icon: Icons.lock_clock,
        color: Colors.redAccent,
      );
    }

    return const _HomeActionCommand(
      type: _HomeActionType.none,
      title: '今日の必須導線は完了済み',
      detail: '次は通常メニューを優先度順に実行。',
      icon: Icons.verified,
      color: Colors.blueGrey,
    );
  }

  Future<void> _openMorningBriefing(BuildContext context) async {
    await _markMorningBriefingDone();
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MorningBriefingPage(),
      ),
    );
    if (mounted) {
      await _refreshKpis();
    }
  }

  Future<void> _openCfoOffice(BuildContext context) async {
    await _markBalanceCheckDone();
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CfoOfficePage()),
    );
    if (mounted) {
      await _refreshKpis();
    }
  }

  Widget _buildNextActionBubble(
    BuildContext context,
    _HomeActionCommand command,
    _HomeOpsSnapshot snapshot,
  ) {
    String buttonLabel = '最新化';
    VoidCallback? onPressed = () {
      _refreshKpis();
    };

    if (command.type == _HomeActionType.morningBriefing) {
      buttonLabel = 'ブリーフィングへ';
      onPressed = () {
        _openMorningBriefing(context);
      };
    } else if (command.type == _HomeActionType.balanceCheck) {
      buttonLabel = '財務管理へ';
      onPressed = () {
        _openCfoOffice(context);
      };
    } else if (command.type == _HomeActionType.criticalTasks) {
      buttonLabel = '必須タスクへ';
      onPressed = () {
        _nav(context, const MindlessTaskPage());
      };
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: command.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: command.color.withValues(alpha: 0.75)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white,
            child: Icon(command.icon, color: command.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '次に実施すべきアクション',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  command.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'AI推奨: ${command.detail}',
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
                if (snapshot.pendingCriticalTaskCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '未完了の必須タスク: ${snapshot.pendingCriticalTaskCount}件',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: command.color,
              foregroundColor: Colors.white,
            ),
            onPressed: onPressed,
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }

  Future<String> _fetchTotalAssets() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      return NumberFormat.currency(
        locale: 'ja_JP',
        symbol: '¥',
        decimalDigits: 0,
      ).format(0);
    }

    try {
      // ✅ RPC: スカラー(numeric)が返ってくる想定
      final res = await Supabase.instance.client.rpc('cfo_total_assets');

      final total = (res as num?)?.toDouble() ?? 0.0;

      final formatter = NumberFormat.currency(
        locale: 'ja_JP',
        symbol: '¥',
        decimalDigits: 0,
      );
      return formatter.format(total);
    } catch (e) {
      debugPrint('Error fetching total assets (rpc): $e');
      return 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final primaryColor = themeService.primaryColor;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 390;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('自分株式会社 経営コックピット'),
            // 時計部分を独立したウィジェットとして配置（パフォーマンス改善）
            _ClockWidget(),
          ],
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeService.toggleTheme(),
            tooltip: 'テーマ切替',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
            tooltip: '設定',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'ログアウト',
          ),
        ],
      ),

      // ✅ 改善: RefreshIndicator を追加（KPIのみ再取得できる）
      body: RefreshIndicator(
        onRefresh: _refreshKpis,
        child: FutureBuilder<_HomeOpsSnapshot>(
          future: _opsSnapshotFuture,
          builder: (context, snapshot) {
            final opsSnapshot = snapshot.data ?? const _HomeOpsSnapshot();
            final nextAction = _resolveNextAction(opsSnapshot);
            final highlightMorning =
                nextAction.type == _HomeActionType.morningBriefing;
            final highlightBalance =
                nextAction.type == _HomeActionType.balanceCheck;
            final highlightCritical =
                nextAction.type == _HomeActionType.criticalTasks;

            return SingleChildScrollView(
              physics:
                  const AlwaysScrollableScrollPhysics(), // Pull-to-Refreshを効かせる
              padding: EdgeInsets.all(isCompact ? 12.0 : 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNextActionBubble(context, nextAction, opsSnapshot),
                  const SizedBox(height: 20),
                  _buildSectionHeader(
                    'CEO OFFICE',
                    Icons.business_center,
                    Colors.redAccent,
                  ),
                  _buildCeoCard(context),
                  const SizedBox(height: 12),
                  _buildMorningBriefingCard(
                    context,
                    isHighlighted: highlightMorning,
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    'KPI SUMMARY',
                    Icons.show_chart,
                    Colors.purple,
                  ),
                  _buildKpiSummary(context, isDark, isCompact),
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    'SPECIAL PROJECT',
                    Icons.rocket_launch,
                    Colors.indigo,
                  ),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: Colors.indigo,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      leading: const CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 28,
                        child: Icon(
                          Icons.campaign,
                          color: Colors.indigo,
                          size: 30,
                        ),
                      ),
                      title: const Text(
                        '2026 衆院選 勝利戦略室',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: const Text(
                        'AI参謀と連携し、地域特性を踏まえた勝利戦略を立案します。',
                        style: TextStyle(color: Colors.white70),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.white,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ElectionStrategyPage(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader('CSO OFFICE', Icons.flag, Colors.orange),
                  _buildGridMenu(context, isCompact, [
                    _MenuData(
                      '断捨離 (デジタル)',
                      Icons.cleaning_services,
                      Colors.orange,
                      () => _nav(context, const DanshariPage()),
                    ),
                    _MenuData(
                      '断捨離 (リアル)',
                      Icons.camera_alt,
                      Colors.deepOrange,
                      () => _nav(
                        context,
                        RealWorldDanshariPage(
                          supabaseClient: Supabase.instance.client,
                        ),
                      ),
                    ),
                    _MenuData(
                      'AI稼働モニター',
                      Icons.monitor_heart,
                      Colors.orange,
                      () => _nav(context, const AiStatusPage()),
                    ),
                    _MenuData(
                      '週末ストック',
                      Icons.check_circle_outline,
                      Colors.teal,
                      () => _nav(context, const StockTasksPage()),
                    ),
                    _MenuData(
                      '思考停止ログ（読書ループ）',
                      Icons.access_time_filled,
                      Colors.indigo,
                      () => _nav(context, const MindlessTaskPage()),
                      isHighlighted: highlightCritical,
                      badgeLabel: highlightCritical ? 'NEXT' : null,
                    ),
                    _MenuData(
                      'ワードローブ整理',
                      Icons.checkroom,
                      Colors.brown,
                      () => _nav(context, const WardrobePage()),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    'CFO/CHO/CHRO OFFICE',
                    Icons.balance,
                    Colors.teal,
                  ),
                  _buildGridMenu(context, isCompact, [
                    _MenuData(
                      '財務管理 (CFO)',
                      Icons.account_balance_wallet,
                      Colors.green,
                      () => _openCfoOffice(context),
                      isHighlighted: highlightBalance,
                      badgeLabel: highlightBalance ? 'NEXT' : null,
                    ),
                    _MenuData(
                      '健康管理 (CHO)',
                      Icons.medical_services,
                      Colors.teal,
                      () => _nav(context, const ChoOfficePage()),
                    ),
                    _MenuData(
                      '人事厚生 (CHRO)',
                      Icons.diversity_3,
                      Colors.indigo,
                      () => _nav(context, const ChroOfficePage()),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    'CMO/CKO OFFICE',
                    Icons.analytics,
                    Colors.blue,
                  ),
                  _buildGridMenu(context, isCompact, [
                    _MenuData(
                      '市場分析 (CMO)',
                      Icons.trending_up,
                      Colors.pink,
                      () => _nav(context, const CmoOfficePage()),
                    ),
                    _MenuData(
                      'メモ一覧 (CKO)',
                      Icons.list_alt,
                      Colors.blue,
                      () => _nav(context, const NoteListPage()),
                    ),
                    _MenuData(
                      '新規事業起案',
                      Icons.edit_note,
                      Colors.blue,
                      () => _nav(context, const NoteEditorPage()),
                    ),
                    _MenuData(
                      'Gemini大学',
                      Icons.menu_book,
                      Colors.blue,
                      () => _nav(context, const GeminiUniversityV2Page()),
                    ),
                    _MenuData(
                      'マインドマップ (思考整理)',
                      Icons.hub,
                      Colors.blue,
                      () => _nav(context, const MindMapPage()),
                    ),
                  ]),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _nav(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCeoCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        leading: const CircleAvatar(
          backgroundColor: Colors.redAccent,
          radius: 28,
          child: Icon(Icons.emergency, color: Colors.white, size: 30),
        ),
        title: const Text(
          '緊急役員会議',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: const Text('CEOとして全AI役員を招集し、直面している課題を解決します。'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const EmergencyMeetingPage(),
          ),
        ),
      ),
    );
  }

  Widget _buildMorningBriefingCard(
    BuildContext context, {
    bool isHighlighted = false,
  }) {
    return Card(
      elevation: isHighlighted ? 6 : 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isHighlighted ? Colors.amber.shade50 : null,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        leading: CircleAvatar(
          backgroundColor: isHighlighted ? Colors.amber.shade700 : Colors.amber,
          radius: 28,
          child: const Icon(Icons.wb_sunny, color: Colors.white, size: 30),
        ),
        title: Text(
          isHighlighted ? 'モーニング・ブリーフィング（最優先）' : 'モーニング・ブリーフィング',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          isHighlighted ? 'まず朝の優先順位を固定してください。' : '今日のタスクと優先順位を確認します。',
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _openMorningBriefing(context),
      ),
    );
  }

  Widget _buildGridMenu(
    BuildContext context,
    bool isCompact,
    List<_MenuData> items,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isCompact ? 1 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isCompact ? 3.3 : 2.5,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Material(
          color: item.isHighlighted
              ? item.color.withValues(alpha: 0.12)
              : Theme.of(context).cardColor,
          elevation: item.isHighlighted ? 4 : 2,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: item.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.icon, color: item.color, size: 20),
                  ),
                  SizedBox(width: isCompact ? 10 : 12),
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: item.isHighlighted ? item.color : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.badgeLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.badgeLabel!,
                        style: TextStyle(
                          color: item.color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // KPIサマリー
  Widget _buildKpiSummary(BuildContext context, bool isDark, bool isCompact) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isCompact ? 1 : 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: isCompact ? 2.4 : 1.8,
      children: [
        // ✅ 総資産（Futureキャッシュを渡す）
        _buildAsyncKpiCard(
          context,
          isDark,
          '総資産 (CFO)',
          Icons.account_balance,
          Colors.green,
          _totalAssetsFuture,
        ),
        // ダミー
        _buildKpiCard(
          context,
          isDark,
          '睡眠時間 (CHO)',
          '7h 30m',
          Icons.bedtime,
          Colors.blue,
        ),
        _buildKpiCard(
          context,
          isDark,
          '訪問者数 (CMO)',
          '8,123',
          Icons.people,
          Colors.pink,
        ),
        _buildKpiCard(
          context,
          isDark,
          '新規メモ (CKO)',
          '3件',
          Icons.note_add,
          Colors.orange,
        ),
      ],
    );
  }

  // 非同期データ用KPIカード
  Widget _buildAsyncKpiCard(
    BuildContext context,
    bool isDark,
    String title,
    IconData icon,
    Color color,
    Future<String> futureValue,
  ) {
    return FutureBuilder<String>(
      future: futureValue,
      builder: (context, snapshot) {
        // ローディング中はインジケータ
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final displayValue = snapshot.hasError
            ? 'Error'
            : (snapshot.data == null || snapshot.data!.isEmpty)
                ? '¥0'
                : snapshot.data!;

        return _buildKpiCard(
          context,
          isDark,
          title,
          displayValue,
          icon,
          color,
        );
      },
    );
  }

  // 通常のKPIカード
  Widget _buildKpiCard(
    BuildContext context,
    bool isDark,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final labelColor =
        isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.6);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: labelColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 時計表示（独立Widget）
class _ClockWidget extends StatefulWidget {
  const _ClockWidget();

  @override
  State<_ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<_ClockWidget> {
  late DateTime _dateTime;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _dateTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _dateTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      DateFormat('yyyy/MM/dd HH:mm:ss').format(_dateTime),
      style: const TextStyle(fontSize: 12, color: Colors.white70),
    );
  }
}

class _MenuData {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isHighlighted;
  final String? badgeLabel;

  _MenuData(
    this.title,
    this.icon,
    this.color,
    this.onTap, {
    this.isHighlighted = false,
    this.badgeLabel,
  });
}

enum _HomeActionType {
  morningBriefing,
  balanceCheck,
  criticalTasks,
  none,
}

class _HomeActionCommand {
  final _HomeActionType type;
  final String title;
  final String detail;
  final IconData icon;
  final Color color;

  const _HomeActionCommand({
    required this.type,
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
  });
}

class _HomeOpsSnapshot {
  final bool morningBriefingDone;
  final bool balanceCheckDone;
  final int pendingCriticalTaskCount;

  const _HomeOpsSnapshot({
    this.morningBriefingDone = false,
    this.balanceCheckDone = false,
    this.pendingCriticalTaskCount = 0,
  });
}
