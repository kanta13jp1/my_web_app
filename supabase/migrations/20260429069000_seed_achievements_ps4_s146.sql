-- PS#4 S146: 競合3社追加 309→312社 (roam-research/heptabase/anki)
-- SEO: "Roam Research代替"/"Heptabase代替"/"Anki代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S146: 競合3社追加 309→312社 (roam-research/heptabase/anki)',
  'comparison_page.dartにroam-research(双方向リンクネットワークノート/notes/0D2B3E)/heptabase(ビジュアルホワイトボード知識管理/notes/4F46E5)/anki(間隔反復フラッシュカード学習/learning/1F7399)の3社追加(309→312社)。全ファイル312統一。sitemap 602 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
