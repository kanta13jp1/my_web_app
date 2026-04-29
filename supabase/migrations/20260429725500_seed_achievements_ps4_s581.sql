-- PS#4 S581: 競合3社追加 継続 (amazon-connect/mitel/liveagent)
-- SEO: "Amazon Connect代替"/"Mitel代替"/"LiveAgent代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S581: 競合3社追加 (amazon-connect/mitel/liveagent)',
  'comparison_page.dartにamazon-connect(クラウドCCaaS・AWS統合・AI・Contact Lens・従量課金/FF9900)/mitel(UCaaS/CCaaS・ハイブリッド・ビジネスコミュニケーション・中規模/00529B)/liveagent(マルチチャネルCS・ライブチャット・コールセンター・ゲーミフィケーション/FF5722)の3社追加(1564社)。sitemap 1660 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
