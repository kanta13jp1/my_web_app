// home_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ✅ 改善ポイント:
  // build() のたびに _fetchTotalAssets() が走るのを防ぐため Future をキャッシュする
  late Future<String> _totalAssetsFuture;

  @override
  void initState() {
    super.initState();
    _totalAssetsFuture = _fetchTotalAssets();
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
    });
  }

  // ▼ 各資産の「最新の残高」を取得して合計するロジック（現状維持 + 例外対策）
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
      // 1. ユーザーの全資産データを取得（日付の古い順）
      final data = await Supabase.instance.client
          .from('cfo_assets')
          .select('title, amount, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      if (data.isEmpty) {
        return NumberFormat.currency(
          locale: 'ja_JP',
          symbol: '¥',
          decimalDigits: 0,
        ).format(0);
      }

      // 2. 各資産ごとの「最新の金額」を保持するMap
      final Map<String, double> latestAssets = {};

      // 古い順でループ → 同じtitleは最新で上書きされ続ける
      for (final item in data) {
        final String title = (item['title'] ?? '').toString();
        final num rawAmount = (item['amount'] as num?) ?? 0;
        latestAssets[title] = rawAmount.toDouble();
      }

      // 3. 各資産の最新残高を合計
      double total = 0;
      for (final amount in latestAssets.values) {
        total += amount;
      }

      // 4. 通貨フォーマット（マイナスも対応）
      final formatter = NumberFormat.currency(
        locale: 'ja_JP',
        symbol: '¥',
        decimalDigits: 0,
      );
      return formatter.format(total);
    } catch (e) {
      debugPrint('Error fetching total assets: $e');
      return 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final primaryColor = themeService.primaryColor;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Column(
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
        child: SingleChildScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(), // Pull-to-Refreshを効かせる
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'CEO OFFICE',
                Icons.business_center,
                Colors.redAccent,
              ),
              _buildCeoCard(context),
              const SizedBox(height: 12),
              _buildMorningBriefingCard(context),
              const SizedBox(height: 24),
              _buildSectionHeader(
                'KPI SUMMARY',
                Icons.show_chart,
                Colors.purple,
              ),
              _buildKpiSummary(context, isDark),
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  leading: const CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 28,
                    child: Icon(Icons.campaign, color: Colors.indigo, size: 30),
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
              _buildGridMenu(context, [
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
                  '思考停止ログ',
                  Icons.access_time_filled,
                  Colors.indigo,
                  () => _nav(context, const MindlessTaskPage()),
                ),
              ]),
              const SizedBox(height: 24),
              _buildSectionHeader(
                'CFO/CHO/CHRO OFFICE',
                Icons.balance,
                Colors.teal,
              ),
              _buildGridMenu(context, [
                _MenuData(
                  '財務管理 (CFO)',
                  Icons.account_balance_wallet,
                  Colors.green,
                  () => _nav(context, const CfoOfficePage()),
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
                  'CMO/CKO OFFICE', Icons.analytics, Colors.blue),
              _buildGridMenu(context, [
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

  Widget _buildMorningBriefingCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        leading: const CircleAvatar(
          backgroundColor: Colors.amber,
          radius: 28,
          child: Icon(Icons.wb_sunny, color: Colors.white, size: 30),
        ),
        title: const Text(
          'モーニング・ブリーフィング',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: const Text('今日のタスクと優先順位を確認します。'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MorningBriefingPage(),
          ),
        ),
      ),
    );
  }

  Widget _buildGridMenu(BuildContext context, List<_MenuData> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.5,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Material(
          color: Theme.of(context).cardColor,
          elevation: 2,
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
                      color: item.color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.icon, color: item.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
  Widget _buildKpiSummary(BuildContext context, bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.8,
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
    final labelColor = isDark ? Colors.white70 : Colors.black.withOpacity(0.6);

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
  _MenuData(this.title, this.icon, this.color, this.onTap);
}
