-- PS#4 S638: 競合3社追加 ドキュメント生成ツール (docsify/doxygen/sphinx)
-- SEO: "Docsify代替"/"Doxygen代替"/"Sphinx代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S638: 競合3社追加 (docsify/doxygen/sphinx)',
  'comparison_page.dartにdocsify(ビルドレスドキュメント・SPA・Markdownレンダリング・プラグイン・軽量/42B983)/doxygen(ソースコードからドキュメント生成・C++/Java・クラス図・UML/2C5F8A)/sphinx(Python標準ドキュメント・reStructuredText/Markdown・ReadTheDocs統合/3B4252)の3社追加(1735社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
