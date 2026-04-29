-- PS#3 S129: AI大学 352→354社化 achievements
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'AI大学 S129: Mentat 追加 — 352→353社',
    'Mentat (AbanteAI / 2023年初期CLI自律コーディングエージェント / コードベース全体理解 / 複数ファイル同時編集 / git統合 / デューン小説から命名 / 現代エージェント黎明期の先駆者 / MIT OSS) を AI大学コンテンツとして追加。',
    '2026-04-29'
  ),
  (
    'AI大学 S129: Plandex 追加 — 353→354社',
    'Plandex (長タスク対応AIコーディングエンジン / Pending Changesバッファ / ロールバック機能 / AI会話ブランチ / 大規模多ファイル変更対応 / MIT OSS / curl one-liner install) を AI大学コンテンツとして追加。',
    '2026-04-29'
  )
ON CONFLICT DO NOTHING;
