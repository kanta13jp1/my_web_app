-- PS#4 S128: 競合3社追加 255→258社 (ticktick/thinkific/skillshare)
-- SEO: "TickTick代替"/"Thinkific代替"/"Skillshare代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S128: 競合3社追加 255→258社 (ticktick/thinkific/skillshare)',
  'comparison_page.dartにticktick(タスク管理・習慣トラッキング/tasks/4772FA)/thinkific(オンラインコース・コミュニティ構築/e-learning/2F86FB)/skillshare(クリエイティブスキル学習/e-learning/002333)の3社追加(255→258社)。全ファイル258統一。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
