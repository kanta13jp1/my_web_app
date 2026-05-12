-- PS#3 S123: AI大学 340→342社化 achievements
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'AI大学 S123: Phind 追加 — 340→341社',
    'Phind (コード特化AI検索エンジン / GPT-4o + Phind-70B / Web検索統合 / Stack Overflow・GitHub重点 / $20/月 / 最新情報対応 / デバッグ・API質問に最適) を AI大学コンテンツとして追加。',
    '2026-04-29'
  ),
  (
    'AI大学 S123: Tabnine 追加 — 341→342社',
    'Tabnine (エンタープライズ向けプライベートAIコード補完 / ローカル実行 / オンプレ / エアギャップ / SOC2/GDPR / Fine-tuning / 15+ IDE対応 / $12/月〜 / 金融・医療・政府向け) を AI大学コンテンツとして追加。',
    '2026-04-29'
  )
ON CONFLICT DO NOTHING;
