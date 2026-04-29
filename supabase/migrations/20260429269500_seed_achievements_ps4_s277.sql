-- PS#4 S277: 競合3社追加 702→705社 (redash/superset/whimsical)
-- SEO: "Redash代替"/"Apache Superset代替"/"Whimsical代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S277: 競合3社追加 702→705社 (redash/superset/whimsical)',
  'comparison_page.dartにredash(OSSクエリダッシュボードBI/analytics/E8292B)/superset(Apache OSS BIデータ探索/analytics/20A7C9)/whimsical(ワイヤーフレームフローチャート統合/design/7B5EA7)の3社追加(702→705社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
