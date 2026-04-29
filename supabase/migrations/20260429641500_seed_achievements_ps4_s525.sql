-- PS#4 S525: 競合3社追加 1395→1404社 (openreplay/lucky-orange/yandex-metrica)
-- SEO: "OpenReplay代替"/"Lucky Orange代替"/"Yandex Metrica代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S525: 競合3社追加 1395→1404社 (openreplay/lucky-orange/yandex-metrica)',
  'comparison_page.dartにopenreplay(OSS セッションリプレイ・自社ホスト・GDPR・DevToolsパネル・パフォーマンス追跡/E01F5A)/lucky-orange(ヒートマップ+ライブチャット+セッション録画+フォーム分析・中小企業向け/FF7F00)/yandex-metrica(Yandex無料ウェブ分析・ヒートマップ・セッションリプレイ・無制限データ保存/FF0000)の3社追加(1395→1404社)。sitemap 1498 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
