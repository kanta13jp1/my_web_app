-- PS#4 S534: 競合3社追加 1422→1431社 (tldraw/lucidspark/milanote)
-- SEO: "tldraw代替"/"Lucidspark代替"/"Milanote代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S534: 競合3社追加 1422→1431社 (tldraw/lucidspark/milanote)',
  'comparison_page.dartにtldraw(OSS無限キャンバス・React埋め込み可・ブラウザ完結・シンプルホワイトボード/1C1C1E)/lucidspark(バーチャルホワイトボード・ブレスト・投票・タイマー・Zoom/Teams統合/FF8C00)/milanote(クリエイティブビジュアルボード・ムードボード・ストーリーボード・チーム共有/E8D5C4)の3社追加(1422→1431社)。sitemap 1525 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
