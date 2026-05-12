-- PS#4 S446: 競合3社追加 1162→1165社 (twist-app/pumble/mimecast)
-- SEO: "Twist代替"/"Pumble代替"/"Mimecast代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S446: 競合3社追加 1162→1165社 (twist-app/pumble/mimecast)',
  'comparison_page.dartにtwist-app(Doist非同期チームコミュニケーションスレッド重視集中力Todoist連携/team-chat/EF4444)/pumble(完全無料Slack代替無制限メッセージゲスト招待/team-chat/7C3AED)/mimecast(メールセキュリティフィッシングBEC防御アーカイブ/email-security/002855)の3社追加(1162→1165社)。sitemap 1255 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
