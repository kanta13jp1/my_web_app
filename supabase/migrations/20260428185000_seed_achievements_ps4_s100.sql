-- PS#4 S100: 競合数表記 174社→179社 に全ファイル統一
-- 新規5社追加(github-copilot/chatgpt/tabnine/codeium/gemini)に伴う表記更新

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S100: 競合数表記 174→179社 全ファイル統一',
  'S98+S99で5社追加(github-copilot/chatgpt/tabnine/codeium/gemini)に合わせ、landing_page.dart/comparison_page.dart/user_manual_page.dartの「174社」表記を「179社」に全更新。SEO的にも正確な社数をページ全体に反映。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
