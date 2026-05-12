-- PS#4 S620: 競合3社追加 APIゲートウェイ (aws-api-gateway/azure-api-management/gravitee)
-- SEO: "AWS API Gateway代替"/"Azure API Management代替"/"Gravitee代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S620: 競合3社追加 (aws-api-gateway/azure-api-management/gravitee)',
  'comparison_page.dartにaws-api-gateway(マネージドAPI・REST/WebSocket/Lambda統合・認証・スロットリング/FF9900)/azure-api-management(マネージドAPI・ポリシーエンジン・開発者ポータル・Azure統合/0078D4)/gravitee(OSS APIゲートウェイ・アクセス管理・イベントネイティブ・Kafka対応/6D1FDB)の3社追加(1681社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
