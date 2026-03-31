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
    _FnDef('gemini-election-analysis', 'Gemini 選挙AI分析', true, '/local-election-700', '選挙戦略ページ > AI分析ボタン'),
    // --- 追加 Edge Functions ---
    _FnDef('ai-secretary', 'AI 秘書 (秘書機能)', true, '/ai-secretary', 'ホーム > QUICK ACCESS > AI秘書'),
    _FnDef('agent-department-manager', '仮想部署管理', true, '/agents', 'ホーム > AI組織OS > 部署管理'),
    _FnDef('agent-performance-monitor', 'エージェント実績モニター', true, '/agents', 'ホーム > AI組織OS > 実績'),
    _FnDef('agent-personality', 'エージェント個性設定', true, '/agents', 'ホーム > AI組織OS > 個性設定'),
    _FnDef('agent-task-router', 'エージェントタスク振り分け', true, '/agents', 'ホーム > AI組織OS > タスク'),
    _FnDef('department-reporting', '部署レポート生成', true, '/agents', 'ホーム > AI組織OS > 部署レポート'),
    _FnDef('team-task-manager', 'チームタスク管理', true, '/team', 'ホーム > チームワーク > タスク'),
    _FnDef('team-collaboration-sync', 'チームコラボ同期', true, '/team', 'ホーム > チームワーク > 同期'),
    _FnDef('kanban-board', 'カンバンボード', true, '/kanban', 'ホーム > タスク管理 > カンバン'),
    _FnDef('habit-tracker', '習慣トラッカー', true, '/daily-habits', 'ホーム > 日課・習慣'),
    _FnDef('goal-tracker', 'ゴールトラッカー', true, '/life-goals', 'ホーム > ライフゴール'),
    _FnDef('gamification-engine', 'ゲーミフィケーション', true, '/rewards', 'ホーム > 報酬・実績'),
    _FnDef('feature-request-manager', '機能リクエスト管理', true, '/feature-requests', '機能リクエストページ'),
    _FnDef('import-from-competitors', '競合アプリからインポート', true, '/import', 'ホーム > インポート'),
    _FnDef('blog-post-manager', '技術ブログ投稿管理', true, '/tech-blog-tracker', 'ホーム > 技術ブログトラッカー'),
    _FnDef('template-library', 'テンプレートライブラリ', true, '/templates', 'ホーム > テンプレート'),
    _FnDef('bookmark-manager', 'ブックマーク管理', true, '/bookmarks', 'ホーム > ブックマーク'),
    _FnDef('user-profile-manager', 'ユーザープロフィール管理', true, '/profile', 'ホーム > プロフィール設定'),
    _FnDef('user-feedback-collector', 'ユーザーフィードバック収集', true, '/feedback', 'ホーム > フィードバック'),
    _FnDef('onboarding-flow', 'オンボーディングフロー', true, '/onboarding', '新規登録後 > ウェルカム画面'),
    _FnDef('notification-center', '通知センター', true, '/settings', '設定 > 通知センター'),
    _FnDef('notification-preferences', '通知設定', true, '/settings', '設定 > 通知設定'),
    _FnDef('subscription-management', 'サブスクリプション管理', true, '/profile', 'プロフィール > プラン管理'),
    _FnDef('search-analytics', '検索アナリティクス', true, '/admin', '管理者ダッシュボード > 検索分析'),
    _FnDef('user-activity-tracker', 'ユーザー行動追跡', true, '/admin', '管理者ダッシュボード > 行動ログ'),
    _FnDef('app-analytics-dashboard', 'アプリ分析ダッシュボード', true, '/admin', '管理者ダッシュボード > アナリティクス'),
    _FnDef('development-stats', '開発統計', true, '/admin', '管理者ダッシュボード > 開発統計'),
    _FnDef('revenue-forecaster', '収益予測', true, '/admin', '管理者ダッシュボード > 収益予測'),
    _FnDef('ab-testing-manager', 'A/Bテスト管理', true, '/admin', '管理者ダッシュボード > A/Bテスト'),
    _FnDef('data-export-manager', 'データエクスポート', true, '/admin', '管理者ダッシュボード > データ出力'),
    _FnDef('content-moderation', 'コンテンツモデレーション', true, '/admin', '管理者ダッシュボード > 監査'),
    _FnDef('competitor-feature-sync', '競合機能データ同期', true, '/admin', '管理者ダッシュボード > 競合同期'),
    _FnDef('seo-optimizer', 'SEO 最適化', true, '/admin', '管理者ダッシュボード > SEO'),
    _FnDef('webhook-manager', 'Webhook 管理', true, '/admin', '管理者ダッシュボード > Webhook'),
    _FnDef('api-rate-limiter', 'API レート制限', false, null, 'サーバーサイド専用 (自動適用)'),
    _FnDef('schedule-task-monitor', 'Schedule 実行ログ', true, '/admin', '管理者ダッシュボード > Schedule モニター'),
    _FnDef('schedule-health-check', 'Schedule ヘルスチェック', true, '/admin', '管理者ダッシュボード > Schedule モニター'),
    _FnDef('edge-function-coverage', 'Edge Function カバレッジ', true, '/edge-functions', 'ホーム > API ステータス > 詳細'),
    _FnDef('code-review-issues', 'コードレビュー Issue 発行', false, null, 'Schedule 専用 (cs-check タスク)'),
    _FnDef('expense-tracker', '支出トラッカー', true, '/financial-report', 'ホーム > 財務レポート'),
    _FnDef('invoice-generator', '請求書生成', true, '/financial-report', 'ホーム > 財務レポート > 請求書'),
    _FnDef('markdown-renderer', 'Markdown レンダラー', true, '/note-editor', 'ノートエディタ内で自動適用'),
    _FnDef('quick-note', 'クイックノート', true, '/note-editor', 'ホーム > ノート > 新規作成'),
    _FnDef('reading-list', 'リーディングリスト', true, '/bookmarks', 'ホーム > ブックマーク > リーディングリスト'),
    _FnDef('tag-manager', 'タグ管理', true, '/note-list', 'ノート一覧 > タグフィルター'),
    _FnDef('ai-summarizer', 'AI 要約', true, '/note-editor', 'ノートエディタ > AI 要約ボタン'),
    _FnDef('calendar-events', 'カレンダーイベント', true, '/home', 'ホーム > スケジュールカード'),
    _FnDef('pomodoro-timer', 'ポモドーロタイマー', true, '/home', 'ホーム > 集中タイマー'),
    _FnDef('time-tracker', '時間トラッカー', true, '/home', 'ホーム > 時間管理カード'),
    _FnDef('poll-survey', 'アンケート・投票', true, '/feature-requests', '機能リクエスト > 投票'),
    _FnDef('password-generator', 'パスワード生成', true, '/settings', '設定 > セキュリティ > パスワード生成'),
    _FnDef('currency-converter', '通貨換算', true, '/financial-report', 'ホーム > 財務 > 通貨換算'),
    _FnDef('contact-manager', 'コンタクト管理', true, '/home', 'ホーム > 人脈管理'),
    _FnDef('chat-messaging', 'チャット/メッセージング', true, '/team', 'チームワーク > チャット'),
    _FnDef('clipboard-history', 'クリップボード履歴', true, '/home', 'ホーム > クイックアクセス'),
    _FnDef('file-storage-manager', 'ファイルストレージ', true, '/admin', '管理者ダッシュボード > ファイル管理'),
    _FnDef('weather-widget', '天気ウィジェット', true, '/home', 'ホーム > ダッシュボード'),
    _FnDef('system-status', 'システムステータス', true, '/admin', '管理者ダッシュボード > システム状態'),
    _FnDef('automation-workflows', '自動化ワークフロー', true, '/home', 'ホーム > 自動化設定'),
    _FnDef('knowledge-base', 'ナレッジベース', true, '/knowledge-base', 'ナレッジベースページ > 記事検索・閲覧'),
    _FnDef('semantic-search', 'セマンティック検索 (意味検索)', true, '/semantic-search', 'セマンティック検索ページ > キーワード入力'),
    _FnDef('social-feed', 'ソーシャルフィード', true, '/social-feed', 'ソーシャルフィードページ > 投稿一覧'),
    _FnDef('api-key-manager', 'API キー管理', true, '/admin', '管理者ダッシュボード > API キー'),
    _FnDef('cohort-analysis', 'コホート分析', true, '/admin', '管理者ダッシュボード > コホート分析'),
    _FnDef('document-collaboration', 'ドキュメント共同編集', true, '/note-editor', 'ノートエディタ > 共同編集'),
    _FnDef('email-service', 'メール送信サービス', false, null, 'サーバーサイド専用 (自動送信)'),
    _FnDef('integration-connector', '外部サービス連携', true, '/admin', '管理者ダッシュボード > インテグレーション'),
    _FnDef('leave-management', '休暇管理', true, '/chro-office', 'QUICK ACCESS > 財務・健康・人事 > 人事厚生(CHRO)'),
    _FnDef('marketplace', 'マーケットプレイス', true, '/templates', 'テンプレートマーケットプレイス'),
    _FnDef('payment-processor', '支払い処理', true, '/financial-report', '財務レポート > 支払い処理'),
    _FnDef('performance-review', '人事評価', true, '/chro-office', 'QUICK ACCESS > 財務・健康・人事 > 人事厚生(CHRO)'),
    _FnDef('scheduled-notifications', 'スケジュール通知', true, '/settings', '設定 > 通知スケジュール'),
    _FnDef('video-audio-manager', '動画・音声ファイル管理', true, '/admin', '管理者ダッシュボード > メディア管理'),
    _FnDef('wiki-database', 'Wiki データベース', true, '/knowledge-base', 'ナレッジベース > Wiki'),
    _FnDef('ci-cd-pipeline', 'CI/CD パイプライン管理', false, null, 'Schedule専用 (自動ビルド・デプロイ)'),
    _FnDef('compensation-manager', '給与・報酬管理', true, '/chro-office', 'QUICK ACCESS > 財務・健康・人事 > 人事厚生(CHRO)'),
    _FnDef('financial-report', '財務レポート生成', true, '/financial-report', 'QUICK ACCESS > 財務・健康・人事 > 財務レポート'),
    _FnDef('inventory-manager', '在庫管理', true, '/admin', '管理者ダッシュボード > 在庫管理'),
    _FnDef('oauth-sso-provider', 'OAuth/SSO プロバイダー', false, null, 'サーバーサイド専用 (認証フロー)'),
    _FnDef('ocr-document-scanner', 'OCR ドキュメントスキャナー', true, '/real-world-danshari', 'QUICK ACCESS > 生活・整理 > 断捨離(リアル)'),
    _FnDef('order-tracker', '注文トラッカー', true, '/financial-report', '財務レポート > 注文管理'),
    _FnDef('push-notification-manager', 'プッシュ通知管理', true, '/settings', '設定 > 通知設定'),
    _FnDef('realtime-presence', 'リアルタイムプレゼンス', true, '/team', 'チームワーク > オンライン状態'),
    _FnDef('voice-memo-transcriber', '音声メモ文字起こし', true, '/note-editor', 'ノートエディタ > 音声入力'),
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
