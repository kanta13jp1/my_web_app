-- PS#4 S514: 競合3社追加 継続 (deepseek-api/perplexity-api/nvidia-nim)
-- SEO: "DeepSeek代替"/"Perplexity代替"/"NVIDIA NIM代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S514: 競合3社追加 (deepseek-api/perplexity-api/nvidia-nim)',
  'comparison_page.dartにdeepseek-api(DeepSeek-V3/R1 OpenAI互換API OSS超低コスト/006EFF)/perplexity-api(リアルタイムWeb検索引用付き回答Pro検索API/20B2AA)/nvidia-nim(NVIDIA最適化GPU推論エンタープライズコンテナ/76B900)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
