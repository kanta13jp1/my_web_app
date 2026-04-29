-- PS#4 S457: 競合3社追加 1192→1195社 (betterment/wealthfront/acorns)
-- SEO: "Betterment代替"/"Wealthfront代替"/"Acorns代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S457: 競合3社追加 1192→1195社 (betterment/wealthfront/acorns)',
  'comparison_page.dartにbetterment(米国ロボアドバイザー税損失収穫/ゴール別投資/0A2540)/wealthfront(自動ETFポートフォリオPath Financialプランニング直接インデックス/5BC07D)/acorns(マイクロ投資おつり自動投資Found Money/6A8A2F)の3社追加(1192→1195社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
