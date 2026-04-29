-- PS#3 S143: AI大学 380→382社化 achievements
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'AI大学 S143: HellaSwag 追加 — 380→381社',
    'HellaSwag (AI2/UW / Rowan Zellers et al. / 常識推論ベンチマーク / 70k問 / 4択文章補完 / AFLite敵対的フィルタリング / BERT 47%→GPT-4 95.3%→飽和 / WinoGrande/ARC後継 / MIT OSS) を AI大学コンテンツとして追加。',
    '2026-04-29'
  ),
  (
    'AI大学 S143: GSM8K 追加 — 381→382社',
    'GSM8K (OpenAI / Karl Cobbe et al. / 小学校算数8,500問 / 多段階推論 / Chain-of-Thought実証 / Verifier手法 / GPT-3 15%→GPT-4 92%→o1 99%→飽和 / MATH/AIME後継 / MIT OSS) を AI大学コンテンツとして追加。',
    '2026-04-29'
  )
ON CONFLICT DO NOTHING;
