-- PS#4 S434: 競合3社追加 1126→1129社 (ableton/hemingway/ps-plus)
-- SEO: "Ableton代替"/"Hemingway Editor代替"/"PlayStation Plus代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S434: 競合3社追加 1126→1129社 (ableton/hemingway/ps-plus)',
  'comparison_page.dartにableton(Ableton Live DAWライブパフォーマンスSessionビューMax for Live/music-creation/4C4C4C)/hemingway(文章明瞭化ツール読みやすさスコア受動態検出/writing/F5A623)/ps-plus(Sony PS4/PS5サブスクEssential/Extra/Premium/gaming-sub/003087)の3社追加(1126→1129社)。sitemap 1219 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
