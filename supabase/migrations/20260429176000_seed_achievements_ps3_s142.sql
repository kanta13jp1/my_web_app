-- PS#3 S142: AI大学 378→380社化 achievements
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'AI大学 S142: HumanEval 追加 — 378→379社',
    'HumanEval (OpenAI / Mark Chen et al. / コード生成ベンチマーク / 164問 / pass@k評価 / Python関数実装 / Codex論文同時公開 / GPT-4~67%→Claude3.5~92%→飽和 / HumanEval+/LiveCodeBench後継 / MIT OSS) を AI大学コンテンツとして追加。',
    '2026-04-29'
  ),
  (
    'AI大学 S142: MMLU 追加 — 379→380社',
    'MMLU (UC Berkeley / Dan Hendrycks et al. / 57分野57,000問 / 多タスク言語理解 / 4択多肢選択 / GPT-3 43.9%→GPT-4 86.4%→Claude3.7 90%+ / STEM+人文+医療+法律 / MMLU-Pro/GPQA後継 / MIT OSS) を AI大学コンテンツとして追加。',
    '2026-04-29'
  )
ON CONFLICT DO NOTHING;
