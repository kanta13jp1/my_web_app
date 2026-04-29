-- PS#4 S491: 競合3社追加 継続 (affine/zettlr/journey-app)
-- SEO: "AFFiNE代替"/"Zettlr代替"/"Journey代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S491: 競合3社追加 (affine/zettlr/journey-app)',
  'comparison_page.dartにaffine(OSS次世代PKMホワイトボードドキュメントDB統合ローカルファースト/1971C2)/zettlr(OSS学術向けMarkdownZettelkastenZotero連携/43A047)/journey-app(クロスプラットフォーム日記写真/地図ムードGoogle Drive/00897B)の3社追加。sitemap 1390 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
