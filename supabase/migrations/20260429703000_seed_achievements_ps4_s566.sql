-- PS#4 S566: 競合3社追加 継続 (hexnode/mosyle/citrix-endpoint)
-- SEO: "Hexnode代替"/"Mosyle代替"/"Citrix Endpoint代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S566: 競合3社追加 (hexnode/mosyle/citrix-endpoint)',
  'comparison_page.dartにhexnode(クラウドUEM・マルチプラットフォーム・キオスクモード・BYOD・コスト効率/4A154B)/mosyle(Apple MDM・ゼロタッチ・セキュリティ・アプリ配布・学校/企業/2E8B57)/citrix-endpoint(UEM・MAM・VDI統合・セキュアアクセス・BYOD/452170)の3社追加(1520社)。sitemap 1615 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
