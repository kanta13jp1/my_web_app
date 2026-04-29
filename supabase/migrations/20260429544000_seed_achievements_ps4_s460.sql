-- PS#4 S460: 競合3社追加 1201→1204社 (quora/snapchat/arc)
-- SEO: "Quora代替"/"Snapchat代替"/"Arc代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S460: 競合3社追加 1201→1204社 (quora/snapchat/arc)',
  'comparison_page.dartにquora(Q&Aナレッジ共有Spaces Poe AI専門家回答/B92B27)/snapchat(消えるメッセージARレンズStories Snap Map/FFFC00)/arc(The Browser Company SpacesコマンドバーMax AI/FF4F00)の3社追加(1201→1204社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
