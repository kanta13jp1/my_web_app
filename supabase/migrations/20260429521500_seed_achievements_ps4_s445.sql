-- PS#4 S445: 競合3社追加 1159→1162社 (zulip/chanty/flock-app)
-- SEO: "Zulip代替"/"Chanty代替"/"Flock代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S445: 競合3社追加 1159→1162社 (zulip/chanty/flock-app)',
  'comparison_page.dartにzulip(スレッド型OSSチームチャット非同期重視大規模コミュニティ/team-chat/6492FE)/chanty(シンプルチームチャットタスク統合無制限メッセージ/team-chat/F85E00)/flock-app(インド発チームメッセージングチャンネルビデオ会議/team-chat/6F42C1)の3社追加(1159→1162社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
