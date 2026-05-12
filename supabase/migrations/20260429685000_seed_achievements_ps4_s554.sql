-- PS#4 S554: 競合3社追加 継続 (carbon-black/trend-micro/darktrace)
-- SEO: "Carbon Black代替"/"Trend Micro代替"/"Darktrace代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S554: 競合3社追加 (carbon-black/trend-micro/darktrace)',
  'comparison_page.dartにcarbon-black(VMware EDR・ワークロード保護・脅威ハンティング・ランサムウェア対策/1A1A1A)/trend-micro(XDR・ランサムウェア対策・ハイブリッドクラウド・エンドポイント統合/E60012)/darktrace(AI自律型・自己学習・RESPOND/PREVENT/HEAL・NTA/EDR/Email統合/7B2D8B)の3社追加(1484社)。sitemap 1579 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
