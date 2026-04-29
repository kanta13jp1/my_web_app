-- PS#4 S461: 競合3社追加 1204→1207社 (firefox/opera/vivaldi)
-- SEO: "Firefox代替"/"Opera代替"/"Vivaldi代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S461: 競合3社追加 1204→1207社 (firefox/opera/vivaldi)',
  'comparison_page.dartにfirefox(Mozilla OSS ETP拡張機能エコシステム/FF9400)/opera(内蔵VPN Ad Blocker Opera GX Aria AI/FF1B2D)/vivaldi(高カスタマイズタブスタック分割ビューノートメール統合/EF3939)の3社追加(1204→1207社)。sitemap 1300 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
