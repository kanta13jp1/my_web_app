-- PS#4 S328: 競合3社追加 855→858社 (portkey-ai/lunary/neptune-ai)
-- SEO: "Portkey代替"/"Lunary代替"/"Neptune.ai代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S328: 競合3社追加 855→858社 (portkey-ai/lunary/neptune-ai)',
  'comparison_page.dartにportkey-ai(AI GatewayLLMルータープロダクションAIオブザーバビリティ/llm-ops/5B6AD4)/lunary(OSS LLMテレメトリーAI評価ツールキット/llm-ops/6366F1)/neptune-ai(MLメタデータ管理実験追跡モデルレジストリ/mlops/5C62FF)の3社追加(855→858社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
