import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// AI Observability — プロバイダーヘルス + ヒートマップ + セッショントレース
///
/// NotebookLM "TraceHawk vs Datadog: AI Agent Observability in 2026" (f56cc07c)
/// の知見を統合 (Win版#131 part 4)。
///
/// バックエンド:
///   - SQL views: provider_health_view / provider_heatmap_view / session_trace_view
///   - EF actions: ai-hub:observability.{provider_health,heatmap,sessions,session_steps}
///
/// 既存資産との関係:
///   - ai_hub_chat_logs (PS版#117) を latency_ms/trace_id/session_id で拡張
///   - Rule 23 #3 trace_id+5秒検出 → 本ページで実データ可視化
///   - Rule 23 #4 cost circuit breaker → estimated_cost_usd を表示
class AiObservabilityPage extends StatefulWidget {
  const AiObservabilityPage({super.key});

  @override
  State<AiObservabilityPage> createState() => _AiObservabilityPageState();
}

class _AiObservabilityPageState extends State<AiObservabilityPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs =>
      const <String>['health', 'heatmap', 'sessions'];

  @override
  TabController get tabUrlController => _tab;

  late TabController _tab;
  final _supabase = Supabase.instance.client;

  bool _loadingHealth = true;
  bool _loadingSessions = true;
  List<Map<String, dynamic>> _providers = [];
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _loadHealth();
    _loadSessions();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadHealth() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _loadingHealth = false);
      return;
    }
    setState(() => _loadingHealth = true);
    try {
      final resp = await _supabase.functions.invoke(
        'ai-hub',
        body: {'action': 'observability.provider_health'},
      );
      final data = resp.data as Map<String, dynamic>?;
      final list =
          (data?['providers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) setState(() => _providers = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('プロバイダーヘルス取得失敗: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingHealth = false);
    }
  }

  Future<void> _loadSessions() async {
    setState(() => _loadingSessions = true);
    try {
      final resp = await _supabase.functions.invoke(
        'ai-hub',
        body: {'action': 'observability.sessions', 'limit': 50},
      );
      final data = resp.data as Map<String, dynamic>?;
      final list =
          (data?['sessions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) setState(() => _sessions = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('セッション取得失敗: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingSessions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('AI Observability'),
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFFF97316),
          labelColor: const Color(0xFFF97316),
          unselectedLabelColor: const Color(0xFF94A3B8),
          tabs: const [
            Tab(icon: Icon(Icons.health_and_safety), text: 'ヘルス'),
            Tab(icon: Icon(Icons.grid_on), text: 'ヒートマップ'),
            Tab(icon: Icon(Icons.timeline), text: 'セッション'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadHealth();
              _loadSessions();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildHealth(),
          _HeatmapTab(supabase: _supabase),
          _buildSessions(),
        ],
      ),
    );
  }

  Widget _buildHealth() {
    if (_loadingHealth) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFF97316)),
      );
    }
    if (_providers.isEmpty) {
      return _empty(
        '過去24時間の AI 呼び出しログがありません',
        '/ai-assistant や /ai-chat を使うと記録が始まります。',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadHealth,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _providers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _providerHealthCard(_providers[i]),
      ),
    );
  }

  Widget _providerHealthCard(Map<String, dynamic> p) {
    final provider = p['provider'] as String? ?? '?';
    final total = (p['total_requests'] as num?)?.toInt() ?? 0;
    final errors = (p['error_count'] as num?)?.toInt() ?? 0;
    final successRate = (p['success_rate_pct'] as num?)?.toDouble() ?? 0.0;
    final p50 = (p['p50_latency_ms'] as num?)?.toDouble();
    final p95 = (p['p95_latency_ms'] as num?)?.toDouble();
    final isFlaky = p['is_flaky_now'] == true;
    final color = isFlaky
        ? const Color(0xFFEF4444)
        : successRate >= 99
            ? const Color(0xFF22C55E)
            : successRate >= 95
                ? const Color(0xFFF97316)
                : const Color(0xFFEAB308);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFlaky ? color : const Color(0xFF1F1F1F),
          width: isFlaky ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  provider,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ),
              if (isFlaky)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '⚠ flaky (1h)',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${successRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _stat('合計', total.toString(), const Color(0xFFCBD5E1)),
              const SizedBox(width: 12),
              _stat(
                'エラー',
                errors.toString(),
                errors > 0 ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 12),
              _stat(
                'p50',
                p50 == null ? '—' : '${p50.toInt()}ms',
                const Color(0xFFF97316),
              ),
              const SizedBox(width: 12),
              _stat(
                'p95',
                p95 == null ? '—' : '${p95.toInt()}ms',
                const Color(0xFFA855F7),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessions() {
    if (_loadingSessions) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFF97316)),
      );
    }
    if (_sessions.isEmpty) {
      return _empty('セッションログがありません', 'AI 機能を session_id 付きで呼び出すと記録されます。');
    }
    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _sessions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _sessionCard(_sessions[i]),
      ),
    );
  }

  Widget _sessionCard(Map<String, dynamic> s) {
    final sessionId = s['session_id'] as String? ?? '';
    final stepCount = (s['step_count'] as num?)?.toInt() ?? 0;
    final errorSteps = (s['error_step_count'] as num?)?.toInt() ?? 0;
    final totalLatency = (s['total_latency_ms'] as num?)?.toInt() ?? 0;
    final cost = (s['total_cost_usd'] as num?)?.toDouble() ?? 0.0;
    final providers =
        (s['provider_chain'] as List?)?.cast<String>().toSet().join(', ') ??
            '?';
    final hasError = errorSteps > 0;
    final color = hasError ? const Color(0xFFEF4444) : const Color(0xFF6366F1);
    return InkWell(
      onTap: () => _showSessionSteps(sessionId),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasError ? color : const Color(0xFF1F1F1F),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sessionId.length > 28
                        ? '${sessionId.substring(0, 28)}...'
                        : sessionId,
                    style: const TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 11,
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
                  ),
                ),
                if (hasError)
                  Text(
                    '$errorSteps err',
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              providers,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 12,
                height: 1.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '$stepCount ステップ',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${totalLatency}ms',
                  style: const TextStyle(
                    color: Color(0xFFF97316),
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '\$${cost.toStringAsFixed(5)}',
                  style: const TextStyle(
                    color: Color(0xFFA855F7),
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSessionSteps(String sessionId) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SessionStepsSheet(sessionId: sessionId),
    );
  }

  Widget _empty(String title, String hint) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.insights, color: Color(0xFF6366F1), size: 56),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 14,
                height: 1.7,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                height: 1.7,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// ヒートマップタブ (時間帯 × プロバイダー)
