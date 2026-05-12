// lib/pages/admin/quota_dashboard_page.dart
// AI クォータ監視ダッシュボード
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuotaDashboardPage extends StatefulWidget {
  final SupabaseClient? supabaseClient;
  const QuotaDashboardPage({super.key, this.supabaseClient});

  @override
  State<QuotaDashboardPage> createState() => _QuotaDashboardPageState();
}

class _QuotaDashboardPageState extends State<QuotaDashboardPage> {
  late final SupabaseClient _supabase;
  List<Map<String, dynamic>> _latest = [];
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  bool _historyLoading = false;

  static const _bg = Color(0xFF0A0A0A);
  static const _card = Color(0xFF1A1A2E);
  static const _orange = Color(0xFFFF6B35);
  static const _alertRed = Color(0xFFE53935); // DESIGN.md red
  static const _okGreen = Color(0xFF4CAF50); // DESIGN.md green

  // ツールの表示名マッピング
  static const _toolNames = {
    'anthropic': 'Anthropic Claude',
    'openai': 'OpenAI GPT',
    'github_copilot': 'GitHub Copilot',
    'gemini': 'Google Gemini',
    'hedra': 'Hedra API',
  };

  // ツールごとの月次上限 (USD)
  static const _toolLimits = {
    'anthropic': 50.0,
    'openai': 20.0,
    'github_copilot': 10.0,
    'hedra': 0.0,
    'gemini': 0.0, // 無料枠
  };

  static const _toolIcons = {
    'anthropic': Icons.auto_awesome,
    'openai': Icons.psychology,
    'github_copilot': Icons.code,
    'gemini': Icons.auto_fix_high,
    'hedra': Icons.video_camera_front_outlined,
  };

  @override
  void initState() {
    super.initState();
    _supabase = widget.supabaseClient ?? Supabase.instance.client;
    _loadLatest();
  }

