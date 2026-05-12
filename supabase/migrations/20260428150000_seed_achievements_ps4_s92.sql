-- PS#4 S92: 21社→174社 表記統一
-- comparison_page hero tag / landing nav / user_manual help text

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S92: 21社→174社表記統一 (comparison/landing/user_manual)',
  'vs-*ページヒーロータグ「21競合比較」→「174社比較」、landingナビラベル「21社との機能比較」→「174社との機能比較」、user_manual比較ページ案内「21社分」→「174社分」に統一。「競合21社に存在しない」説明文は21社参照として意図的に維持。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
