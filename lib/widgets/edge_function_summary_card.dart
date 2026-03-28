import 'package:flutter/material.dart';

/// ホーム画面用: Edge Function 一覧の簡易表示カード。
///
/// 全 Edge Functions を UI 有無別に集計して表示し、
/// 各 Function の UI 操作手順または「UI未実装」を示す。
/// 詳細は EdgeFunctionStatusPage (/edge-functions) へリンク。
class EdgeFunctionSummaryCard extends StatefulWidget {
  const EdgeFunctionSummaryCard({super.key});

  @override
  State<EdgeFunctionSummaryCard> createState() =>
      _EdgeFunctionSummaryCardState();
}

class _EdgeFunctionSummaryCardState extends State<EdgeFunctionSummaryCard> {
  bool _expanded = false;

  // Edge Function の定義 (EdgeFunctionStatusPage と同期)
  static const List<_FnDef> _functions = [
    _FnDef('get-home-dashboard', 'ホーム画面の統合データ', true, '/home', 'ホーム画面を開く'),
    _FnDef('development-achievements', '開発実績一覧', true, '/', 'ランディングページ最下部で確認'),
    _FnDef('get-growth-roadmap-progress', '競合 vs 進捗バー', true, '/home', 'ホーム画面 > 進捗バーセクション'),
    _FnDef('get-competitor-features', '競合機能比較データ', true, '/home', 'ホーム画面 > 競合比較カード'),
    _FnDef('ai-assistant', 'AI アシスタント (汎用)', true, '/agents', 'ホーム > AI組織OS をタップ'),
    _FnDef('ai-search', 'AI 全文検索', true, '/home', 'ホーム画面 > ノート検索バー'),
    _FnDef('ai-suggest-tags', 'AI タグ自動提案', true, '/note-editor', 'ノートエディタ > タグ提案ボタン'),
    _FnDef('daily-judgment', 'ストリーク判定 (自動)', false, '/admin', '管理者ダッシュボード > 手動実行'),
    _FnDef('schedule-daily-digest', '日次メトリクス API', true, '/admin', '管理者ダッシュボード > Schedule モニター'),
    _FnDef('get-support-tickets', 'CS チケット一覧', true, '/admin', '管理者ダッシュボード > CS セクション'),
    _FnDef('reply-support-request', 'CS チケット返信', true, '/admin', '管理者ダッシュボード > CS 返信'),
    _FnDef('post-x-update', 'X 自動投稿', true, '/admin', '管理者ダッシュボード > X 投稿'),
    _FnDef('growth-share-signal', 'シェアイベント記録', true, '/public-memos', '公開メモ > シェアボタン'),
    _FnDef('growth-referral', '紹介コード処理', true, '/referral', '紹介プログラムページ'),
    _FnDef('growth-acquisition-signal', '獲得イベント記録', true, '/', 'ランディングページ経由で自動'),
    _FnDef('growth-acquisition-report', '獲得レポート', true, '/growth-mission', '成長ミッション > レポート'),
    _FnDef('growth-command-center', 'グロース指令センター', true, '/growth-mission', '成長ミッション'),
    _FnDef('growth-weekly-digest', '週次グロース指標', true, '/growth-mission', '成長ミッション > 週次'),
    _FnDef('growth-import-preview', 'インポートプレビュー', true, '/import', 'インポートページ > プレビュー'),
    _FnDef('growth-import-commit', 'インポート実行', true, '/import', 'インポートページ > 実行'),
    _FnDef('notify-feature-request', '機能リクエスト通知', true, '/feature-requests', '機能リクエスト'),
    _FnDef('send-waitlist-notification', 'ウェイトリスト通知', true, '/admin', '管理者ダッシュボード'),
    _FnDef('analyze-reality', 'リアリティチェック AI', true, '/reality-check', 'ホーム > 現実直視ノート'),
    _FnDef('generate-daily-challenges', 'デイリーチャレンジ生成', true, '/home', 'ホーム > デイリーチャレンジカード'),
    _FnDef('generate-quote-image', '名言画像生成', true, '/home', 'ホーム > モチベーションカード'),
    _FnDef('share-quote', '名言シェア URL', true, '/home', 'ホーム > モチベーションカード > シェア'),
    _FnDef('get-admin-users', '管理者ユーザー一覧', true, '/admin', '管理者ダッシュボード > ユーザー管理'),
    _FnDef('health-check', 'DB ヘルスチェック', true, '/admin', '管理者ダッシュボード > Schedule モニター'),
    _FnDef('check-competitor-updates', '競合 Web 可用性チェック', true, '/admin', '管理者ダッシュボード > 競合モニタリングカード'),
    _FnDef('agent-runtime-cycle', 'エージェント定期サイクル', false, null, 'Schedule専用 (cron secret 認証・UI非対応)'),
    _FnDef('trigger-analysis', 'トリガー分析', true, '/home', '選挙戦略ページ経由'),
    _FnDef('get-ogp', 'OGP メタデータ', false, null, 'サーバーサイド専用'),
    _FnDef('get-public-memo-preview', '公開メモ SEO プレビュー', false, null, 'サーバーサイド専用 (index.html SEO pre-rendering)'),
    _FnDef('public-memo-share', '公開メモ シェアリダイレクト', false, null, 'サーバーサイド専用 (OGP シェア URL リダイレクト)'),
    _FnDef('get-public-memo-ogp', '公開メモ OGP 画像', true, '/public-memos', '公開メモ詳細 > OGP 画像自動生成'),
    _FnDef('get-competitor-monitoring', '競合モニタリング', true, '/admin', '管理者ダッシュボード > 競合モニタリング'),
    _FnDef('local-election-intelligence', '選挙インテリジェンス', true, '/election', '選挙戦略ページ > AI分析'),
    _FnDef('note-comments', 'ノートコメント CRUD', true, '/note-editor', 'ノートエディタ > 💬 コメントアイコン'),
    _FnDef('memo-reactions', '公開メモ絵文字リアクション', true, '/public-memos', '公開メモ詳細 > 絵文字リアクションバー'),
    _FnDef('growth-achievement-summary', '開発実績サマリー', true, '/admin', '管理者ダッシュボード'),
  ];

