-- PS#4 S372: 競合3社追加 987→990社 (canny/productboard/uservoice)
-- SEO: "Canny代替"/"Productboard代替"/"UserVoice代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S372: 競合3社追加 987→990社 (canny/productboard/uservoice)',
  'comparison_page.dartにcanny(フィードバック収集ロードマップ投票/product-feedback/1D6FF8)/productboard(製品戦略顧客インサイトロードマップ/product-mgmt/FF6340)/uservoice(エンタープライズVOC管理/product-feedback/FA6900)の3社追加(987→990社)。sitemap 1039 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
