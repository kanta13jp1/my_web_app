-- PS#4 S381: 競合3社追加 1014→1017社 (kong/tyk/apigee)
-- SEO: "Kong代替"/"Tyk代替"/"Apigee代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S381: 競合3社追加 1014→1017社 (kong/tyk/apigee)',
  'comparison_page.dartにkong(クラウドネイティブAPIゲートウェイプラグイン300+/api-gateway/003459)/tyk(OSS APIゲートウェイデベロッパーポータル/api-gateway/34B6C6)/apigee(Google Cloud APIマネジメント/api-gateway/1A73E8)の3社追加(1014→1017社)。sitemap 1066 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
