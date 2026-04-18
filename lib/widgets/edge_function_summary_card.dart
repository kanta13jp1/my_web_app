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
    _FnDef(
      'ai-assistant',
      'AI アシスタント (汎用)',
      true,
      '/agents',
      'ホーム > AI組織OS をタップ',
    ),
    _FnDef(
      'growth-hub',
      '獲得レポート / コマンドセンター / 紹介 (hub)',
      true,
      '/growth-mission',
      '成長ミッション > グロース機能',
    ),
    _FnDef(
      'growth-weekly-digest',
      '週次グロース指標',
      true,
      '/growth-mission',
      '成長ミッション > 週次',
    ),
    _FnDef(
      'get-public-memo-preview',
      '公開メモ SEO プレビュー',
      false,
      null,
      'サーバーサイド専用 (index.html SEO pre-rendering)',
    ),
    _FnDef(
      'local-election-intelligence',
      '選挙インテリジェンス',
      true,
      '/election-dashboard',
      '選挙戦略ページ > AI分析',
    ),
    _FnDef(
      'memo-reactions',
      '公開メモ絵文字リアクション',
      true,
      '/public-memos',
      '公開メモ詳細 > 絵文字リアクションバー',
    ),
    // --- 追加 Edge Functions ---
    // 追加 (session432o)
    // 追加 (session432p-432q: 185→195)
    // 追加 (session432r-432t: 195→210)
    // 追加 (session432u: 210→215)
    // 追加 (cs-check 自動連携)
    // 追加 (cs-check 自動連携)
    _FnDef(
      'guitar-recording-studio',
      'ギターレコーディングスタジオ + 公開ギャラリー',
      true,
      '/guitar-recording-studio',
      'スタジオ (/guitar-recording-studio) / 公開ギャラリー (/public-guitar-gallery)',
    ),
    // 追加 (cs-check 自動連携)
    // 追加 (cs-check 自動連携)
    // 追加 (cs-check 自動連携)
    // 追加 (cs-check 自動連携)
    // 追加 (cs-check 自動連携)
    // 追加 (cs-check 自動連携)
    // 追加 (cs-check 自動連携)
    _FnDef(
      'core-hub',
      'コアハブ (ホームダッシュボード/チャット/AI/成長統合)',
      true,
      '/home',
      'ホーム画面 (統合API経由)',
    ),
    _FnDef(
      'enterprise-hub',
      'エンタープライズハブ (業務管理/CRM/BI/コンプライアンス統合)',
      true,
      '/admin',
      '管理者ダッシュボード > エンタープライズ機能',
    ),
    _FnDef(
      'lifestyle-hub',
      'ライフスタイルハブ (健康/旅行/スマートホーム/通知統合)',
      true,
      '/home',
      'ホーム > 生活管理カード',
    ),
    _FnDef(
      'media-hub',
      'メディアハブ (動画/音声/ドキュメント/会議統合)',
      true,
      '/admin',
      '管理者ダッシュボード > メディア管理',
    ),
    _FnDef(
      'social-commerce-hub',
      'ソーシャル・コマースハブ (SNS/EC/決済/学習統合)',
      true,
      '/social-feed',
      'ソーシャルフィード > コマース機能',
    ),
    _FnDef(
      'tools-hub',
      'ツールハブ (生産性ツール/メモ/習慣/テンプレート統合)',
      true,
      '/home',
      'ホーム > クイックアクセス > ツール',
    ),
    // 追加 (cs-check 自動連携)
    _FnDef(
      'admin-hub',
      '管理者ハブ統合 (CS/競合/ユーザー/統計)',
      true,
      '/admin',
      '管理者ダッシュボード > 統合管理',
    ),
    _FnDef(
      'ai-hub',
      'AIハブ統合 (要約/選挙分析/トリガー)',
      true,
      '/ai-summarizer',
      'AI要約ページ / 選挙戦略ページ > AIアシスタント',
    ),
    _FnDef(
      'growth-hub',
      '成長ハブ統合 (グロース指令/自動化/週次)',
      true,
      '/growth-mission',
      '成長ミッションページ > グロース指令センター',
    ),
    _FnDef(
      'schedule-hub',
      'スケジュールハブ統合 (実行ログ/ヘルスチェック/結果/モニター)',
      true,
      '/admin',
      '管理者ダッシュボード > Schedule モニター',
    ),
    // 追加 (cs-check 自動連携)
    _FnDef(
      'app-hub',
      'アプリハブ統合 (サブスクリプション/カレンダー/タスク/チャット統合)',
      true,
      '/app-hub',
      'アプリハブページ',
    ),
    // 追加 (cs-check 自動連携 2026-04-17)
    // 追加 (cs-check 自動連携 2026-04-12)
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
                            backgroundColor:
                                isDark ? Colors.grey[800] : Colors.grey[200],
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
