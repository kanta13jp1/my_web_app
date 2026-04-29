-- PS#4 S404: 競合3社追加 1036→1039社 (delighted/clearbit/lusha)
-- SEO: "Delighted代替"/"Clearbit代替"/"Lusha代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S404: 競合3社追加 1036→1039社 (delighted/clearbit/lusha)',
  'comparison_page.dartにdelighted(NPS/CSAT/CES顧客フィードバック収集分析/nps/2AC769)/clearbit(B2BデータエンリッチメントリードインテリジェンスリバースIP/data-enrichment/6563FF)/lusha(B2Bコンタクトデータメール電話取得見込み客データベース/data-enrichment/00A4EF)の3社追加(1036→1039社)。sitemap 1129 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
