-- PS#4 S402: 競合3社追加 1030→1033社 (crisp/tawk-to/tidio)
-- SEO: "Crisp代替"/"tawk.to代替"/"Tidio代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S402: 競合3社追加 1030→1033社 (crisp/tawk-to/tidio)',
  'comparison_page.dartにcrisp(スタートアップ向けライブチャットチャットボットカスタマーサポートハブ/live-chat/1972F5)/tawk-to(完全無料ライブチャットチケット管理CRM/live-chat/03A84E)/tidio(AIチャットボットライブチャットeコマース向けサポート/live-chat/5C6BC0)の3社追加(1030→1033社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
