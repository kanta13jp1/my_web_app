-- PS#3 S144: AI大学 382→384社化 achievements
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'AI大学 S144: TruthfulQA 追加 — 382→383社',
    'TruthfulQA (Oxford/OpenAI / Stephanie Lin et al. / ハルシネーション評価 / 817問 / 38カテゴリ / 逆スケーリング発見 / GPT-3大きいほど悪い / Constitutional AI改善ターゲット / Claude3.5~88% / MIT OSS) を AI大学コンテンツとして追加。',
    '2026-04-29'
  ),
  (
    'AI大学 S144: BIG-bench 追加 — 383→384社',
    'BIG-bench (Google Research / 450+研究者 / 204タスク超大規模BM / emergent abilities実証 / BIG-bench Hard 23タスク / PaLM/GPT-4 83%+ / CoT効果測定 / Apache-2.0 OSS) を AI大学コンテンツとして追加。',
    '2026-04-29'
  )
ON CONFLICT DO NOTHING;
