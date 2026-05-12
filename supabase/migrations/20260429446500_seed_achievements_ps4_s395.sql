-- PS#4 S395: 競合3社追加 1009→1012社 (excalidraw/penpot/finmark)
-- SEO: "Excalidraw代替"/"Penpot代替"/"Finmark代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S395: 競合3社追加 1009→1012社 (excalidraw/penpot/finmark)',
  'comparison_page.dartにexcalidraw(オープンソース手描き風ホワイトボード図解ツール/whiteboard/6965DB)/penpot(オープンソースデザインプロトタイプFigma代替/design-tools/7B61FF)/finmark(スタートアップ向け財務計画モデリング予算管理/financial-planning/6B48FF)の3社追加(1009→1012社)。sitemap 1102 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
