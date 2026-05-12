-- PS#3 S147: AI大学 386→388社化 achievements
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'AI大学 S147: MATH benchmark 追加 — 386→387社',
    'MATH benchmark (Dan Hendrycks / UC Berkeley / NeurIPS2021 / 12,500問競技数学 / 7科目 / 難度5段階AMC-AIME / GPT-3 5%→GPT-4 42%→o1 94% / Chain-of-Thought効果実証 / Minerva数学専用学習の基盤 / Process Reward Model研究促進 / MIT OSS) を AI大学コンテンツとして追加。',
    '2026-05-01'
  ),
  (
    'AI大学 S147: Chatbot Arena 追加 — 387→388社',
    'Chatbot Arena (LMSYS / UC Berkeley / 2023年4月公開 / クラウドソース人間評価 / 1M+投票 / ELO/Bradley-Terryレーティング / ブラインドA/Bテスト / MT-Bench補完 / GPT-4優位確証 / オープンソース台頭発見 / NeurIPS2023 / Apache2.0 OSS) を AI大学コンテンツとして追加。',
    '2026-05-01'
  )
ON CONFLICT DO NOTHING;
