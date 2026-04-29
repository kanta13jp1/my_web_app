-- PS#4 S515: 競合3社追加 継続 (vast-ai/coreweave/salad-com)
-- SEO: "Vast.ai代替"/"CoreWeave代替"/"Salad.com代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S515: 競合3社追加 (vast-ai/coreweave/salad-com)',
  'comparison_page.dartにvast-ai(格安GPU市場個人GPU売買分散GPU安価学習推論/6C3483)/coreweave(GPU特化K8sエンタープライズAI/HPC NVIDIAパートナー/1B4F72)/salad-com(分散GPU遊休GPU活用低コスト推論グリーンコンピューティング/2ECC71)の3社追加。sitemap 1462 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
