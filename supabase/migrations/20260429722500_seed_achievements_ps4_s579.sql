-- PS#4 S579: 競合3社追加 継続 (genesys/avaya/nice-incontact)
-- SEO: "Genesys代替"/"Avaya代替"/"NICE CXone代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S579: 競合3社追加 (genesys/avaya/nice-incontact)',
  'comparison_page.dartにgenesys(AIコンタクトセンター・オムニチャネル・音声/チャット・CX統合/FF4F1B)/avaya(Experience Platform・UCaaS/CCaaS・ハイブリッドクラウド/DA291C)/nice-incontact(クラウドCCaaS・AIオートメーション・WFM・分析/003DA5)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