class _HeatmapTab extends StatefulWidget {
  const _HeatmapTab({required this.supabase});
  final SupabaseClient supabase;

  @override
  State<_HeatmapTab> createState() => _HeatmapTabState();
}

class _HeatmapTabState extends State<_HeatmapTab> {
  bool _loading = true;
  Map<String, Map<int, int>> _matrix = {}; // provider -> {hour_of_day -> count}
  int _maxValue = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await widget.supabase.functions.invoke(
        'ai-hub',
        body: {'action': 'observability.heatmap'},
      );
      final data = resp.data as Map<String, dynamic>?;
      final cells =
          (data?['cells'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final m = <String, Map<int, int>>{};
      var maxV = 0;
      for (final c in cells) {
        final p = c['provider'] as String? ?? '?';
        final h = (c['hour_of_day'] as num?)?.toInt() ?? 0;
        final v = (c['request_count'] as num?)?.toInt() ?? 0;
        m.putIfAbsent(p, () => {});
        m[p]![h] = (m[p]![h] ?? 0) + v;
        if ((m[p]![h] ?? 0) > maxV) maxV = m[p]![h]!;
      }
      if (mounted) {
        setState(() {
          _matrix = m;
          _maxValue = maxV;
        });
      }
    } catch (_) {
      // silent
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFF97316)),
      );
    }
    if (_matrix.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'ヒートマップに表示できるデータがありません。\nAI 機能を呼び出すと過去 7 日分が集計されます。',
            style: TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 13,
              height: 1.7,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final providers = _matrix.keys.toList()..sort();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '過去 7 日 × 24 時間帯',
              style: TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 13,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 時間軸ヘッダー
                  Row(
                    children: [
                      const SizedBox(width: 96),
                      for (var h = 0; h < 24; h++)
                        SizedBox(
                          width: 22,
                          child: Text(
                            h.toString().padLeft(2, '0'),
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 9,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (final p in providers) _heatmapRow(p, _matrix[p]!),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  '密度: ',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
                for (var i = 0; i < 5; i++)
                  Container(
                    width: 18,
                    height: 14,
                    margin: const EdgeInsets.only(right: 2),
                    color: _color((i + 1) / 5.0),
                  ),
                const SizedBox(width: 8),
                Text(
                  '0 → $_maxValue req',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _heatmapRow(String provider, Map<int, int> hours) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              provider,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 11,
                height: 1.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          for (var h = 0; h < 24; h++)
            Container(
              width: 22,
              height: 18,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: _color(
                  _maxValue == 0 ? 0 : (hours[h] ?? 0) / _maxValue,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
              child: (hours[h] ?? 0) == 0
                  ? null
                  : Center(
                      child: Text(
                        '${hours[h]}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  Color _color(double t) {
    if (t <= 0) return const Color(0xFF1A1A1A);
    final clamped = t.clamp(0.0, 1.0);
    return Color.lerp(
      const Color(0xFF1F2937),
      const Color(0xFFF97316),
      clamped,
    )!;
  }
}

/// セッション内ステップ詳細 (Modal Bottom Sheet)
class _SessionStepsSheet extends StatefulWidget {
  const _SessionStepsSheet({required this.sessionId});
  final String sessionId;

  @override
  State<_SessionStepsSheet> createState() => _SessionStepsSheetState();
}

class _SessionStepsSheetState extends State<_SessionStepsSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _steps = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final resp = await Supabase.instance.client.functions.invoke(
        'ai-hub',
        body: {
          'action': 'observability.session_steps',
          'session_id': widget.sessionId,
        },
      );
      final data = resp.data as Map<String, dynamic>?;
      final list =
          (data?['steps'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) setState(() => _steps = list);
    } catch (_) {
      // silent
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.7;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SizedBox(
        height: h,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              alignment: Alignment.center,
              margin: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF6B7280),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const Text(
              'セッションリプレイ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.sessionId,
              style: const TextStyle(
                color: Color(0xFF6366F1),
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFF97316),
                      ),
                    )
                  : _steps.isEmpty
                      ? const Center(
                          child: Text(
                            'ステップなし',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              height: 1.5,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _steps.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (_, i) => _stepCard(i + 1, _steps[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepCard(int idx, Map<String, dynamic> s) {
    final ok = s['success'] == true;
    final color = ok ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final provider = s['provider'] as String? ?? '?';
    final action = s['action'] as String? ?? '?';
    final latency = (s['latency_ms'] as num?)?.toInt() ?? 0;
    final err = s['error_message'] as String?;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  '$idx',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$provider · $action',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ),
              Text(
                '${latency}ms',
                style: const TextStyle(
                  color: Color(0xFFF97316),
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ],
          ),
          if (err != null && err.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              err,
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 11,
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