  int get _withUiCount => _functions.where((f) => f.hasUi).length;
  int get _noUiCount => _functions.where((f) => !f.hasUi).length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pct = (_withUiCount / _functions.length * 100).round();
    final noUiFns = _functions.where((f) => !f.hasUi).toList();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // ヘッダー
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.api,
                      size: 18,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edge Functions 実装状況',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '全 ${_functions.length} 件  |  UI 実装済: $_withUiCount 件  |  UI未実装: $_noUiCount 件  ($pct%)',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 進捗バー
                  SizedBox(
                    width: 60,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$pct%',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _withUiCount / _functions.length,
                            minHeight: 6,
                            backgroundColor: isDark
                                ? Colors.grey[800]
                                : Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF6366F1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),

          if (_expanded) ...[
            const Divider(height: 1),

            // UI未実装の関数リスト
            if (noUiFns.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'UI 未実装 / 未連携 ($_noUiCount 件)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: noUiFns.length,
                itemBuilder: (context, i) {
                  final fn = noUiFns[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.circle,
                          size: 6,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fn.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          fn.description,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Divider(height: 16),
            ],

            // UI実装済み一覧 (最初の10件)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 14,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'UI 実装済み ($_withUiCount 件) — 操作手順',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            ..._functions
                .where((f) => f.hasUi)
                .take(8)
                .map((fn) => _buildFnRow(fn, isDark)),
            if (_withUiCount > 8)
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Text(
                  '他 ${_withUiCount - 8} 件 → 詳細は Edge Functions 状況ページへ',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
              ),

            // 詳細ページへのボタン
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('Edge Functions 詳細・テストページ'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6366F1),
                    side: const BorderSide(color: Color(0xFF6366F1)),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () =>
                      Navigator.pushNamed(context, '/edge-functions'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFnRow(_FnDef fn, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.chevron_right, size: 14, color: Colors.green),
          const SizedBox(width: 4),
          SizedBox(
            width: 160,
            child: Text(
              fn.name,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              fn.uiInstruction ?? '',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FnDef {
  final String name;
  final String description;
  final bool hasUi;
  final String? uiPath;
  final String? uiInstruction;

  const _FnDef(
    this.name,
    this.description,
    this.hasUi,
    this.uiPath,
    this.uiInstruction,
  );
}
