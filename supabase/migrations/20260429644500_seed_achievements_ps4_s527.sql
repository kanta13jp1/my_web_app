-- PS#4 S527: 競合3社追加 継続 (sprig/instabug/usersnap)
-- SEO: "Sprig代替"/"Instabug代替"/"Usersnap代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S527: 競合3社追加 (sprig/instabug/usersnap)',
  'comparison_page.dartにsprig(旧UserLeap プロダクト調査プラットフォーム・マイクロサーベイ・AIインサイト・インプロダクト/1DB954)/instabug(モバイルアプリバグ報告・クラッシュレポート・セッションリプレイ・フィードバックSDK/FF6600)/usersnap(ビジュアルバグ報告・スクリーンショット注釈・プロダクトフィードバック・Jira/Slack連携/5B4FBE)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
