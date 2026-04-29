-- PS#4 S576: 競合3社追加 継続 (gorgias/re-amaze/groove)
-- SEO: "Gorgias代替"/"Re:amaze代替"/"Groove代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S576: 競合3社追加 (gorgias/re-amaze/groove)',
  'comparison_page.dartにgorgias(Eコマース特化CS・Shopify統合・AI自動化・マルチチャネル/6366F1)/re-amaze(Eコマース統合CS・ライブチャット・FAQ・WooCommerce/2196F3)/groove(SMB共有受信箱・シンプルヘルプデスク・Gmail統合/0A3E6E)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
