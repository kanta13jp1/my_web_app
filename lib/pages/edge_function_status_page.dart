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
      'name': 'development-achievements',
      'description': '開発実績一覧を返す (LP 用)',
      'hasUi': true,
      'uiPath': '/',
      'uiLabel': 'ランディングページ',
      'uiNavigation': 'ホーム → 開発実績カード',
      'category': 'core',
    },
    {
      'name': 'get-growth-roadmap-progress',
      'description': '競合21社 vs 開発進捗バーデータ',
      'hasUi': true,
      'uiPath': '/home',
      'uiLabel': 'ホーム: GrowthRoadmapProgressCard',
      'uiNavigation': 'ホーム → 進捗バー (GrowthRoadmapProgressCard)',
      'category': 'growth',
    },
    {
      'name': 'get-competitor-features',
      'description': '競合14社の機能比較データ',
      'hasUi': true,
      'uiPath': '/home',
      'uiLabel': 'ホーム: CompetitorFeatureComparisonCard',
      'uiNavigation': 'ホーム → 競合機能比較カード',
      'category': 'growth',
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
      'name': 'ai-search',
      'description': 'AI による全文検索',
      'hasUi': true,
      'uiPath': '/home',
      'uiLabel': 'ノート検索',
      'uiNavigation': 'ホーム → AI ノート検索 (AI ノート検索メニュー)',
      'category': 'ai',
    },
    {
      'name': 'ai-suggest-tags',
      'description': 'AI タグ自動提案',
      'hasUi': true,
      'uiPath': '/note-editor',
      'uiLabel': 'ノートエディタ',
      'uiNavigation': 'ノート編集 → タグ提案ボタン',
      'category': 'ai',
    },
    {
      'name': 'daily-judgment',
      'description': '毎晩実行: アウトプットなしユーザーのストリークリセット・ペナルティ',
      'hasUi': false,
      'uiPath': '/admin',
      'uiLabel': '管理者ダッシュボード (手動実行)',
      'uiNavigation': null,
      'category': 'schedule',
    },
    {
      'name': 'schedule-daily-digest',
      'description': 'Claude Schedule 用: 日次メトリクス API',
      'hasUi': true,
      'uiPath': '/admin',
      'uiLabel': '管理者ダッシュボード',
      'uiNavigation': null,
      'category': 'schedule',
    },
    {
      'name': 'get-support-tickets',
      'description': 'Claude Schedule 用: 未返信チケット + FAQ',
      'hasUi': true,
      'uiPath': '/admin',
      'uiLabel': '管理者ダッシュボード',
      'uiNavigation': '管理者ダッシュボード → サポートチケット',
      'category': 'schedule',
    },
    {
      'name': 'reply-support-request',
      'description': 'CS チケット返信・エスカレーション',
      'hasUi': true,
      'uiPath': '/admin',
      'uiLabel': '管理者ダッシュボード',
      'uiNavigation': null,
      'category': 'schedule',
    },
    {
      'name': 'post-x-update',
      'description': 'X (Twitter) 自動投稿 @kanta13jp1',
      'hasUi': true,
      'uiPath': '/admin',
      'uiLabel': '管理者ダッシュボード > X投稿',
      'uiNavigation': null,
      'category': 'social',
    },
    {
      'name': 'growth-share-signal',
      'description': 'シェアイベント記録',
      'hasUi': true,
      'uiPath': '/public-memos',
      'uiLabel': '公開メモ シェアボタン',
      'uiNavigation': 'ノート共有時に自動呼び出し',
      'category': 'growth',
    },
    {
      'name': 'growth-referral',
      'description': '紹介コード処理・報酬付与',
      'hasUi': true,
      'uiPath': '/referral',
      'uiLabel': '紹介プログラム',
      'uiNavigation': '紹介プログラムページ',
      'category': 'growth',
    },
    {
      'name': 'growth-acquisition-signal',
      'description': 'ユーザー獲得イベント記録',
      'hasUi': true,
      'uiPath': '/',
      'uiLabel': 'ランディングページ',
      'uiNavigation': '自動: 紹介・シェア時に呼び出し',
      'category': 'growth',
    },
    {
      'name': 'growth-acquisition-report',
      'description': '獲得レポート生成',
      'hasUi': true,
      'uiPath': '/growth-mission',
      'uiLabel': '成長ミッション',
      'uiNavigation': '管理者ダッシュボード → 成長レポート',
      'category': 'growth',
    },
    {
      'name': 'growth-command-center',
      'description': 'グロース指令センター',
      'hasUi': true,
      'uiPath': '/growth-mission',
      'uiLabel': '成長ミッション',
      'uiNavigation': '管理者ダッシュボード → グロースコマンドセンター',
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
    {
      'name': 'growth-import-preview',
      'description': 'インポートプレビュー',
      'hasUi': true,
      'uiPath': '/import',
      'uiLabel': 'インポートページ',
      'uiNavigation': 'インポートページ → データインポートプレビュー',
      'category': 'data',
    },
    {
      'name': 'growth-import-commit',
      'description': 'インポート実行',
      'hasUi': true,
      'uiPath': '/import',
      'uiLabel': 'インポートページ',
      'uiNavigation': 'インポートページ → データインポート確定',
      'category': 'data',
    },
    {
      'name': 'notify-feature-request',
      'description': '機能リクエスト更新通知メール',
      'hasUi': true,
      'uiPath': '/feature-requests',
      'uiLabel': '機能リクエスト',
      'uiNavigation': null,
      'category': 'notification',
    },
    {
      'name': 'send-waitlist-notification',
      'description': 'ウェイトリスト通知メール',
      'hasUi': true,
      'uiPath': '/admin',
      'uiLabel': '管理者ダッシュボード',
      'uiNavigation': null,
      'category': 'notification',
    },
    {
      'name': 'analyze-reality',
      'description': 'リアリティチェックの AI 分析 (Gemini)',
      'hasUi': false,
      'uiPath': '/reality-check',
      'uiLabel': 'リアリティチェック (未連携)',
      'uiNavigation': '現実チェックページ (現実分析ボタン)',
      'category': 'ai',
    },
    {
      'name': 'generate-daily-challenges',
      'description': '毎日のチャレンジ生成',
      'hasUi': true,
      'uiPath': '/home',
      'uiLabel': 'ホーム: DailyChallengeCard',
      'uiNavigation': 'ホーム → デイリーチャレンジカード',
      'category': 'ai',
    },
    {
      'name': 'generate-quote-image',
      'description': '名言画像生成',
      'hasUi': true,
      'uiPath': '/home',
      'uiLabel': 'ホーム: DailyMotivationCard',
      'uiNavigation': null,
      'category': 'ai',
    },
    {
      'name': 'share-quote',
      'description': '名言シェア URL 生成',
      'hasUi': true,
      'uiPath': '/home',
      'uiLabel': 'ホーム: DailyMotivationCard',
      'uiNavigation': null,
      'category': 'social',
    },
    {
      'name': 'get-admin-users',
      'description': '管理者用ユーザー一覧',
      'hasUi': true,
      'uiPath': '/admin',
      'uiLabel': '管理者ダッシュボード',
      'uiNavigation': '管理者ダッシュボード → ユーザー管理',
      'category': 'admin',
    },
    {
      'name': 'health-check',
      'description': 'DB・テーブル・レスポンスタイム確認',
      'hasUi': true,
      'uiPath': '/admin',
      'uiLabel': '管理者ダッシュボード: ScheduleTaskMonitorCard',
      'uiNavigation': null,
      'category': 'admin',
    },
    {
      'name': 'check-competitor-updates',
      'description': '競合14社 Web 可用性チェック',
      'hasUi': false,
      'uiPath': '/admin',
      'uiLabel': '管理者ダッシュボード (未実装)',
      'uiNavigation': null,
      'category': 'growth',
    },
    {
      'name': 'agent-runtime-cycle',
      'description': 'AI エージェント定期サイクル実行',
      'hasUi': false,
      'uiPath': '/agents',
      'uiLabel': 'AI 組織 OS (未連携)',
      'uiNavigation': null,
      'category': 'ai',
    },
    {
      'name': 'trigger-analysis',
      'description': 'トリガー分析 (選挙戦略ページ)',
      'hasUi': true,
      'uiPath': '/home',
      'uiLabel': '選挙戦略ページ',
      'uiNavigation': '選挙戦略ページ',
      'category': 'ai',
    },
    {
      'name': 'get-ogp',
      'description': 'OGP メタデータ取得 (内部)',
      'hasUi': false,
      'uiPath': null,
      'uiLabel': 'サーバーサイド専用',
      'uiNavigation': null,
      'category': 'core',
    },
    {
      'name': 'get-public-memo-preview',
      'description': '公開メモプレビュー (内部)',
      'hasUi': false,
      'uiPath': '/public-memos',
      'uiLabel': '公開メモ一覧 (未連携)',
      'uiNavigation': null,
      'category': 'data',
    },
    {
      'name': 'growth-achievement-summary',
      'description': '開発実績サマリー',
      'hasUi': true,
      'uiPath': '/admin',
      'uiLabel': '管理者ダッシュボード',
      'uiNavigation': null,
      'category': 'growth',
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

  Future<void> _testFunction(String name) async {
    setState(() => _loading = true);
    try {
      final result = await _supabase.functions.invoke(
        name,
        method: HttpMethod.get,
      );
      setState(() {
        _testResults[name] = {
          'status': result.status,
          'ok': result.status < 300,
        };
      });
    } catch (e) {
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
                  Colors.grey,
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
                final color =
                    _categoryColors[cat] ?? const Color(0xFF6366F1);
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
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${fns.length}件',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color),
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
                  color: hasUi
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
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
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style:
                            TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                                  : Colors.grey[400],
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                uiLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: hasUi
                                      ? const Color(0xFF6366F1)
                                      : Colors.grey[400],
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
                                style: TextStyle(fontSize: 10, color: color),
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
                                : Colors.grey[400],
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
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text(
                          '実装へ',
                          style: TextStyle(fontSize: 11),
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
