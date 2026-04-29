-- PS#4 S265: 競合3社追加 666→669社 (indeed/bizreach/mynavi)
-- SEO: "Indeed代替"/"ビズリーチ代替"/"マイナビ代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S265: 競合3社追加 666→669社 (indeed/bizreach/mynavi)',
  'comparison_page.dartにindeed(世界最大求人検索/job-board/003A9B)/bizreach(ハイクラス転職スカウト/job-board-jp/E8003D)/mynavi(日本大手転職就活サイト/job-board-jp/003087)の3社追加(666→669社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
