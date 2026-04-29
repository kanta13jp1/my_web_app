-- PS#4 S542: 競合3社追加 継続 (noodl/webstudio/umso) 【1500社達成!】
-- SEO: "Noodl代替"/"Webstudio代替"/"Umso代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S542: 競合3社追加 (noodl/webstudio/umso) 1500社達成!',
  'comparison_page.dartにnoodl(ビジュアルフルスタック・JavaScriptノード・データベース・API・Reactベース/FFA500)/webstudio(OSS Webflow代替・セルフホスト・RadixUI・TypeScript・Cloudflare Workers/7C3AED)/umso(スタートアップLP・AI生成・テンプレート・高速公開/10B981)の3社追加。競合1500社大台達成！',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
