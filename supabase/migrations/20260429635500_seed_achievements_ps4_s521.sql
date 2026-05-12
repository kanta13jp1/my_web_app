-- PS#4 S521: 競合3社追加 継続 (looker-studio/sisense/sigma-computing)
-- SEO: "Looker Studio代替"/"Sisense代替"/"Sigma Computing代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S521: 競合3社追加 (looker-studio/sisense/sigma-computing)',
  'comparison_page.dartにlooker-studio(Google無料BIツール・旧Data Studio・BigQuery統合・ダッシュボード・Google Workspace連携/4285F4)/sisense(埋め込みBI・ホワイトラベル・AI InsightBot・In-Chipエンジン・SaaS製品組み込み/673AB7)/sigma-computing(クラウドBIスプレッドシートUI・Snowflake/BigQuery直接クエリ・ノーコードSQL/00BCD4)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
