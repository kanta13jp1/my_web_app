-- PS#4 S247: 競合3社追加 612→615社 (langgraph/metagpt/superagi)
-- SEO: "LangGraph代替"/"MetaGPT代替"/"SuperAGI代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S247: 競合3社追加 612→615社 (langgraph/metagpt/superagi)',
  'comparison_page.dartにlanggraph(ステートフルAIエージェントグラフ/ai-agent/1C7ED6)/metagpt(ソフトウェア会社模倣マルチエージェント/ai-agent/6C3483)/superagi(OSS自律AIエージェントインフラ/ai-agent/7B2FBE)の3社追加(612→615社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
