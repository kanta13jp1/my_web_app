-- Session 25: Schedule タスクモニター + SEO/OGP 強化 + 競合モニタリング
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'Schedule タスク実行状況モニターを管理者ダッシュボードに追加',
    'ScheduleTaskMonitorCard ウィジェットを新規作成。9つの定期タスク（daily-report, cs-check, weekly-sns-draft, daily-development, pr-auto-review, competitor-monitoring, infra-health-check, dependency-audit, blog-draft）の実行状況をリアルタイム表示。schedule_task_runs テーブルから実行ログを取得し、ステータス別カラー表示（成功/実行中/エラー/スキップ/待機中）に対応。',
    '2026-03-26'
  ),
  (
    '公開メモの SEO/OGP meta タグ動的更新を実装',
    'SeoMetaHelper ユーティリティを新規作成し、公開メモ詳細ページで og:title, og:description, og:url, og:image, Twitter Card を動的に設定。ページ離脱時にデフォルトにリセットする仕組みにより、SPA内の他ページに影響しない実装。organic検索流入の増加を狙った施策。',
    '2026-03-26'
  ),
  (
    'schedule_task_runs テーブル作成（マイグレーション）',
    'Claude Code Schedule の実行ログを記録するテーブルを作成。task_id + started_at の複合インデックス、RLS ポリシー（service_role: 全操作、authenticated: 読み取り）を設定。管理者ダッシュボードの ScheduleTaskMonitorCard が参照する。',
    '2026-03-26'
  ),
  (
    'health-check Edge Function 新規作成',
    'インフラヘルスチェック用 Edge Function を作成。DB 接続性・レイテンシ測定、必須6テーブル（user_profiles, notes, development_achievements, feature_requests, growth_plans, tech_blog_posts）のアクセス確認、ユーザー数・実績数のカウントを返す。ステータスは healthy/degraded/unhealthy の3段階。',
    '2026-03-26'
  ),
  (
    'check-competitor-updates Edge Function 新規作成',
    '競合14社の Web サイト可用性チェック Edge Function を作成。HEAD リクエスト（10秒タイムアウト）で並列チェックし、competitor_monitoring テーブルに結果を保存。レスポンスタイム・ステータスコード・可用性を記録。',
    '2026-03-26'
  ),
  (
    'competitor_monitoring テーブル作成（マイグレーション）',
    '競合14社の Web サイト監視結果を記録するテーブルを作成。competitor_name, competitor_url, status_code, response_time_ms, available, checked_at カラム。competitor_name + checked_at の複合インデックスを設定。',
    '2026-03-26'
  )
ON CONFLICT DO NOTHING;