  Future<void> _loadLatest() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final res = await _supabase.functions.invoke(
        'admin-hub',
        body: {'action': 'quota.latest'},
      );
      final data = res.data as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        final rows = data['data'] as List<dynamic>? ?? [];
        setState(() {
          _latest = rows.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      debugPrint('quota.latest error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadHistory() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _historyLoading = true);
    try {
      final res = await _supabase.functions.invoke(
        'admin-hub',
        body: {'action': 'quota.list', 'days': 30},
      );
      final data = res.data as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        final rows = data['data'] as List<dynamic>? ?? [];
        setState(() {
          _history = rows.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      debugPrint('quota.list error: $e');
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  bool get _hasAlert => _latest.any((r) => r['alert'] == true);

  Map<String, dynamic>? _rowForTool(String tool) {
    try {
      return _latest.firstWhere((r) => r['tool'] == tool);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        title: const Text(
          'AI クォータ監視',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: '更新',
            onPressed: _loadLatest,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : RefreshIndicator(
              onRefresh: _loadLatest,
              color: _orange,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_hasAlert) _buildAlertBanner(),
                    if (_hasAlert) const SizedBox(height: 16),
                    _buildToolCards(),
                    const SizedBox(height: 16),
                    _buildHistorySection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAlertBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _alertRed.withAlpha(30),
        border: Border.all(color: _alertRed, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: _alertRed, size: 20),
              SizedBox(width: 8),
              Text(
                '⚠️ フォールバック推奨',
                style: TextStyle(
                  color: _alertRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Claude MAX レート制限到達。ファイル種別に応じて代替AIを使用してください:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          _buildFallbackTable(),
        ],
      ),
    );
  }

  Widget _buildFallbackTable() {
    const rows = [
      ['.dart', 'Gemini Code Assist (VS Code拡張)'],
      ['.py / .ts', 'CODEX CLI (OpenAI)'],
      ['.yml / .sql / .md', 'GitHub Copilot'],
    ];
    return Table(
      border: TableBorder.all(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(4),
      ),
      columnWidths: const {0: FixedColumnWidth(120), 1: FlexColumnWidth()},
      children: rows.map((r) {
        return TableRow(
          children: r.map((cell) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                cell,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildToolCards() {
    final tools = [
      'anthropic',
      'openai',
      'github_copilot',
      'gemini',
      'hedra',
    ];
    return Column(
      children: tools.map((tool) {
        final row = _rowForTool(tool);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildToolCard(tool, row),
        );
      }).toList(),
    );
  }

  Widget _buildToolCard(String tool, Map<String, dynamic>? row) {
    final isAlert = row?['alert'] == true;
    final statusColor = isAlert ? _alertRed : _okGreen;
    final displayName = _toolNames[tool] ?? tool;
    final icon = _toolIcons[tool] ?? Icons.smart_toy;

    final usageJson = row?['usage_json'] as Map<String, dynamic>? ?? {};
    final costUsd = (usageJson['cost_usd'] as num?)?.toDouble() ?? 0.0;
    final tokens = (usageJson['tokens'] as num?)?.toInt();
    final remainingCredits = (usageJson['remaining'] as num?)?.toInt();
    final usedCredits = (usageJson['used'] as num?)?.toInt();
    final expiringCredits = (usageJson['expiring'] as num?)?.toInt();
    final creditThreshold = (usageJson['threshold'] as num?)?.toInt();
    final severity = usageJson['severity']?.toString();
    final errorMessage = usageJson['error']?.toString();
    final checkedAt = row?['checked_at'] as String?;
    final limit = _toolLimits[tool] ?? 0.0;
    final progress = (limit > 0) ? (costUsd / limit).clamp(0.0, 1.0) : 0.0;

    return Card(
      color: _card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isAlert ? _alertRed.withAlpha(128) : Colors.white12,
          width: isAlert ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _orange, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withAlpha(128)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAlert
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        color: statusColor,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAlert ? 'アラート' : '正常',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (row == null) ...[
              const SizedBox(height: 12),
              const Text(
                'データなし',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (remainingCredits != null) ...[
                    Text(
                      '$remainingCredits',
                      style: TextStyle(
                        color: isAlert ? _alertRed : Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    const Text(
                      ' credits remaining',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ] else if (costUsd > 0 || limit > 0) ...[
                    Text(
                      '\$${costUsd.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: isAlert ? _alertRed : Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    if (limit > 0) ...[
                      Text(
                        ' / \$${limit.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(width: 16),
                  ],
                  if (tokens != null)
                    Text(
                      '${_formatTokens(tokens)} tokens',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                ],
              ),
              if (usedCredits != null || expiringCredits != null) ...[
                const SizedBox(height: 6),
                Text(
                  [
                    if (usedCredits != null) 'used: $usedCredits',
                    if (expiringCredits != null) 'expiring: $expiringCredits',
                    if (creditThreshold != null)
                      'alert threshold: $creditThreshold',
                    if (severity != null) 'severity: $severity',
                  ].join(' / '),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
              if (errorMessage != null && errorMessage.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  errorMessage,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _alertRed,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
              if (limit > 0) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress > 0.8 ? _alertRed : _orange,
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}% 使用',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
              if (checkedAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  '最終確認: $checkedAt',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Card(
      color: _card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: const Icon(Icons.history, color: Colors.white54),
        title: const Text(
          '使用履歴 (30日間)',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        iconColor: Colors.white54,
        collapsedIconColor: Colors.white38,
        onExpansionChanged: (expanded) {
          if (expanded && _history.isEmpty) _loadHistory();
        },
        children: [
          if (_historyLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: _orange),
            )
          else if (_history.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'データなし',
                style: TextStyle(
                  color: Colors.white38,
                  height: 1.5,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildHistoryTable(),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryTable() {
    return Column(
      children: [
        Table(
          border: TableBorder.all(color: Colors.white12),
          columnWidths: const {
            0: FlexColumnWidth(1.5),
            1: FlexColumnWidth(1.0),
            2: FlexColumnWidth(1.0),
            3: FlexColumnWidth(0.8),
          },
          children: [
            TableRow(
              decoration:
                  const BoxDecoration(color: Color(0xFF1A1A1A)), // surface1
              children: ['ツール', '日付', '金額', 'アラート'].map((h) {
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Text(
                    h,
                    style: const TextStyle(
                      color: _orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                );
              }).toList(),
            ),
            ..._history.take(50).map((row) {
              final tool = row['tool'] as String? ?? '';
              final date =
                  (row['checked_at'] as String? ?? '').substring(0, 10);
              final usage = row['usage_json'] as Map<String, dynamic>? ?? {};
              final isAlert = row['alert'] == true;
              return TableRow(
                children: [
                  _tableCell(_toolNames[tool] ?? tool),
                  _tableCell(date),
                  _tableCell(_historyMetric(usage)),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: Icon(
                      isAlert ? Icons.warning_amber : Icons.check,
                      color: isAlert ? _alertRed : _okGreen,
                      size: 14,
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _tableCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          height: 1.5,
        ),
      ),
    );
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000000) return '${(tokens / 1000000).toStringAsFixed(1)}M';
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(0)}K';
    return '$tokens';
  }

  String _historyMetric(Map<String, dynamic> usage) {
    final remainingCredits = (usage['remaining'] as num?)?.toInt();
    if (remainingCredits != null) return '$remainingCredits cr';
    final cost = (usage['cost_usd'] as num?)?.toDouble() ??
        (usage['cost_usd_est'] as num?)?.toDouble();
    if (cost != null) return '\$${cost.toStringAsFixed(2)}';
    final tokens = (usage['tokens'] as num?)?.toInt();
    if (tokens != null) return '${_formatTokens(tokens)} tok';
    final status = usage['status']?.toString();
    if (status != null && status.isNotEmpty) return status;
    return '-';
  }
}
