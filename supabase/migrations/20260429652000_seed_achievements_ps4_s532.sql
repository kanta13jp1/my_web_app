-- PS#4 S532: 競合3社追加 継続 (upvoty/wishkit/productplan)
-- SEO: "Upvoty代替"/"Wishkit代替"/"ProductPlan代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S532: 競合3社追加 (upvoty/wishkit/productplan)',
  'comparison_page.dartにupvoty(機能リクエスト投票・ホワイトラベル・ウィジェット・Jira/Slack・ロードマップ/6C63FF)/wishkit(iOSアプリ向け機能リクエスト・SwiftUI SDK数行実装・投票・ロードマップ内蔵/FF2D55)/productplan(プロダクトロードマップソフト・戦略整合・ビジュアル・ステークホルダー共有・Jira連携/00BFA5)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
