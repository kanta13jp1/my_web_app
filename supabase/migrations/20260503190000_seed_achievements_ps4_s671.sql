-- PS#4 S671: 競合9社追加 APIクライアントツール (Bruno/ThunderClient/HTTPie/RapidAPI/Apidog/Paw/Restfox/Requestly/Milkman)
-- api-clientカテゴリ新設 (Postman/Insomnia/Hoppscotch既存補完)

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S671: 競合9社追加 (Bruno/ThunderClient/HTTPie/RapidAPI/Apidog/Paw/Restfox/Requestly/Milkman)',
  'comparison_page.dartにBruno(OSSローカルAPIクライアント/Git管理可能/Postman代替/FF6F00)/Thunder Client(VSCode拡張APIクライアント/軽量/Git同期/FF6D00)/HTTPie(人間向けHTTPクライアント/CLI+GUI/009688)/RapidAPI Client(API marketplace統合/APIハブ/0052CC)/Apidog(API設計/Mock/テスト/ドキュメント統合/FF4081)/Paw(Mac向けフル機能APIクライアント/795548)/Restfox(OSSブラウザ対応/PWA/Postman代替/0288D1)/Requestly(HTTP傍受/APIモッキング/43A047)/Milkman(OSSマルチプロトコル/gRPC/WebSocket/Kafka/5C6BC0)の9社追加(1861→1870社)。sitemap 1957→1966 URLs。api-clientカテゴリ新設。',
  '2026-05-03'
)
ON CONFLICT DO NOTHING;
