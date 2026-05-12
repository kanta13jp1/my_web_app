-- PS#4 S530: 競合3社追加 継続 (sleekplan/frill/userback)
-- SEO: "Sleekplan代替"/"Frill代替"/"Userback代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S530: 競合3社追加 (sleekplan/frill/userback)',
  'comparison_page.dartにsleekplan(プロダクトフィードバック・機能リクエスト投票・ロードマップ公開・チェンジログ・無料/6B48FF)/frill(機能リクエスト収集・投票ボード・ロードマップ・チェンジログ・ウィジェット埋め込み/F59E0B)/userback(フィードバックウィジェット・ビデオ録画・注釈・Jira/Trello・アジャイルチーム/0EA5E9)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
