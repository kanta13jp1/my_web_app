-- PS#4 S502: 競合3社追加 継続 (placeit/snappa/pixlr)
-- SEO: "Placeit代替"/"Snappa代替"/"Pixlr代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S502: 競合3社追加 (placeit/snappa/pixlr)',
  'comparison_page.dartにplaceit(モックアップロゴ動画テンプレート50K+デザインEnvato/7B1FA2)/snappa(高速グラフィック6000テンプレートフリー写真3M枚SNS自動投稿/00BCD4)/pixlr(ブラウザ写真編集AI背景除去フィルターレイヤー/1565C0)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
