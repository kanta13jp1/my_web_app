-- ============================================================
-- Seed: 2026-03-25 session 2
-- 本日の追加開発実績
-- ============================================================

insert into public.development_achievements (title, completed_at) values
  ('公開メモ SEO 強化: get-public-memo-preview Edge Function 新規作成 (public_memos テーブルから Markdown 除去済みエクサープト・pageTitle・ogDescription を返す認証不要エンドポイント)', '2026-03-25 15:00:00+00'),
  ('index.html SEO シェル改善: /public-memo?id=XXX の URL で Flutter 起動前に OGP メタタグ (og:title / og:description / twitter:card) を動的書き換え → SNS シェアカードに実メモ内容を表示', '2026-03-25 15:30:00+00'),
  ('get-home-dashboard Edge Function 新規作成: ホーム画面マーケティング KPI (totalUsers / todaySignups / todayViews / todayShares / lpSeries) を Promise.all で並列フェッチし 1 API 呼び出しに統合', '2026-03-25 16:00:00+00'),
  ('home_page.dart リファクタ: _loadHomeMarketingKpiSummary を get-home-dashboard Edge Function 呼び出しに置換 (3〜4 往復 DB クエリを廃止・未使用 _normalizeDateKey メソッド削除)', '2026-03-25 16:30:00+00'),
  ('DevelopmentAchievementsCard バグ修正: ドロップダウン期間変更時に _fetchTasks が呼ばれず一覧が更新されない問題を修正', '2026-03-25 17:00:00+00'),
  ('Zenn 技術ブログ原稿完成 (docs/zenn_growth_dashboard_20260325.md): 4 つの Edge Function 実装詳細・Flutter 呼び出しコード例・deno lint 0 件維持の運用原則を記載', '2026-03-25 17:30:00+00')
on conflict do nothing;
