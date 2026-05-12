-- PS#4 S288: 競合3社追加 735→738社 (teamtailor/phenom/checkr)
-- SEO: "Teamtailor代替"/"Phenom代替"/"Checkr代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S288: 競合3社追加 735→738社 (teamtailor/phenom/checkr)',
  'comparison_page.dartにteamtailor(雇用主ブランディング採用/ats/3FE0D0)/phenom(AI採用マーケティング候補者体験/ats/8B3DFF)/checkr(AI採用バックグラウンドチェック/hr/0055FF)の3社追加(735→738社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
