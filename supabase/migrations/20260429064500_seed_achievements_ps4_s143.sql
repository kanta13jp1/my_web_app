-- PS#4 S143: 競合3社追加 300→303社 (linkedin/glassdoor/wantedly)
-- SEO: "LinkedIn代替"/"Glassdoor代替"/"Wantedly代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S143: 競合3社追加 300→303社 (linkedin/glassdoor/wantedly)',
  'comparison_page.dartにlinkedin(プロフェッショナルネットワーク/career/0077B5)/glassdoor(企業口コミ求人/career/0CAA41)/wantedly(カジュアル面談スタートアップ転職/career/21CEFF)の3社追加(300→303社)。新カテゴリcareer追加。sitemap 352 URLs。全ファイル303統一。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
