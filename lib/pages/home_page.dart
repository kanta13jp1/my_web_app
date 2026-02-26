// home_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// Services
import '../services/ai_service.dart';
import '../services/abstinence_guard_store.dart';
import '../services/theme_service.dart';

// Pages
import 'abstinence_guard_page.dart';
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
  final DateTime Function()? nowProvider;

  const HomePage({super.key, this.nowProvider});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ✅ 改善ポイント:
  // build() のたびに _fetchTotalAssets() が走るのを防ぐため Future をキャッシュする
  late Future<String> _totalAssetsFuture;
  late Future<_HomeOpsSnapshot> _opsSnapshotFuture;
  late Future<String?> _aiNudgeFuture;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _reloadHomeSignals();
  }

  DateTime _now() => widget.nowProvider?.call() ?? DateTime.now();

  void _reloadHomeSignals() {
    _totalAssetsFuture = _fetchTotalAssets();
    _opsSnapshotFuture = _loadOpsSnapshot();
    _aiNudgeFuture = _opsSnapshotFuture.then((snapshot) {
      final command = _resolveNextAction(snapshot);
      return _loadAiNudgeIfNeeded(command, snapshot);
    });
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
      _reloadHomeSignals();
    });
    await _totalAssetsFuture;
    await _opsSnapshotFuture;
    await _aiNudgeFuture;
  }

  String get _todayKey => DateFormat('yyyy-MM-dd').format(_now());

  String get _morningBriefingDoneKey => 'home_morning_briefing_done_$_todayKey';

  String get _balanceCheckDoneKey => 'home_balance_check_done_$_todayKey';

  String _aiNudgeCacheKey(_HomeActionType type) =>
      'home_ai_nudge_${_todayKey}_${type.name}';

  Future<int> _fetchPendingCriticalTaskCount() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return 0;

    final dateStr = DateFormat('yyyy-MM-dd').format(_now());
    try {
      final dynamic rowsRaw = await Supabase.instance.client
          .from('mindless_tasks')
          .select('id')
          .eq('user_id', userId)
          .eq('task_date', dateStr)
          .eq('is_completed', false)
          .ilike('content', '%必須:%');
      final rows = rowsRaw is List ? rowsRaw : const <dynamic>[];
      return rows.length;
    } catch (e) {
      debugPrint('Error fetching critical task count: $e');
      return 0;
    }
  }

  Future<int> _fetchPendingStockTaskCount() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final dynamic rowsRaw = await Supabase.instance.client
          .from('someday_tasks')
          .select('id')
          .eq('user_id', userId)
          .eq('is_completed', false);
      final rows = rowsRaw is List ? rowsRaw : const <dynamic>[];
      return rows.length;
    } catch (e) {
      debugPrint('Error fetching pending stock task count: $e');
      return 0;
    }
  }

  Future<_HomeOpsSnapshot> _loadOpsSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingCriticalTaskCount = await _fetchPendingCriticalTaskCount();
    final pendingStockTaskCount = await _fetchPendingStockTaskCount();
    final abstinenceSnapshot = await AbstinenceGuardStore.loadSnapshot(
      prefs: prefs,
      now: _now(),
    );

    return _HomeOpsSnapshot(
      morningBriefingDone: prefs.getBool(_morningBriefingDoneKey) ?? false,
      balanceCheckDone: prefs.getBool(_balanceCheckDoneKey) ?? false,
      pendingCriticalTaskCount: pendingCriticalTaskCount,
      pendingStockTaskCount: pendingStockTaskCount,
      abstinenceFocusCount: abstinenceSnapshot.enabledCount,
      abstinenceSlipCount: abstinenceSnapshot.totalSlipCount,
      abstinenceTopLabels: abstinenceSnapshot.topEnabledLabels,
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

  String _resolveHomeModel(SharedPreferences prefs) {
    final candidates = <String?>[
      prefs.getString('gemini_model_home'),
      prefs.getString('gemini_model_emergency_meeting'),
      prefs.getString('gemini_model'),
    ];
    for (final candidate in candidates) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return 'gemini-1.5-flash';
  }

  Future<String?> _loadHomeApiKey(SharedPreferences prefs) async {
    final secureKey = await _secureStorage.read(key: 'gemini_api_key');
    if (secureKey != null && secureKey.trim().isNotEmpty) {
      return secureKey.trim();
    }
    final legacyKey = prefs.getString('gemini_api_key');
    if (legacyKey != null && legacyKey.trim().isNotEmpty) {
      return legacyKey.trim();
    }
    return null;
  }

  String? _normalizeAiNudge(String? rawText) {
    final text = rawText?.replaceAll('\n', ' ').trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    if (text.length <= 80) {
      return text;
    }
    return '${text.substring(0, 80)}...';
  }

  Future<String?> _loadAiNudgeIfNeeded(
    _HomeActionCommand command,
    _HomeOpsSnapshot snapshot,
  ) async {
    if (command.type == _HomeActionType.none) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _aiNudgeCacheKey(command.type);
    final cached = prefs.getString(cacheKey);
    if (cached != null && cached.trim().isNotEmpty) {
      return cached.trim();
    }

    try {
      final apiKey = await _loadHomeApiKey(prefs);
      if (apiKey == null) {
        return null;
      }

      final model = _resolveHomeModel(prefs);
      final aiService = AIService(null, apiKey);
      final prompt = '''
あなたはホーム画面の運用アシスタントです。
次アクションに対して、実行を後押しする短い補足を日本語で1文だけ返してください。
出力は1文のみ（句点あり、絵文字なし）。

action_title: ${command.title}
action_detail: ${command.detail}
pending_critical_tasks: ${snapshot.pendingCriticalTaskCount}
''';

      final generated = await aiService.generateContent(
        model: model,
        prompt: prompt,
      );
      final nudge = _normalizeAiNudge(generated);
      if (nudge == null) {
        return null;
      }

      await prefs.setString(cacheKey, nudge);
      return nudge;
    } catch (e) {
      debugPrint('Home AI nudge generation failed: $e');
      return null;
    }
  }

  _HomeActionCommand _resolveNextAction(_HomeOpsSnapshot snapshot) {
    final hour = _now().hour;
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

    if (hour >= 6 &&
        snapshot.pendingStockTaskCount > 0 &&
        _now().weekday == DateTime.saturday) {
      return _HomeActionCommand(
        type: _HomeActionType.stockReview,
        title: '週末ストックを見直す',
        detail: '土曜リマインド: 未完了ストックが${snapshot.pendingStockTaskCount}件あります。',
        icon: Icons.inventory_2,
        color: Colors.teal,
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

  Future<void> _openAbstinenceGuard(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AbstinenceGuardPage(nowProvider: widget.nowProvider),
      ),
    );
    if (mounted) {
      await _refreshKpis();
    }
  }

  Widget _buildNextActionBubble(
    BuildContext context,
    _HomeActionCommand command,
    _HomeOpsSnapshot snapshot, {
    String? aiNudge,
    bool isAiNudgeLoading = false,
  }) {
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
    } else if (command.type == _HomeActionType.stockReview) {
      buttonLabel = '週末ストックへ';
      onPressed = () {
        _nav(context, const StockTasksPage());
      };
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = Color.alphaBlend(
      command.color.withValues(alpha: isDark ? 0.2 : 0.12),
      isDark ? const Color(0xFF0F172A) : Colors.white,
    );
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor,
            Color.alphaBlend(
              Colors.white.withValues(alpha: isDark ? 0.02 : 0.55),
              baseColor,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: command.color.withValues(alpha: 0.65)),
        boxShadow: [
          BoxShadow(
            color: command.color.withValues(alpha: isDark ? 0.16 : 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.92),
              shape: BoxShape.circle,
              border: Border.all(color: command.color.withValues(alpha: 0.35)),
            ),
            child: Icon(command.icon, color: command.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '次に実施すべきアクション',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textColor.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  command.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'AI推奨: ${command.detail}',
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withValues(alpha: 0.88),
                  ),
                ),
                if (isAiNudgeLoading &&
                    command.type != _HomeActionType.none) ...[
                  const SizedBox(height: 4),
                  Text(
                    'AI補足を生成中...',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.72),
                    ),
                  ),
                ],
                if (aiNudge != null && aiNudge.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'AI補足: $aiNudge',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.9),
                    ),
                  ),
                ],
                if (snapshot.pendingCriticalTaskCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '未完了の必須タスク: ${snapshot.pendingCriticalTaskCount}件',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
                if (command.type == _HomeActionType.stockReview &&
                    snapshot.pendingStockTaskCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '未完了の週末ストック: ${snapshot.pendingStockTaskCount}件',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: command.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  onPressed: onPressed,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(buttonLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbstinenceGuardPanel(
    BuildContext context,
    _HomeOpsSnapshot snapshot,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeLabels = snapshot.abstinenceTopLabels;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF1F2937), Color(0xFF111827)]
              : const [Color(0xFFFFFBFB), Color(0xFFFFF3F2)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_moon, color: Colors.redAccent),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'やらないことガード',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              FilledButton.tonal(
                onPressed: () => _openAbstinenceGuard(context),
                child: const Text('設定'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '今日の害悪行動を先に禁止して、逸脱は回数で管理する。',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusPill(
                label: '禁止中',
                value: '${snapshot.abstinenceFocusCount}件',
                color: Colors.redAccent,
              ),
              _buildStatusPill(
                label: '逸脱',
                value: '${snapshot.abstinenceSlipCount}回',
                color: snapshot.abstinenceSlipCount > 0
                    ? Colors.orange
                    : Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            activeLabels.isEmpty
                ? 'まだ今日の禁止対象が固定されていません。酒・スマホ・動画などから先に封鎖してください。'
                : '今日の禁止対象: ${activeLabels.join(' / ')}'
                    '${snapshot.abstinenceFocusCount > activeLabels.length ? ' ほか' : ''}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
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
    final isWide = screenWidth >= 1200;
    final contentHorizontalPadding = isCompact ? 12.0 : (isWide ? 24.0 : 16.0);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B1220) : const Color(0xFFF3F7FF),
      appBar: AppBar(
        toolbarHeight: 74,
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('自分株式会社 経営コックピット'),
            // 時計部分を独立したウィジェットとして配置（パフォーマンス改善）
            _ClockWidget(),
          ],
        ),
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                  Colors.white.withValues(alpha: 0.08),
                  primaryColor,
                ),
                Color.alphaBlend(
                  Colors.black.withValues(alpha: 0.2),
                  primaryColor,
                ),
              ],
            ),
          ),
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
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [
                    Color(0xFF0B1220),
                    Color(0xFF111827),
                    Color(0xFF0F172A),
                  ]
                : const [
                    Color(0xFFF8FAFF),
                    Color(0xFFF1F5F9),
                    Color(0xFFE8EFF8),
                  ],
          ),
        ),
        child: RefreshIndicator(
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
              final highlightStock =
                  nextAction.type == _HomeActionType.stockReview;

              return FutureBuilder<String?>(
                future: _aiNudgeFuture,
                builder: (context, aiNudgeSnapshot) {
                  final aiNudge = aiNudgeSnapshot.data;
                  final isAiLoading =
                      aiNudgeSnapshot.connectionState == ConnectionState.waiting;

                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      contentHorizontalPadding,
                      16,
                      contentHorizontalPadding,
                      24,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1140),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildNextActionBubble(
                              context,
                              nextAction,
                              opsSnapshot,
                              aiNudge: aiNudge,
                              isAiNudgeLoading: isAiLoading,
                            ),
                            const SizedBox(height: 14),
                            _buildAbstinenceGuardPanel(context, opsSnapshot),
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
                              elevation: 6,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              color: Colors.transparent,
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF3F46CC),
                                      Color(0xFF4F46E5),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.indigo.withValues(alpha: 0.25),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
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
                                      builder: (context) =>
                                          const ElectionStrategyPage(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildSectionHeader(
                              'CSO OFFICE',
                              Icons.flag,
                              Colors.orange,
                            ),
                            _buildGridMenu(context, isCompact, [
                              _MenuData(
                                '禁欲ガード',
                                Icons.shield_moon,
                                Colors.redAccent,
                                () => _openAbstinenceGuard(context),
                                isHighlighted: opsSnapshot.abstinenceSlipCount > 0,
                                badgeLabel: opsSnapshot.abstinenceSlipCount > 0
                                    ? 'WARN'
                                    : null,
                              ),
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
                                '週末ストック / 思考ネタ',
                                Icons.check_circle_outline,
                                Colors.teal,
                                () => _nav(context, const StockTasksPage()),
                                isHighlighted: highlightStock,
                                badgeLabel: highlightStock ? 'SAT' : null,
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
                                () => _nav(
                                  context,
                                  const GeminiUniversityV2Page(),
                                ),
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
                },
              );
            },
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
      padding: const EdgeInsets.only(bottom: 12.0, left: 2, right: 2),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              color: color.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCeoCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1F2937) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor,
            Color.alphaBlend(
              Colors.redAccent.withValues(alpha: isDark ? 0.16 : 0.07),
              baseColor,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withValues(alpha: isDark ? 0.16 : 0.12),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        leading: const CircleAvatar(
          backgroundColor: Colors.redAccent,
          radius: 26,
          child: Icon(Icons.emergency, color: Colors.white, size: 28),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final accent = isHighlighted ? Colors.amber.shade700 : Colors.amber;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor,
            Color.alphaBlend(
              Colors.amber.withValues(alpha: isHighlighted ? 0.2 : 0.09),
              baseColor,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isHighlighted ? 0.18 : 0.1),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        leading: CircleAvatar(
          backgroundColor: accent,
          radius: 26,
          child: const Icon(Icons.wb_sunny, color: Colors.white, size: 28),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isCompact ? 1 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isCompact ? 3.2 : 2.7,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final cardColor = item.isHighlighted
            ? Color.alphaBlend(
                item.color.withValues(alpha: isDark ? 0.24 : 0.14),
                Theme.of(context).cardColor,
              )
            : Theme.of(context).cardColor;
        final borderColor = item.isHighlighted
            ? item.color.withValues(alpha: 0.65)
            : Theme.of(context).dividerColor.withValues(alpha: 0.25);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: item.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: item.color.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Icon(item.icon, color: item.color, size: 18),
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
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.2),
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
          ),
        );
      },
    );
  }

  // KPIサマリー
  Widget _buildKpiSummary(BuildContext context, bool isDark, bool isCompact) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isCompact ? 1 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: isCompact ? 130 : 150,
      ),
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
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
    final base = isDark ? const Color(0xFF111827) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            base,
            Color.alphaBlend(color.withValues(alpha: isDark ? 0.14 : 0.08), base),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
  stockReview,
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
  final int pendingStockTaskCount;
  final int abstinenceFocusCount;
  final int abstinenceSlipCount;
  final List<String> abstinenceTopLabels;

  const _HomeOpsSnapshot({
    this.morningBriefingDone = false,
    this.balanceCheckDone = false,
    this.pendingCriticalTaskCount = 0,
    this.pendingStockTaskCount = 0,
    this.abstinenceFocusCount = 0,
    this.abstinenceSlipCount = 0,
    this.abstinenceTopLabels = const [],
  });
}
