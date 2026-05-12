-- PS#4 S98: 高検索ボリューム競合3社追加 (github-copilot/chatgpt/tabnine)
-- SEO: "GitHub Copilot代替"/"ChatGPT代替"/"Tabnine代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S98: 高検索ボリューム競合3社追加 174→177社 (github-copilot/chatgpt/tabnine)',
  'comparison_page.dart _competitorInfo に github-copilot/chatgpt/tabnine の3社を追加(174→177社)。competitorMeta(index.html) + sitemap.xml(+3URL/priority=0.8) も更新。_categoryOf にai-dev/ai-platform分類追加。ChatGPT代替・GitHub Copilot代替は高検索ボリュームキーワード。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
