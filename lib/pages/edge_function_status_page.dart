import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Edge Function の UI 実装状況を一覧表示するページ
class EdgeFunctionStatusPage extends StatefulWidget {
  const EdgeFunctionStatusPage({super.key});

  @override
  State<EdgeFunctionStatusPage> createState() => _EdgeFunctionStatusPageState();
}

class _EdgeFunctionStatusPageState extends State<EdgeFunctionStatusPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = false;
  final Map<String, Map<String, dynamic>> _testResults = {};
  final Set<String> _expandedNavigation = {};

  // 全 Edge Functions の定義 (name, description, hasUi, uiPath, uiLabel, uiNavigation)
  static const List<Map<String, dynamic>> _functions = [
    {
      'name': 'get-home-dashboard',
      'description': 'ホーム画面の統合データを返す',
      'hasUi': true,
      'uiPath': '/home',
      'uiLabel': 'ホーム画面',
      'uiNavigation': 'ホーム → KPIサマリー (CMOオフィス)',
      'category': 'core',
    },
    {
      'name': 'ai-assistant',
      'description': 'AI アシスタント（汎用）',
      'hasUi': true,
      'uiPath': '/agents',
      'uiLabel': 'AI 組織 OS / 各 AI ページ',
      'uiNavigation': 'ホーム → AI秘書 / ノート編集 → AIアシスタントメニュー',
      'category': 'ai',
    },
    {
      'name': 'growth-hub',
      'description': '獲得レポート / grコマンドセンター / 紹介 (hub)',
      'hasUi': true,
      'uiPath': '/growth-mission',
      'uiLabel': '成長ミッション',
      'uiNavigation': '管理者ダッシュボード → グロース各機能',
      'category': 'growth',
    },
    {
      'name': 'growth-weekly-digest',
      'description': '週次グロース指標',
      'hasUi': true,
      'uiPath': '/growth-mission',
      'uiLabel': '成長ミッション',
      'uiNavigation': '管理者ダッシュボード → 週次ダイジェスト',
      'category': 'growth',
    },
    // ─── 現行 deploy 済み EF (16本) ───
    // 旧 28 EF は core-hub / growth-hub 等に統合済 (2026-04 macro/mega-hub体制)
    {
      'name': 'core-hub',
      'description':
          'コア機能統合 (achievements/notification/personal-dashboard ほか15機能)',
      'hasUi': true,
      'uiPath': '/home',
      'uiLabel': 'ホーム',
      'uiNavigation':
          'ホーム → 各種カード (旧 development-achievements / system-status 等)',
      'category': 'core',
    },
    {
      'name': 'ai-hub',
      'description':
          'AI 機能統合 (provider.chat / quiz / fsrs / voice 等30+ action)',
      'hasUi': true,
      'uiPath': '/gemini-university',
      'uiLabel': 'AI大学',
      'uiNavigation': 'AI大学 → クイズ・音声・provider.chat',
      'category': 'ai',
    },
    {
      'name': 'admin-hub',
      'description': '管理者機能統合 (quota / users / support tickets 等)',
      'hasUi': true,
      'uiPath': '/quota-dashboard',
      'uiLabel': 'クォータダッシュボード',
      'uiNavigation': '管理者 → クォータ / サポート / フィードバック',
      'category': 'admin',
    },
    {
      'name': 'app-hub',
      'description': 'アプリ機能統合 (notes / bookmarks / calendar 等)',
      'hasUi': true,
      'uiPath': '/home',
      'uiLabel': 'ホーム機能群',
      'uiNavigation': 'ホーム → ノート / ブックマーク / カレンダー',
      'category': 'core',
    },
    {
      'name': 'schedule-hub',
      'description': 'スケジュール機能統合 (daily-digest / health-check / x-update 等)',
      'hasUi': false,
      'uiPath': '',
      'uiLabel': 'バッチ専用',
      'uiNavigation': 'GitHub Actions cron で起動',
      'category': 'schedule',
    },
    {
      'name': 'tools-hub',
      'description': 'ツール機能統合 (horseracing / 各種ユーティリティ)',
      'hasUi': true,
      'uiPath': '/horse-racing',
      'uiLabel': '競馬AI予想',
      'uiNavigation': 'ホーム → 競馬AI予想',
      'category': 'data',
    },
    {
      'name': 'media-hub',
      'description': 'メディア機能統合 (画像/動画/音声 生成・処理)',
      'hasUi': false,
      'uiPath': '',
      'uiLabel': '内部利用',
      'uiNavigation': '各ページから利用',
      'category': 'data',
    },
    {
      'name': 'enterprise-hub',
      'description': 'エンタープライズ機能統合',
      'hasUi': false,
      'uiPath': '',
      'uiLabel': '内部利用',
      'uiNavigation': '管理者ダッシュボード等から利用',
      'category': 'admin',
    },
    {
      'name': 'social-commerce-hub',
      'description': 'ソーシャル+EC機能統合',
      'hasUi': false,
      'uiPath': '',
      'uiLabel': '内部利用',
      'uiNavigation': 'SNS関連ページから利用',
      'category': 'social',
    },
    {
      'name': 'lifestyle-hub',
      'description': 'ライフスタイル機能統合 (realestate 等5アクション)',
      'hasUi': false,
      'uiPath': '',
      'uiLabel': '内部利用',
      'uiNavigation': '関連ページから利用',
      'category': 'data',
    },
    {
      'name': 'guitar-recording-studio',
      'description': 'ギター録音スタジオ (専用)',
      'hasUi': true,
      'uiPath': '/guitar-recording-studio',
      'uiLabel': 'ギター録音',
      'uiNavigation': 'ホーム → ギター録音スタジオ',
      'category': 'data',
    },
    {
      'name': 'local-election-intelligence',
      'description': '地方選挙インテリジェンス (専用)',
      'hasUi': true,
      'uiPath': '/election-victory',
      'uiLabel': '地方選 戦略',
      'uiNavigation': 'ホーム → 地方選 戦略ページ',
      'category': 'data',
    },
  ];

  static const Map<String, String> _categoryLabels = {
    'core': '🏗 コア',
    'ai': '🤖 AI',
    'growth': '📈 グロース',
    'schedule': '⏰ Schedule',
    'social': '📣 SNS',
    'notification': '🔔 通知',
    'admin': '🔑 管理',
    'data': '💾 データ',
  };

  static const Map<String, Color> _categoryColors = {
    'core': Color(0xFF6366F1),
    'ai': Color(0xFF8B5CF6),
    'growth': Color(0xFF10B981),
    'schedule': Color(0xFFF59E0B),
    'social': Color(0xFF3B82F6),
    'notification': Color(0xFFEF4444),
    'admin': Color(0xFF64748B),
    'data': Color(0xFF06B6D4),
  };

  /// EF の種類に応じて呼び出し方法を変える:
  /// - `*-hub`: action 指定が必要なため POST + ダミー body で応答確認
  /// - `ai-assistant`: POST で action=get_models を送って到達確認
  /// - その他: GET (旧 standalone EF 互換)
  ///
  /// 到達できれば (2xx / 4xx 含む) 「生存」と判定する。
  /// CORS / network error / 5xx のみ「接続失敗」扱い。
  Future<void> _testFunction(String name) async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final bool isHub = name.endsWith('-hub');
      final bool isAiAssistant = name == 'ai-assistant';
      final result = await _supabase.functions.invoke(
        name,
        method: (isHub || isAiAssistant) ? HttpMethod.post : HttpMethod.get,
        body: isHub
            ? {'action': 'health.ping'}
            : isAiAssistant
                ? {'action': 'get_models'}
                : null,
      );
      final status = result.status;
      // 到達していれば ok (200-499 = EF が応答, 5xx = server error = 接続失敗)
      setState(() {
        _testResults[name] = {
          'status': status,
          'ok': status >= 200 && status < 500,
        };
      });
    } catch (e) {
      // CORS / network / unreachable
      setState(() {
        _testResults[name] = {'status': 0, 'ok': false};
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _withUi => _functions.where((f) => f['hasUi'] as bool).length;
  int get _withoutUi => _functions.where((f) => !(f['hasUi'] as bool)).length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    // Group by category
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final f in _functions) {
      final cat = f['category'] as String;
      grouped.putIfAbsent(cat, () => []).add(f);
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Edge Functions 実装状況'),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Summary bar
          Container(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _summaryChip(
                  '総数',
                  '${_functions.length}',
                  const Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 8),
                _summaryChip('UI あり', '$_withUi', const Color(0xFF10B981)),
                const SizedBox(width: 8),
                _summaryChip('UI なし', '$_withoutUi', const Color(0xFFEF4444)),
                const Spacer(),
                Text(
                  '${(_withUi / _functions.length * 100).toStringAsFixed(0)}% 連携済',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF10B981),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          // Progress bar
          LinearProgressIndicator(
            value: _withUi / _functions.length,
            backgroundColor: const Color(0xFFEF4444).withAlpha(30),
            valueColor: const AlwaysStoppedAnimation<Color>(
              Color(0xFF10B981),
            ),
            minHeight: 4,
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: grouped.entries.map((entry) {
                final cat = entry.key;
                final fns = entry.value;
                final color = _categoryColors[cat] ?? const Color(0xFF6366F1);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _categoryLabels[cat] ?? cat,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${fns.length}件',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...fns.map((f) => _buildFunctionCard(f, isDark, color)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.5,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionCard(
    Map<String, dynamic> fn,
    bool isDark,
    Color catColor,
  ) {
    final name = fn['name'] as String;
    final description = fn['description'] as String;
    final hasUi = fn['hasUi'] as bool;
    final uiLabel = fn['uiLabel'] as String?;
    final uiPath = fn['uiPath'] as String?;
    final uiNavigation = fn['uiNavigation'] as String?;
    final testResult = _testResults[name];
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final navExpanded = _expandedNavigation.contains(name);

    return Card(
      color: cardColor,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: hasUi
              ? const Color(0xFF10B981).withAlpha(40)
              : const Color(0xFFEF4444).withAlpha(40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  hasUi ? Icons.check_circle : Icons.cancel,
                  size: 18,
                  color:
                      hasUi ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark ? Colors.white : const Color(0xFF1E293B),
                          fontFamily: 'monospace',
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                      if (uiLabel != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              hasUi ? Icons.link : Icons.link_off,
                              size: 12,
                              color: hasUi
                                  ? const Color(0xFF6366F1)
                                  : const Color(0xFF9CA3AF),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                uiLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: hasUi
                                      ? const Color(0xFF6366F1)
                                      : const Color(0xFF9CA3AF),
                                  height: 1.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (testResult != null) ...[
                        const SizedBox(height: 4),
                        Builder(
                          builder: (_) {
                            final ok = testResult['ok'] ?? false;
                            final status = testResult['status'] ?? 0;
                            final color = ok
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: color.withAlpha(20),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                ok ? 'HTTP $status OK' : 'HTTP $status NG',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: color,
                                  height: 1.5,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (uiNavigation != null)
                      Tooltip(
                        message: 'UIでの操作方法を表示',
                        child: IconButton(
                          onPressed: () => setState(() {
                            if (navExpanded) {
                              _expandedNavigation.remove(name);
                            } else {
                              _expandedNavigation.add(name);
                            }
                          }),
                          icon: Icon(
                            navExpanded
                                ? Icons.touch_app
                                : Icons.touch_app_outlined,
                            size: 18,
                            color: navExpanded
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF9CA3AF),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                        ),
                      ),
                    if (uiPath != null && !hasUi)
                      TextButton(
                        onPressed: () {
                          if (uiPath.startsWith('/')) {
                            Navigator.pushNamed(context, uiPath);
                          }
                        },
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 28),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text(
                          '実装へ',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ),
                    IconButton(
                      onPressed: _loading ? null : () => _testFunction(name),
                      icon: const Icon(Icons.play_circle_outline, size: 18),
                      tooltip: 'テスト呼び出し',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (navExpanded && uiNavigation != null) ...[
            const Divider(height: 1, indent: 10, endIndent: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.touch_app,
                    size: 14,
                    color: Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'UIでの操作方法',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFFB45309),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withAlpha(15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withAlpha(40),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.navigation,
                                size: 12,
                                color: Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  uiNavigation,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1E293B),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
