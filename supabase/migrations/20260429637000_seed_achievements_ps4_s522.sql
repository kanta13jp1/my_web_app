-- PS#4 S522: 競合3社追加 1386→1395社 (mode-analytics/hex-tech/lightdash)
-- SEO: "Mode Analytics代替"/"Hex代替"/"Lightdash代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S522: 競合3社追加 1386→1395社 (mode-analytics/hex-tech/lightdash)',
  'comparison_page.dartにmode-analytics(SQL+Python+R+BI統合・データチーム協働ノートブック・自動レポート/3D5AFE)/hex-tech(モダン協働データノートブック・SQL+Python+AI・インタラクティブアプリ化/6C5CE7)/lightdash(OSS BIツール・dbt連携・LookML不要・Gitバージョン管理・セルフホスト/7262FF)の3社追加(1386→1395社)。sitemap 1489 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
