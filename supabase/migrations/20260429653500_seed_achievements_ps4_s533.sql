-- PS#4 S533: 競合3社追加 継続 (craft-io/airfocus/padlet)
-- SEO: "Craft.io代替"/"Airfocus代替"/"Padlet代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S533: 競合3社追加 (craft-io/airfocus/padlet)',
  'comparison_page.dartにcraft-io(プロダクト管理プラットフォーム・北極星・OKR・ロードマップ・バックログ・AI機能/3F51B5)/airfocus(プロダクト優先付け・スコアリングモデル・ロードマップ・モジュラー設計・AIアシスト/F97316)/padlet(仮想ピンボード・教育/チーム向け・マルチメディア・リアルタイム共同編集・無料プラン/48C774)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
